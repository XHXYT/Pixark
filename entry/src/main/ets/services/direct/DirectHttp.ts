import { rcp } from '@kit.RemoteCommunicationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { createLogger } from '../../common/utils/Logger';
import { UrlUtils } from '../../common/utils/UrlUtils';
import { PIXIV_DIRECT_DOMAINS, pixivHosts } from './PixivHosts';
import { echRequest } from './EchDirect';
import { NetworkMode, networkModeState } from './NetworkModeState';

const logger = createLogger('DirectHttp');

/** 网络层重试次数上限（每次重试前会轮换直连 IP） */
const MAX_NETWORK_RETRIES = 2;
/** 图片防盗链 Referer（PixEz 同款） */
const IMAGE_REFERER = 'https://app-api.pixiv.net/';
/** 下载链路连接/传输超时（下载会话配置，直连下载请求统一走该会话） */
const DL_CONNECT_MS = 15000;
const DL_TRANSFER_MS = 90000;
/** 下载链路停滞判定：超过该时长未收到任何新数据（响应头/字节）则主动取消、轮换 IP 重试 */
const DOWNLOAD_STALL_MS = 30000;

/** CDN IP 测速：单连接拉取上限与超时（慢速链路下超时也能拿到部分吞吐样本） */
const SPEED_TEST_RANGE_END = 262143; // bytes=0-262143（256KB）
const SPEED_TEST_CONNECT_MS = 10000;
const SPEED_TEST_TRANSFER_MS = 25000;
/** 测速样本路径：PixEz NetworkSettingPage 同款 illust（2016 年老图，长期稳定存在）的 master1200 */
const SPEED_TEST_PATH = '/c/600x1200_90/img-master/img/2016/04/29/03/33/27/56585648_p0_master1200.jpg';

/**
 * 走 ECH 链路的 API 域名（前置 Cloudflare，SNI 阻断 + CF 拒绝 SNI-less 双重夹击，
 * 唯一直连出路是 ECH，见 EchDirect.ts 说明；失败自动回退 rcp SNI-less 链路）
 */
const ECH_API_DOMAINS: string[] = [
  'app-api.pixiv.net',
  'oauth.secure.pixiv.net',
  'accounts.pixiv.net',
  'www.pixiv.net',
];

/**
 * 统一原始响应（rcp 与 ECH 两条链路的公共形态）
 */
interface RawResponse {
  statusCode: number;
  headers: Record<string, string | string[]>;
  /** 二进制体（图片等） */
  body?: ArrayBuffer;
  /** 文本体（JSON API 等） */
  text: string;
}

export interface HttpConfig {
  params?: Record<string, Object | string | number | boolean | undefined | null>;
  headers?: Record<string, string>;
  timeoutMs?: number;
}

export interface HttpResponse<T> {
  status: number;
  data: T;
  headers: Record<string, string>;
}

/** Range 分段请求结果 */
export interface RangeFetchResult {
  /** 分段响应体 */
  body: ArrayBuffer;
  /** Content-Range 携带的资源总大小（bytes 0-0/TOTAL），响应无该头时为 -1 */
  totalSize: number;
}

/** 图片 CDN 单 IP 吞吐实测结果 */
export interface IpSpeedResult {
  ip: string;
  /** 是否拿到有效数据（HTTP < 400 且收到字节） */
  ok: boolean;
  /** 实收字节数（超时/失败时也可能有部分数据） */
  bytes: number;
  /** 总耗时（含握手） */
  totalMs: number;
  /** 首字节到达耗时（-1 = 未收到任何数据） */
  ttfbMs: number;
  /** ttfb 之后的平均吞吐 KB/s（排除握手影响，反映该连接的持续限速水平；无数据为 0） */
  speedKBs: number;
  /** 失败原因（成功为空串） */
  error: string;
}

/** 分块内断点续传状态（网络层重试时携带已收数据，只补拉剩余区间） */
interface ChunkResumeState {
  /** 跨尝试累积的响应分片 */
  chunks: ArrayBuffer[];
  /** 跨尝试累积的已收字节数 */
  received: number;
}

export interface DirectClientOptions {
  baseURL?: string;
  defaultHeaders?: Record<string, string>;
  /** 每次请求前回调，用于动态注入 Token 等请求头 */
  onRequest?: (headers: Record<string, string>) => void;
  /** 收到 401 时回调，返回 true 表示已刷新凭证、客户端会重试一次 */
  onUnauthorized?: (headers: Record<string, string>) => Promise<boolean>;
}

