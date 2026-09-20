import { socket } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { createLogger } from '../../common/utils/Logger';
import { queryDnsA } from '../../common/utils/DoHClient';

const logger = createLogger('PixivHosts');

/**
 * 需要直连管理的 Pixiv 域名
 */
export const PIXIV_DIRECT_DOMAINS: string[] = [
  'app-api.pixiv.net',
  'oauth.secure.pixiv.net',
  'www.pixiv.net',
  'accounts.pixiv.net',
  'i.pximg.net',
  's.pximg.net',
  'sketch.pixiv.net',
];

/** 图片 CDN 域名（同一集群，IP 池互通） */
const PXIMG_CDN_DOMAINS: string[] = ['i.pximg.net', 's.pximg.net'];
/** 图片 CDN 的 DoH 查询源（该域名未被污染，答案真实可信） */
const PXIMG_CDN_DOH_SOURCE = 's.pximg.net';

/**
 * 内置兜底 IP（2026-09 在 SNI 阻断网络下真机实测）
 * - 图片 CDN（i/s.pximg.net）：210.140.139.x 集群，SNI-less + Host 路由已验证可取回真实图片
 * - API 域名：PixEz-Flutter hoster.dart 内置的 210.140.139.155（仅 DNS 污染网络可用；
 *   SNI 阻断网络下 API 直连无解，需用户配置代理或等 rcp 支持 ECH）
 */
const BUILTIN_IPS: Record<string, string[]> = {
  'app-api.pixiv.net': ['210.140.139.155'],
  'oauth.secure.pixiv.net': ['210.140.139.155'],
  'www.pixiv.net': ['210.140.139.155'],
  'accounts.pixiv.net': ['210.140.139.155'],
  'sketch.pixiv.net': ['210.140.139.155'],
  'i.pximg.net': ['210.140.139.133', '210.140.139.132', '210.140.139.134', '210.140.139.135'],
  's.pximg.net': ['210.140.139.133', '210.140.139.132', '210.140.139.134', '210.140.139.135'],
};

/** 单个域名保留的可用 IP 数量上限 */
const MAX_IPS_PER_HOST = 4;
/** 测速排序应用的池大小上限（分块 worker 摊开用，ips[0] 供探针/单请求/预览图） */
export const SPEED_POOL_APPLY_SIZE = 6;
/** 连续失败多少次后触发后台 DoH 刷新 */
const FAILURE_THRESHOLD = 3;

interface PingResult {
  ip: string;
  costMs: number;
}

/**
 * Pixiv 域名 IP 池管理器（直连核心）
 * 优先级：用户自定义 hosts > DoH+测速缓存 > 内置兜底 IP
 */
class PixivHosts {
  /** 用户自定义 hosts 覆盖 (host -> ip) */
  private userHosts: Map<string, string> = new Map();
  /** 可用 IP 池（有序，越靠前越优） */
  private cachedIps: Map<string, string[]> = new Map();
  /** 域名连续失败计数 */
  private failureCounts: Map<string, number> = new Map();
  private refreshing: boolean = false;
  private refreshedOnce: boolean = false;

  /**
   * 取域名可用的直连 IP 列表（有序，首选在前）
   * 返回空数组表示该域名不在直连管理范围内
   */
  getDirectIps(host: string): string[] {
    const userIp = this.userHosts.get(host);
    if (userIp) {
      return [userIp];
    }
    const cached = this.cachedIps.get(host);
    if (cached && cached.length > 0) {
      return [...cached];
    }
    const builtin = BUILTIN_IPS[host];
    return builtin ? [...builtin] : [];
  }

  /** 用户是否为该域名配置了自定义 hosts */
  hasUserHost(host: string): boolean {
    return this.userHosts.has(host);
  }

  /**
   * 应用「CDN IP 测速」结果：按实测吞吐降序写入图片 CDN IP 池（持久化由调用方负责）
   * 用户为该域名配置了自定义 hosts 时不覆盖；顺序即优先级，ips[0] = 实测最快
   */
  setSpeedPool(orderedIps: string[]): void {
    if (orderedIps.length === 0) {
      return;
    }
    const pool = orderedIps.slice(0, SPEED_POOL_APPLY_SIZE);
    for (const domain of PXIMG_CDN_DOMAINS) {
      if (!this.userHosts.has(domain)) {
        this.cachedIps.set(domain, [...pool]);
      }
    }
    logger.info(`applied speed-test pool: [${pool.join(', ')}]`);
  }

  /** 设置用户自定义 hosts 映射 */
  setUserHost(host: string, ip: string): void {
    this.userHosts.set(host, ip);
  }

