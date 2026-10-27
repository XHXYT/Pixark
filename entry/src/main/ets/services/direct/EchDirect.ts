import axios from '@ohos/axios';
import { createLogger } from '../../common/utils/Logger';
import { UrlUtils } from '../../common/utils/UrlUtils';
import { echFetch, EchResponse, EchFetchOptions, EchHeader } from 'libpixech.so';

const logger = createLogger('EchDirect');

/**
 * ECH 直连层（PixEz ECH 模式同款机制）
 *
 * 原理：app-api/oauth/accounts 等 API 域名前置 Cloudflare，TLS ClientHello 携带真实 SNI 会被
 * GFW RST（SNI 阻断），而 SNI-less 又被 CF 边缘拒绝（403）。ECH（Encrypted Client Hello）
 * 把真实 SNI 加密进 ClientHello 的 encrypted_client_hello 扩展，外层明文 SNI 用
 * cloudflare-ech.com，从而既过 GFW 又能被 CF 正确路由。
 *
 * ECH 配置来源：阿里 DoH 查询 cloudflare-ech.com 的 HTTPS RR（type 65），
 * Answer.data 中的 ech=<base64> 即 rustls 所需的 ECHConfigList，ipv4hint 为推荐边缘 IP。
 * 该记录 TTL 很短（约 1-2 分钟），需按 TTL 动态刷新。
 */

/** ECH 边缘兜底 IP（DoH 无 ipv4hint 时使用，PixEz hoster.dart 同款） */
const FALLBACK_ECH_IPS: string[] = ['104.18.10.118', '104.18.11.118'];

/** ECH 配置查询结果 */
interface EchLookup {
  /** ECHConfigList 的 base64（不含引号），透传给 libpixech.so */
  echConfigB64: string;
  /** DoH ipv4hint 给出的边缘 IP 列表 */
  ips: string[];
  /** 过期时间戳（毫秒） */
  expiresAt: number;
  /** 过期后仍可沿用的最后期限（ms）：窗口内先用旧配置顶住并后台刷新 */
  usableUntil: number;
}

/** DoH JSON 响应（HTTPS RR 查询） */
interface DoHJsonAnswer {
  name: string;
  type: number;
  data: string;
  ttl?: number;
}

interface DoHJsonResponse {
  Status?: number;
  Answer?: DoHJsonAnswer[];
}

let cachedLookup: EchLookup | null = null;
let inFlight: Promise<EchLookup | null> | null = null;
/** 轮换游标：ech 边缘 IP 失败后换下一个 */
let ipCursor = 0;

/** DoH 配置查询失败轮次：每次失败 +1，供「同一轮失败只计一次」去重 */
let configFailEpoch = 0;
/** 已计入失败统计的轮次（=== configFailEpoch 表示本轮已计过） */
let countedConfigEpoch = -1;
/** 达阈值后是否已强制刷新过一次配置（是则下次达阈值直接进冷却） */
let configRefreshForced = false;

/** 过期配置沿用缓冲窗口（ms）：DoH 单点抖动时先用旧配置顶住，后台静默刷新 */
const STALE_CONFIG_GRACE_MS = 60 * 1000;

/**
 * ECH 链路运行时状态（失败统计 + 冷却期，供设置页展示与快速回退）
 * 连续失败达阈值后进入冷却期：期间 echRequest 直接抛错，
 * DirectHttp 立刻回退兼容模式，避免每个请求都白等一次 ECH 超时
 */
export interface EchRuntimeStatus {
  /** 连续失败次数（成功后清零） */
  consecutiveFailures: number;
  /** 累计请求次数 */
  totalRequests: number;
  /** 最近一次失败原因 */
  lastError: string;
  /** 冷却截止时间戳（ms），0 表示未进入冷却 */
  cooldownUntil: number;
}

const ECH_FAILURE_THRESHOLD = 3;
const ECH_COOLDOWN_MS = 3 * 60 * 1000;

const echStatus: EchRuntimeStatus = {
  consecutiveFailures: 0,
  totalRequests: 0,
  lastError: '',
  cooldownUntil: 0,
};

/** 读取 ECH 链路运行状态（设置页展示用） */
export function getEchStatus(): EchRuntimeStatus {
  return echStatus;
}

/** 重置失败统计并解除冷却（模式切回 ECH / 手动重试时调用） */
export function resetEchStatus(): void {
  echStatus.consecutiveFailures = 0;
  echStatus.lastError = '';
  echStatus.cooldownUntil = 0;
  configRefreshForced = false;
}

/** 记录一次 ECH 失败，达到阈值先进冷却；首次达阈值先强制刷新一次配置（不进冷却） */
function reportEchFailure(reason: string): void {
  echStatus.consecutiveFailures++;
  echStatus.lastError = reason;
  if (echStatus.consecutiveFailures >= ECH_FAILURE_THRESHOLD) {
    if (!configRefreshForced) {
      // 冷启动 DoH 抖动多为「配置刚过期 + DoH 单点失败」叠加：
      // 先作废旧配置强制重查一次，给一轮机会，不直接进 3 分钟冷却
      configRefreshForced = true;
      cachedLookup = null;
      if (!inFlight) {
        inFlight = doLookup().finally(() => {
          inFlight = null;
        });
      }
      logger.warn(`ech threshold reached, force config refresh instead of cooldown: ${reason}`);
      return;
    }
    configRefreshForced = false;
    echStatus.cooldownUntil = Date.now() + ECH_COOLDOWN_MS;
    logger.warn(`ech entered cooldown ${ECH_COOLDOWN_MS / 1000}s after ${echStatus.consecutiveFailures} failures: ${reason}`);
  }
}