/**
 * 统一错误对象（模拟 axios 的 error.response / error.code 结构，便于上层复用原有逻辑）
 */
export class HttpError extends Error {
  readonly code?: string;
  readonly response?: { status: number; data: Object | undefined };

  constructor(message: string, code?: string, response?: { status: number; data: Object | undefined }) {
    super(message);
    this.name = 'HttpError';
    this.code = code;
    this.response = response;
  }
}

/** rcp 网络层错误码（连接类失败，可轮换 IP 重试） */
const RETRYABLE_CODES: Set<number> = new Set<number>([
  1007900006, // Couldn't resolve host name
  1007900007, // Couldn't connect to server
  1007900028, // Timeout was reached
  1007900035, // SSL connect error
  1007900052, // Server returned nothing
  1007900055, // Failed sending data to the peer
  1007900056, // Failure when receiving data from the peer
  1007900060, // SSL peer certificate or SSH remote key was not OK
]);

/** 直连自检只执行一次（多客户端共享） */
let selfCheckDone = false;

/**
 * 基于 rcp 的直连 HTTP 客户端（PixEz compat 模式同款机制）
 *
 * 原理（2026-09 在 SNI 阻断网络下逐项实测验证）：
 * 1. 把 URL 中的域名替换为 IP 池中的地址 —— libcurl 对 IP 字面量 URL 不发送 SNI 扩展，
 *    绕过基于 SNI 关键字的 GFW 阻断（发送真实 SNI 会被 RST）；
 * 2. 通过 Host 头携带真实域名，由服务端（pixiv CDN nginx 按 Host 路由 vhost）完成路由；
 * 3. SNI-less 下服务端返回默认证书（CN=pximg.net），故证书校验改为跳过，
 *    后续可通过 rcp ValidationCallback / CertificatePinning 做钉扎增强。
 */
export class DirectHttpClient {
  readonly baseURL: string;
  private readonly options: DirectClientOptions;
  /** 直连会话：跳过证书校验 + 显式忽略系统代理 */
  private readonly directSession: rcp.Session;
  /** 下载会话：直连同款设置 + 3 分钟传输超时（大文件经 GFW 节流链路耗时远超普通请求） */
  private readonly downloadSession: rcp.Session;
  /** 常规会话：系统证书校验 + 跟随系统代理（用于非直连域名） */
  private readonly systemSession: rcp.Session;
  /** 测速会话：直连同款设置 + 短超时（懒创建，仅网络设置页测速使用） */
  private speedSession: rcp.Session | undefined = undefined;

  constructor(options: DirectClientOptions = {}) {
    this.options = options;
    this.baseURL = options.baseURL || '';
    this.directSession = rcp.createSession({
      requestConfiguration: {
        proxy: 'no-proxy',
        security: {
          remoteValidation: 'skip'
        },
        // 4xx/5xx 也正常返回 Response（对齐 axios 行为），由客户端自行判断状态码
        processing: {
          validateResponse: (_response: rcp.Response): boolean => true
        },
        transfer: {
          timeout: { connectMs: 15000, transferMs: 30000 }
        }
      }
    });
    this.downloadSession = rcp.createSession({
      requestConfiguration: {
        proxy: 'no-proxy',
        security: {
          remoteValidation: 'skip'
        },
        processing: {
          validateResponse: (_response: rcp.Response): boolean => true
        },
        transfer: {
          // 实测 2MB 分块在可用连接上 <70s 完成；超过 90s 视为停滞连接，
          // 尽快轮换 IP 重试（旧值 180s 会让整轮停滞白白等满 3 分钟）
          timeout: { connectMs: DL_CONNECT_MS, transferMs: DL_TRANSFER_MS }
        }
      }
    });
    this.systemSession = rcp.createSession({
      requestConfiguration: {
        processing: {
          validateResponse: (_response: rcp.Response): boolean => true
        },
        transfer: {
          timeout: { connectMs: 15000, transferMs: 30000 }
        }
      }
    });
    if (!selfCheckDone) {
      selfCheckDone = true;
      this.selfCheck();
    }
  }