  /** 移除用户自定义 hosts 映射 */
  removeUserHost(host: string): void {
    this.userHosts.delete(host);
  }

  /** 清空全部用户自定义 hosts（设置重解析前调用） */
  clearUserHosts(): void {
    this.userHosts.clear();
  }

  /** 获取当前生效的映射快照（调试/设置页展示用） */
  getSnapshot(): Record<string, string[]> {
    const result: Record<string, string[]> = {};
    for (const domain of PIXIV_DIRECT_DOMAINS) {
      result[domain] = this.getDirectIps(domain);
    }
    return result;
  }

  /**
   * 网络层请求失败后调用：轮换首选 IP，连续失败达阈值后触发后台刷新
   */
  reportFailure(host: string): void {
    if (!PIXIV_DIRECT_DOMAINS.includes(host)) {
      return;
    }
    let pool = this.cachedIps.get(host);
    if (!pool) {
      // 兜底 IP 也纳入池中参与轮换
      const builtin = BUILTIN_IPS[host];
      if (builtin && builtin.length > 0) {
        pool = [...builtin];
        this.cachedIps.set(host, pool);
      }
    }
    if (pool && pool.length > 1) {
      const first = pool.shift();
      if (first !== undefined) {
        pool.push(first);
      }
    }
    const count = (this.failureCounts.get(host) || 0) + 1;
    this.failureCounts.set(host, count);
    if (count >= FAILURE_THRESHOLD) {
      this.failureCounts.set(host, 0);
      this.refresh().catch((e: Object) => {
        logger.warn(`background refresh failed: ${JSON.stringify(e)}`);
      });
    }
  }

  /** 请求成功后调用：清零失败计数 */
  reportSuccess(host: string): void {
    this.failureCounts.set(host, 0);
  }

  /** 首次请求前触发一次后台刷新（失败静默，兜底 IP 仍然可用） */
  ensureRefreshed(): void {
    if (this.refreshedOnce) {
      return;
    }
    this.refreshedOnce = true;
    this.refresh().catch((e: Object) => {
      logger.warn(`initial refresh failed: ${JSON.stringify(e)}`);
    });
  }

  /**
   * DoH 刷新图片 CDN IP 池
   * 国内 DoH 对 API 域名的答案已被污染，且 SNI-less 下 Cloudflare 前置域名无法按 Host 路由，
   * 因此只刷新未被污染的 s.pximg.net，结果供 i.pximg.net / s.pximg.net 共用；
   * API 域名依赖内置 IP 与用户自定义 hosts
   */
  async refresh(): Promise<void> {
    if (this.refreshing) {
      return;
    }
    this.refreshing = true;
    try {
      if (this.userHosts.has(PXIMG_CDN_DOH_SOURCE)) {
        return;
      }
      const candidates = await queryDnsA(PXIMG_CDN_DOH_SOURCE);
      if (candidates.length === 0) {
        return;
      }
      const pingResults = await Promise.all(
        candidates.map((ip: string) => tcping(ip, 443))
      );
      const alive: string[] = pingResults
        .filter((p: PingResult) => p.costMs >= 0)
        .sort((a: PingResult, b: PingResult) => a.costMs - b.costMs)
        .map((p: PingResult) => p.ip)
        .slice(0, MAX_IPS_PER_HOST);
      if (alive.length > 0) {
        for (const domain of PXIMG_CDN_DOMAINS) {
          if (!this.userHosts.has(domain)) {
            this.cachedIps.set(domain, [...alive]);
          }
        }
        logger.info(`refreshed pximg cdn pool: [${alive.join(', ')}]`);
      }
    } finally {
      this.refreshing = false;
    }
  }
}

/**
 * TCP 连通性测速（直连可用性的第一道验证）
 * @returns 耗时毫秒数，失败返回 -1
 */
function tcping(ip: string, port: number, timeoutMs: number = 2000): Promise<PingResult> {
  return new Promise<PingResult>((resolve) => {
    const tcp = socket.constructTCPSocketInstance();
    const start = Date.now();
    let settled = false;
    const finish = (costMs: number): void => {
      if (settled) {
        return;
      }
      settled = true;
      tcp.close().catch(() => {
      });
      resolve({ ip, costMs });
    };
    tcp.connect({
      address: { address: ip, port: port },
      timeout: timeoutMs
    }).then(() => {
      finish(Date.now() - start);
    }).catch((e: BusinessError) => {
      finish(-1);
    });
  });
}

export const pixivHosts = new PixivHosts();