/**
 * 获取 ECH 配置（带缓存，按 TTL 过期；并发查询合并为一次）
 * @returns 查询失败或未获取到 ech 配置时返回 null
 */
export async function getEchLookup(): Promise<EchLookup | null> {
  const now = Date.now();
  if (cachedLookup && now < cachedLookup.expiresAt) {
    return cachedLookup;
  }
  // 配置刚过期但仍在沿用缓冲窗口内：先用旧配置放行请求，后台静默刷新
  // （避免 DoH 单点抖动时所有请求阻塞等查询、甚至直接拿不到配置失败）
  if (cachedLookup && now < cachedLookup.usableUntil) {
    if (!inFlight) {
      inFlight = doLookup().finally(() => {
        inFlight = null;
      });
    }
    return cachedLookup;
  }
  if (inFlight) {
    return inFlight;
  }
  inFlight = doLookup().finally(() => {
    inFlight = null;
  });
  return inFlight;
}

async function doLookup(): Promise<EchLookup | null> {
  const queryUrl = UrlUtils.buildUrl('https://dns.alidns.com/resolve', {
    name: 'cloudflare-ech.com',
    type: '65',
  });
  try {
    const response = await axios.get<DoHJsonResponse>(queryUrl, {
      headers: { accept: 'application/dns-json' },
      timeout: 5000,
    });
    const answers = response.data?.Answer;
    if (!answers || answers.length === 0) {
      logger.warn('DoH HTTPS RR: no answer');
      configFailEpoch++;
      return null;
    }
    let echB64 = '';
    let ips: string[] = [];
    let ttl = 60;
    for (const ans of answers) {
      if (ans.type !== 65 || !ans.data) {
        continue;
      }
      const echMatch = ans.data.match(/ech="?([A-Za-z0-9+/=]+)/);
      if (echMatch && echMatch[1].length > echB64.length) {
        echB64 = echMatch[1];
      }
      const hintMatch = ans.data.match(/ipv4hint="?([0-9.,]+)/);
      if (hintMatch) {
        const parsed = hintMatch[1].split(',').filter((s: string) => s.length > 0);
        if (parsed.length > 0) {
          ips = parsed;
        }
      }
      if (ans.ttl && ans.ttl > 0 && ans.ttl < ttl) {
        ttl = ans.ttl;
      }
    }
    if (!echB64) {
      logger.warn(`DoH HTTPS RR: no ech param, data sample: ${answers[0].data?.substring(0, 80)}`);
      configFailEpoch++;
      return null;
    }
    if (ips.length === 0) {
      ips = [...FALLBACK_ECH_IPS];
    }
    // 提前 5 秒过期（TTL 短、CF 轮换快，但过早作废会让 DoH 单点抖动直接放大成请求失败）
    const expiresAt = Date.now() + Math.max(ttl - 5, 20) * 1000;
    const lookup: EchLookup = {
      echConfigB64: echB64,
      ips: ips,
      expiresAt: expiresAt,
      usableUntil: expiresAt + STALE_CONFIG_GRACE_MS,
    };
    cachedLookup = lookup;
    logger.info(`ech config refreshed: ttl=${ttl}s, ips=[${ips.join(', ')}], ech=${echB64.substring(0, 24)}...`);
    return lookup;
  } catch (e) {
    logger.warn(`DoH HTTPS RR query failed: ${JSON.stringify(e)}`);
    configFailEpoch++;
    return null;
  }
}

/**
 * 取当前首选 ECH 边缘 IP（失败轮换）
 */
function nextEchIp(lookup: EchLookup): string {
  const ips = lookup.ips.length > 0 ? lookup.ips : FALLBACK_ECH_IPS;
  const ip = ips[ipCursor % ips.length];
  ipCursor++;
  return ip;
}

/**
 * 发起 ECH 直连请求（GET/POST 等），失败抛出异常由上层回退到 rcp SNI-less 链路
 */
export async function echRequest(
  method: string,
  url: string,
  headers: Record<string, string>,
  body?: Uint8Array,
  timeoutMs?: number
): Promise<EchResponse> {
  // 冷却期内直接失败，让上层立刻回退兼容模式
  if (Date.now() < echStatus.cooldownUntil) {
    const remain = Math.ceil((echStatus.cooldownUntil - Date.now()) / 1000);
    throw new Error(`ech in cooldown, ${remain}s remaining`);
  }
  echStatus.totalRequests++;
  try {
    const lookup = await getEchLookup();
    if (!lookup) {
      throw new Error('ech config unavailable');
    }
    const echHeaders: EchHeader[] = [];
    const keys = Object.keys(headers);
    for (const key of keys) {
      echHeaders.push({ name: key, value: headers[key] });
    }
    const options: EchFetchOptions = {
      method: method,
      headers: echHeaders,
      body: body,
      // 默认 20s 超时：reqwest 无超时会永久挂起，拖死上层 isLoading 状态
      timeoutMs: timeoutMs ?? 20000,
    };
    const connectIp = nextEchIp(lookup);
    const res = await echFetch(url, connectIp, lookup.echConfigB64, options);
    echStatus.consecutiveFailures = 0;
    configRefreshForced = false;
    return res;
  } catch (e) {
    const msg = `${e}`;
    // 同一轮 DoH 查询失败只计一次失败：冷启动并发请求共享同一次查询结果，
    // 若逐个计数会瞬间打满冷却阈值，把一次 DoH 抖动放大成 3 分钟全量回退
    if (msg.includes('ech config unavailable')) {
      if (countedConfigEpoch === configFailEpoch) {
        throw e;
      }
      countedConfigEpoch = configFailEpoch;
    }
    reportEchFailure(msg);
    throw e;
  }
}