  get<T>(url: string, config: HttpConfig = {}): Promise<HttpResponse<T>> {
    return this.request<T>('GET', url, undefined, config, 0, 0);
  }

  post<T>(url: string, data?: string, config: HttpConfig = {}): Promise<HttpResponse<T>> {
    return this.request<T>('POST', url, data, config, 0, 0);
  }

  /**
   * 拉取图片等二进制资源（i.pximg.net 需携带 Referer 防盗链）
   */
  async fetchBytes(url: string, referer: string = IMAGE_REFERER): Promise<ArrayBuffer> {
    const config: HttpConfig = { headers: { 'Referer': referer } };
    const raw = await this.doFetch('GET', url, undefined, config, 0);
    return raw.body ? raw.body : new ArrayBuffer(0);
  }

  /**
   * Range 分段请求（下载器专用：走长超时下载会话）
   * - end 传 -1 表示开放区间（bytes=start-），可一次性拉取剩余全部
   * - 4xx/5xx 抛 HttpError（防止把错误页当图片写盘）
   * - totalSize 从 Content-Range 头解析（bytes start-end/TOTAL），无该头时为 -1
    * - onProgress：字节级接收回调（当前请求累计已收字节数），用于下载进度与停滞看门狗
    * - isCancelled：外部取消谓词（任务暂停），返回 true 时立刻断开在途请求并抛非重试错误
    * - ipSlot：IP 槽位（分块 worker 编号），直连时按 ips[ipSlot % 池大小] 取 IP，
    *   将并发连接摊到 DoH 刷出的多个 CDN IP 上（GFW 限速按连接+IP 双维度计，多 IP = 多条独立限速通道）
    */
  async fetchRange(url: string, start: number, end: number, referer: string = IMAGE_REFERER,
    onProgress?: (receivedBytes: number) => void,
    isCancelled?: () => boolean,
    ipSlot?: number): Promise<RangeFetchResult> {
    const rangeValue = end >= 0 ? `bytes=${start}-${end}` : `bytes=${start}-`;
    const raw = await this.doDownloadFetch(url, { 'Referer': referer, 'Range': rangeValue }, 0,
      onProgress, undefined, isCancelled, ipSlot);
    if (raw.statusCode >= 400) {
      throw new HttpError(`HTTP ${raw.statusCode} for ${url}`, undefined,
        { status: raw.statusCode, data: safeJson(raw) });
    }
    return {
      body: raw.body ? raw.body : new ArrayBuffer(0),
      totalSize: parseContentRangeTotal(raw.headers['content-range'])
    };
  }

  /**
   * 图片 CDN 单 IP 吞吐实测（网络设置页「CDN IP 测速」用）
   * 走真实下载链路（SNI-less + Host 路由 + Range 256KB 上限），destination 流式计数：
   * - ttfbMs：首字节到达耗时（TLS 握手 + 首包延迟的代理指标）
   * - speedKBs：ttfb 之后的平均吞吐（排除握手，反映 GFW 对该连接的持续限速水平）
   * - 超时/连接失败时已收字节仍计入样本（慢速链路也有分析价值），本方法不抛错
   */
  async speedTestIp(ip: string): Promise<IpSpeedResult> {
    if (this.speedSession === undefined) {
      this.speedSession = rcp.createSession({
        requestConfiguration: {
          proxy: 'no-proxy',
          security: {
            remoteValidation: 'skip'
          },
          processing: {
            validateResponse: (_response: rcp.Response): boolean => true
          },
          transfer: {
            timeout: { connectMs: SPEED_TEST_CONNECT_MS, transferMs: SPEED_TEST_TRANSFER_MS }
          }
        }
      });
    }
    const headers: Record<string, string> = {
      'Referer': IMAGE_REFERER,
      'Host': 'i.pximg.net',
      'Range': `bytes=0-${SPEED_TEST_RANGE_END}`
    };
    const rcRequest = new rcp.Request(`https://${ip}${SPEED_TEST_PATH}`, 'GET', headers as rcp.RequestHeaders);
    const start = Date.now();
    let received = 0;
    let ttfb = -1;
    rcRequest.destination = (incomingData: ArrayBuffer): void => {
      if (ttfb < 0) {
        ttfb = Date.now() - start;
      }
      received += incomingData.byteLength;
    };
    const result: IpSpeedResult = { ip: ip, ok: false, bytes: 0, totalMs: 0, ttfbMs: -1, speedKBs: 0, error: '' };
    try {
      const response = await this.speedSession.fetch(rcRequest);
      result.totalMs = Date.now() - start;
      result.bytes = received;
      result.ttfbMs = ttfb;
      if (response.statusCode >= 400) {
        result.error = `HTTP ${response.statusCode}`;
      } else if (received === 0) {
        result.error = 'empty body';
      } else {
        result.ok = true;
      }
    } catch (e) {
      const err = e as BusinessError;
      result.totalMs = Date.now() - start;
      result.bytes = received;
      result.ttfbMs = ttfb;
      result.error = `error ${err.code}`;
    }
    if (received > 0 && ttfb >= 0 && result.totalMs > ttfb) {
      result.speedKBs = Math.round(((received / 1024) / ((result.totalMs - ttfb) / 1000)) * 10) / 10;
    }
    return result;
  }

  /**
   * 下载链路请求：直连同款 SNI-less + Host 路由 + IP 轮换重试，
   * 走 downloadSession（90s 传输超时兜底 + 30s 停滞看门狗提前换线）。
   *
   * 断点续传：GFW 单连接限速可低至 ~10KB/s，2MB 分块常在 90s 传输上限内收不完；
   * 网络层重试时携带已收数据（resume 状态），Range 起点前移到 start+received 只补拉剩余区间，
   * 每个超时窗口内收到的字节全部保留，杜绝「收了 1.9MB 被杀后从零重下」的带宽浪费
   */
  private async doDownloadFetch(
    url: string,
    headers: Record<string, string>,
    retryCount: number,
    onProgress?: (receivedBytes: number) => void,
    resume?: ChunkResumeState,
    isCancelled?: () => boolean,
    ipSlot?: number
  ): Promise<RawResponse> {
    // 外部已取消（任务暂停）：抛非重试错误，由上层取消检查点收尾（重试递归也会经此终止）
    if (isCancelled !== undefined && isCancelled()) {
      throw new HttpError('download cancelled', 'CANCELLED');
    }
    pixivHosts.ensureRefreshed();
    const host = extractHost(url);
    const mode = networkModeState.getModeForHost(host);
    const isDirect = mode !== NetworkMode.STANDARD && PIXIV_DIRECT_DOMAINS.includes(host);

    // 解析调用方声明的区间（bytes=START-END / bytes=START-），续传时按已收字节数前移本次请求起点
    const rangeHeader = headers['Range'] ?? '';
    const rangeMatch = rangeHeader.match(/^bytes=(\d+)-(\d*)$/);
    const isResume = rangeMatch !== null && resume !== undefined && resume.received > 0;
    const chunks: ArrayBuffer[] = resume !== undefined ? resume.chunks : [];
    let received = resume !== undefined ? resume.received : 0;
    const attemptStart = (rangeMatch ? parseInt(rangeMatch[1]) : 0) + received;
    const attemptRange = rangeMatch === null ? rangeHeader
      : (rangeMatch[2] !== '' ? `bytes=${attemptStart}-${rangeMatch[2]}` : `bytes=${attemptStart}-`);

    const merged: Record<string, string> = {};
    const keys = Object.keys(headers);
    for (const key of keys) {
      merged[key] = headers[key];
    }
    merged['Range'] = attemptRange;
    let requestUrl = url;
    if (isDirect) {
      const ips = pixivHosts.getDirectIps(host);
      if (ips.length > 0) {
        // 按 worker 槽位摊开到 IP 池（多 IP = 多条独立限速通道）；重试轮换由 reportFailure 旋转池实现
        const ip = ipSlot !== undefined && ips.length > 1 ? ips[ipSlot % ips.length] : ips[0];
        requestUrl = url.replace(`://${host}`, `://${ip}`);
        merged['Host'] = host;
      }
    }

    const rcRequest = new rcp.Request(requestUrl, 'GET', merged as rcp.RequestHeaders);
    const session = isDirect ? this.downloadSession : this.systemSession;

    // 进度回调路径：用 destination 流式接收（官方语义：注册回调后 response.body 不再携带数据，须自行拼接）；
    // onProgress 上报跨尝试累计字节数（含历史尝试已收部分），供上层做单调进度
    let lastActiveAt = Date.now();
    const touch = (): void => { lastActiveAt = Date.now(); };
    if (onProgress) {
      rcRequest.destination = (incomingData: ArrayBuffer): void => {
        // 外部取消：立刻断开在途请求（数据分片是取消检测的最快路径）
        if (isCancelled !== undefined && isCancelled()) {
          session.cancel(rcRequest);
          return;
        }
        chunks.push(incomingData);
        received += incomingData.byteLength;
        touch();
        onProgress(received);
      };
    }

    // 停滞看门狗：仅在流式路径生效（每个数据分片都会刷新活跃时间）；超时未刷新说明连接已停滞，
    // 主动取消走重试轮换 IP（比等满 90s 传输超时快 3 倍）。探针无流式回调，靠连接/传输超时兜底；
    // 外部取消也借此定时器检测（无数据流动时的取消路径，最长 5s 延迟）
    let stallCancelled = false;
    const watchdog = isDirect && onProgress ? setInterval((): void => {
      if (isCancelled !== undefined && isCancelled()) {
        session.cancel(rcRequest);
        return;
      }
      if (Date.now() - lastActiveAt > DOWNLOAD_STALL_MS) {
        stallCancelled = true;
        session.cancel(rcRequest);
      }
    }, 5000) : -1;

    try {
      const response = await session.fetch(rcRequest);
      if (response.statusCode < 400) {
        pixivHosts.reportSuccess(host);
      }
      // 续传尝试必须拿到 206（区间生效）；若服务器无视 Range 返回 200（数据从 0 开始），
      // 已累积的数据与本次数据无法对齐，抛错交由上层（分块级重试）从零重下
      if (isResume && response.statusCode !== 206) {
        throw new HttpError(`resume attempt got ${response.statusCode} instead of 206`, undefined,
          { status: response.statusCode, data: undefined });
      }
      const raw = rcpToRaw(response);
      if (onProgress && chunks.length > 0) {
        raw.body = mergeChunks(chunks);
      }
      return raw;
    } catch (e) {
      // 外部取消：不做任何重试，直接向上抛（上层取消检查点收尾）
      if (isCancelled !== undefined && isCancelled()) {
        throw new HttpError('download cancelled', 'CANCELLED');
      }
      const err = e as BusinessError;
      if ((stallCancelled || RETRYABLE_CODES.has(err.code)) && retryCount < MAX_NETWORK_RETRIES) {
        pixivHosts.reportFailure(host);
        logger.warn(`download fetch ${stallCancelled ? 'stalled' : `error ${err.code}`} on ${host}, rotate ip and resume ${received}B (${retryCount + 1}/${MAX_NETWORK_RETRIES})`);
        await sleep(300 * (retryCount + 1));
        const state: ChunkResumeState = { chunks: chunks, received: received };
        return this.doDownloadFetch(url, headers, retryCount + 1, onProgress, state, isCancelled, ipSlot);
      }
      throw new HttpError(err.message || 'network error', String(err.code));
    } finally {
      if (watchdog !== -1) clearInterval(watchdog);
    }
  }

  /**
   * 启动时直连自检：验证 SNI-less + Host 路由链路是否可用（结果写入日志）
   */
  private async selfCheck(): Promise<void> {
    try {
      const start = Date.now();
      const res = await this.doFetch('GET', 'https://i.pximg.net/', undefined, {}, 0);
      const size = res.body ? res.body.byteLength : 0;
      logger.info(`self-check i.pximg.net: HTTP ${res.statusCode}, ${size} bytes, cost ${Date.now() - start}ms`);
    } catch (e) {
      logger.warn(`self-check i.pximg.net failed: ${JSON.stringify(e)}`);
    }
    this.echSelfCheck();
  }

  /**
   * 启动时 ECH 链路自检：对 app-api 发起 ECH 请求（决定性测试，结果写入日志）
   */
  private async echSelfCheck(): Promise<void> {
    try {
      const start = Date.now();
      const res = await echRequest('GET', 'https://app-api.pixiv.net/v1/walkthrough/illusts',
        { 'accept': 'application/json' });
      logger.info(`self-check ech app-api: HTTP ${res.status}, ${res.body.length} bytes, cost ${Date.now() - start}ms`);
    } catch (e) {
      logger.warn(`self-check ech app-api failed: ${e}`);
    }
  }

  private async request<T>(
    method: rcp.HttpMethod,
    url: string,
    data: string | undefined,
    config: HttpConfig,
    retryCount: number,
    retried401: number
  ): Promise<HttpResponse<T>> {
    const raw = await this.doFetch(method, url, data, config, retryCount);
    const status = raw.statusCode;

    // 401：交给上层刷新凭证后重试一次
    if (status === 401 && this.options.onUnauthorized && retried401 === 0) {
      const refreshed = await this.options.onUnauthorized(buildHeaderSnapshot(config, this.options));
      if (refreshed) {
        return this.request<T>(method, url, data, config, retryCount, 1);
      }
    }

    if (status >= 400) {
      throw new HttpError(
        `HTTP ${status} for ${url}`,
        undefined,
        { status: status, data: safeJson(raw) }
      );
    }

    return { status: status, data: parseBody<T>(raw), headers: toPlainHeaders(raw.headers) };
  }

  /**
   * 发送请求 + 网络层失败重试（重试前轮换直连 IP）
   * 按域名所属分组的连接模式路由（对齐上游 PixEz NetworkMode）：
   * - standard：系统网络（系统 DNS / 代理 / 正常证书校验）
   * - ech：ECH 域名优先 ECH 链路，失败回退 SNI-less
   * - compat：SNI-less + Host 头路由（用户自定义 hosts 优先）
   */
  private async doFetch(
    method: rcp.HttpMethod,
    url: string,
    data: string | undefined,
    config: HttpConfig,
    retryCount: number
  ): Promise<RawResponse> {
    pixivHosts.ensureRefreshed();
    const fullUrl = this.buildFullUrl(url, config.params);
    const host = extractHost(fullUrl);
    const mode = networkModeState.getModeForHost(host);
    const isDirect = mode !== NetworkMode.STANDARD && PIXIV_DIRECT_DOMAINS.includes(host);

    const headers: Record<string, string> = { ...(this.options.defaultHeaders || {}) };
    mergeHeaders(headers, config.headers);
    if (this.options.onRequest) {
      this.options.onRequest(headers);
    }

    // ECH 模式：ECH 域名优先走 ECH（真实 SNI 加密穿墙）；用户配置了自定义 hosts 时尊重用户选择
    if (mode === NetworkMode.ECH && ECH_API_DOMAINS.includes(host) && !pixivHosts.hasUserHost(host)) {
      try {
        return await this.doEchFetch(method, fullUrl, headers, data, config);
      } catch (e) {
        logger.warn(`ech fetch failed on ${host}, fallback to sni-less: ${e}`);
      }
    }

    // 直连域名（compat 或 ech 回退）：域名替换为池中首选 IP，真实域名放入 Host 头
    let requestUrl = fullUrl;
    if (isDirect) {
      const ips = pixivHosts.getDirectIps(host);
      if (ips.length > 0) {
        requestUrl = fullUrl.replace(`://${host}`, `://${ips[0]}`);
        headers['Host'] = host;
      }
    }

    try {
      const rcRequest = new rcp.Request(requestUrl, method, headers as rcp.RequestHeaders, data);
      const session = isDirect ? this.directSession : this.systemSession;
      const response = await session.fetch(rcRequest);
      if (response.statusCode < 400) {
        pixivHosts.reportSuccess(host);
      }
      return rcpToRaw(response);
    } catch (e) {
      const err = e as BusinessError;
      if (RETRYABLE_CODES.has(err.code) && retryCount < MAX_NETWORK_RETRIES) {
        pixivHosts.reportFailure(host);
        logger.warn(`network error ${err.code} on ${host}, rotate ip and retry (${retryCount + 1}/${MAX_NETWORK_RETRIES})`);
        await sleep(300 * (retryCount + 1));
        return this.doFetch(method, url, data, config, retryCount + 1);
      }
      throw new HttpError(err.message || 'network error', String(err.code));
    }
  }

  /**
   * ECH 链路请求（libpixech.so：rustls ECH + aws-lc-rs）
   */
  private async doEchFetch(
    method: rcp.HttpMethod,
    fullUrl: string,
    headers: Record<string, string>,
    data: string | undefined,
    config: HttpConfig
  ): Promise<RawResponse> {
    const body = data !== undefined ? encodeUtf8(data) : undefined;
    const res = await echRequest(method, fullUrl, headers, body, config.timeoutMs);
    const plainHeaders: Record<string, string | string[]> = {};
    for (const h of res.headers) {
      const key = h.name.toLowerCase();
      const existing = plainHeaders[key];
      plainHeaders[key] = existing === undefined ? h.value : `${existing}, ${h.value}`;
    }
    const bytes = res.body;
    const copy = new Uint8Array(bytes.length);
    copy.set(bytes);
    return {
      statusCode: res.status,
      headers: plainHeaders,
      body: copy.buffer,
      text: decodeUtf8(bytes),
    };
  }

  private buildFullUrl(url: string, params?: HttpConfig['params']): string {
    let absolute: string;
    if (url.startsWith('http://') || url.startsWith('https://')) {
      absolute = url;
    } else if (this.baseURL.endsWith('/') && url.startsWith('/')) {
      // 避免 baseURL 尾斜杠 + 路径头斜杠拼出 '//'（pixiv 网关对双斜杠路径返回 404）
      absolute = this.baseURL + url.substring(1);
    } else {
      absolute = `${this.baseURL}${url}`;
    }
    return params ? UrlUtils.buildUrl(absolute, params) : absolute;
  }
}

/**
 * 401 回调发生时请求头快照尚未保留（rcp.Request 不回传），
 * 用配置信息重建一份供上层判断发起账号
 */
function buildHeaderSnapshot(config: HttpConfig, options: DirectClientOptions): Record<string, string> {
  const headers: Record<string, string> = { ...(options.defaultHeaders || {}) };
  mergeHeaders(headers, config.headers);
  if (options.onRequest) {
    options.onRequest(headers);
  }
  return headers;
}

function mergeHeaders(target: Record<string, string>, extra?: Record<string, string>): void {
  if (!extra) {
    return;
  }
  const keys = Object.keys(extra);
  for (const key of keys) {
    target[key] = extra[key];
  }
}

function toPlainHeaders(rawHeaders: Record<string, string | string[]>): Record<string, string> {
  const result: Record<string, string> = {};
  const keys = Object.keys(rawHeaders);
  for (const key of keys) {
    const value = rawHeaders[key];
    if (typeof value === 'string') {
      result[key] = value;
    } else if (Array.isArray(value)) {
      result[key] = value.join(', ');
    }
  }
  return result;
}

function parseBody<T>(raw: RawResponse): T {
  const trimmed = raw.text.trim();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    try {
      return JSON.parse(trimmed) as T;
    } catch (_) {
      // 非合法 JSON 时按纯文本返回
    }
  }
  return raw.text as T;
}

function safeJson(raw: RawResponse): Object | undefined {
  const trimmed = raw.text.trim();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    try {
      return JSON.parse(trimmed) as Object;
    } catch (_) {
      return undefined;
    }
  }
  return undefined;
}

function rcpToRaw(response: rcp.Response): RawResponse {
  const text = response.toString();
  return {
    statusCode: response.statusCode,
    headers: response.headers as Record<string, string | string[]>,
    body: response.body,
    text: text === null ? '' : text,
  };
}

/** 把 destination 流式回调收到的分片拼成完整 ArrayBuffer（回调模式下 response.body 为空） */
function mergeChunks(chunks: ArrayBuffer[]): ArrayBuffer {
  let total = 0;
  for (const chunk of chunks) {
    total += chunk.byteLength;
  }
  const merged = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    merged.set(new Uint8Array(chunk), offset);
    offset += chunk.byteLength;
  }
  return merged.buffer;
}

function encodeUtf8(text: string): Uint8Array {
  return new util.TextEncoder().encodeInto(text);
}

function decodeUtf8(bytes: Uint8Array): string {
  if (bytes.length === 0) {
    return '';
  }
  return util.TextDecoder.create('utf-8').decodeToString(bytes);
}

function extractHost(url: string): string {
  const match = url.match(new RegExp('^https?://([^/:?]+)'));
  return match ? match[1] : '';
}

/** 解析 Content-Range 头（bytes start-end/TOTAL）中的总大小，缺失/畸形返回 -1 */
function parseContentRangeTotal(contentRange: string | string[] | undefined): number {
  const value = Array.isArray(contentRange) ? contentRange[0] : contentRange;
  if (!value) {
    return -1;
  }
  const match = value.match(/\/(\d+)$/);
  return match ? parseInt(match[1]) : -1;
}

function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve) => setTimeout(resolve, ms));
}
