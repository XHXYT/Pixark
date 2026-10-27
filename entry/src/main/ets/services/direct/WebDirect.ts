/**
 * WebView 直连桥（登录/注册等 Pixiv 网页在阻断网络下的直连加载方案）
 *
 * 原理：ArkWeb 的 WebSchemeHandler（API 12+）接管 WebView 的 https 网络层，
 * 请求经 DirectHttpClient 走 ECH/SNI-less 直连管道（复用 networkModeState 路由），
 * 响应回填给 WebView 渲染——浏览器 JS 环境与指纹是真实的，只有网络层被替换为直连。
 *
 * 接管范围：仅 PIXIV_DIRECT_DOMAINS 且该域名当前处于 ECH/COMPAT 模式；
 * 其余请求（第三方资源、标准模式）返回 false 放行，保持 WebView 默认网络栈。
 */

import { webview } from '@kit.ArkWeb';
import { WebNetErrorList } from '@ohos.web.netErrorList';
import { BusinessError } from '@kit.BasicServicesKit';
import { createLogger } from '../../common/utils/Logger';
import { DirectHttpClient, ForwardRawResponse } from './DirectHttp';
import { PIXIV_DIRECT_DOMAINS } from './PixivHosts';
import { NetworkMode, networkModeState } from './NetworkModeState';

const logger = createLogger('WebDirect');

/** 独立转发客户端：不注入 App UA / Bearer Token（网页请求自带浏览器头），路由仍按 networkModeState */
const webClient = new DirectHttpClient({});

/**
 * pixiv:// 登录回调监听（登录/账密登录页注册）
 * 背景：auth/pixiv/start 返回 302 Location: pixiv://account/login?code=...，
 * 内核跟随自定义 scheme 会尝试 applink 打开（16000019 失败 → 白屏"不正确的请求"），
 * 且 onLoadIntercept / onPageBegin 均收不到该导航，只能在桥内截获。
 */
let pixivSchemeCallback: ((url: string) => void) | null = null;

export function setPixivSchemeCallback(callback: ((url: string) => void) | null): void {
  pixivSchemeCallback = callback;
}

/** 单次读取 WebView 请求体的块大小 */
const BODY_CHUNK_SIZE = 65536;

/** 响应头透传排除名单：content-length 与实际回填字节可能不一致（防截断误判）+ 逐跳头 */
const SKIP_RESPONSE_HEADERS: Set<string> = new Set<string>([
  'content-length',
  'transfer-encoding',
  'connection',
  'keep-alive',
]);

/**
 * 桥内按域隔离的 cookie jar（domain -> name -> value）
 * 背景：拦截请求的内核 Cookie 头不做域隔离——app-api set 的 PHPSESSID 会被附到
 * accounts 请求上；账密登录时 accounts 的 ajax/login 轮换同名 PHPSESSID 后，
 * auth/start（app-api 域）拿到 accounts 会话 → 404"不正确的请求"。
 * 因此转发时以本表按域匹配重建 Cookie 头，不再信任内核的跨域 Cookie 头。
 * configCookieSync 双写保留，仅供页面 JS document.cookie 读取。
 */
const directCookieJar: Map<string, Map<string, string>> = new Map();

/** 清空桥内 cookie jar（登录页清 Cookie 时同步调用） */
export function clearDirectCookieJar(): void {
  directCookieJar.clear();
}

/** 解析单条 set-cookie 写入域 jar：host-only 归响应域，带 Domain= 归该域（须匹配响应域） */
function storeSetCookie(requestUrl: string, cookie: string): void {
  const host = extractHost(requestUrl);
  if (!host) {
    return;
  }
  const segments = cookie.split(';');
  const nameValue = segments[0];
  const eq = nameValue.indexOf('=');
  if (eq <= 0) {
    return;
  }
  const name = nameValue.substring(0, eq).trim();
  const value = nameValue.substring(eq + 1).trim();
  let domain = host;
  for (let i = 1; i < segments.length; i++) {
    const seg = segments[i].trim().toLowerCase();
    if (seg.startsWith('domain=')) {
      const d = segments[i].trim().substring('domain='.length).trim().replace(/^\./, '').toLowerCase();
      const hostLower = host.toLowerCase();
      // Domain 属性须为响应域本身或其父域，否则按 host-only 处理
      if (hostLower === d || hostLower.endsWith('.' + d)) {
        domain = d;
      }
      break;
    }
  }
  let jar = directCookieJar.get(domain);
  if (!jar) {
    jar = new Map<string, string>();
    directCookieJar.set(domain, jar);
  }
  // 空值 / "deleted" 为删除语义（pixiv 下线 cookie 的惯例写法）
  if (value === '' || value === 'deleted') {
    jar.delete(name);
  } else {
    jar.set(name, value);
  }
}

/** 按域匹配组装 Cookie 头：请求域命中 jar 域本身或为其子域 */
function buildCookieHeader(url: string): string {
  const host = extractHost(url).toLowerCase();
  if (!host) {
    return '';
  }
  const parts: string[] = [];
  directCookieJar.forEach((jar: Map<string, string>, domain: string) => {
    const d = domain.toLowerCase();
    if (host === d || host.endsWith('.' + d)) {
      jar.forEach((value: string, name: string) => {
        parts.push(`${name}=${value}`);
      });
    }
  });
  return parts.join('; ');
}

function extractHost(url: string): string {
  const match = url.match(new RegExp('^https?://([^/:?]+)'));
  return match ? match[1] : '';
}

/** 大小写不敏感取响应头（rcp/ECH 两条链路头名大小写不统一） */
function getHeaderRaw(headers: Record<string, string | string[]>, name: string): string | string[] | undefined {
  const keys = Object.keys(headers);
  for (const key of keys) {
    if (key.toLowerCase() === name) {
      return headers[key];
    }
  }
  return undefined;
}

/**
 * 读取 WebView 请求体流（POST/PUT 表单、JSON 等）
 * 流为空（GET）返回 undefined
 */
async function readRequestBody(stream: webview.WebHttpBodyStream | null): Promise<ArrayBuffer | undefined> {
  if (!stream) {
    return undefined;
  }
  await stream.initialize();
  const chunks: ArrayBuffer[] = [];
  let total = 0;
  while (!stream.isEof()) {
    const chunk = await stream.read(BODY_CHUNK_SIZE);
    if (chunk.byteLength === 0) {
      break;
    }
    chunks.push(chunk);
    total += chunk.byteLength;
  }
  if (total === 0) {
    return undefined;
  }
  const merged = new Uint8Array(total);
  let offset = 0;
  for (const chunk of chunks) {
    merged.set(new Uint8Array(chunk), offset);
    offset += chunk.byteLength;
  }
  return merged.buffer;
}

/**
 * 直连转发单个 WebView 请求并把结果回填给内核
 * - 浏览器请求头透传，accept-encoding 强制 identity（rcp/ECH 链路解压行为不一致，规避压缩协商歧义）
 * - set-cookie 双写：响应头透传 + configCookieSync 写入 WebView cookie 存储（接管后内核不再自动存储）
 * - 302 等状态原样回填，内核自行跟随重定向（下一跳会再次进入拦截器）
 */
async function forwardToDirect(
  request: webview.WebSchemeHandlerRequest,
  resourceHandler: webview.WebResourceHandler
): Promise<void> {
  const url = request.getRequestUrl();
  const method = request.getRequestMethod();
  const headers: Record<string, string> = {};
  for (const header of request.getHeader()) {
    headers[header.headerKey.toLowerCase()] = header.headerValue;
  }
  headers['accept-encoding'] = 'identity';
  // 域隔离 cookie：本域 jar 非空时重建 Cookie 头（内核附的跨域 Cookie 会污染会话）；
  // jar 为空保留原头兜底（页面 JS 经 document.cookie 设置的 cookie 仍在内核 jar）
  const ownCookie = buildCookieHeader(url);
  if (ownCookie !== '') {
    headers['cookie'] = ownCookie;
  }
  // 请求级排障日志（登录链路 404 / 丢 body / 丢 cookie 定位）：cookie 只记名不记值
  const cookieHeader = headers['cookie'] || '';
  const cookieNames = cookieHeader === '' ? 'none'
    : cookieHeader.split(';').map((c: string): string => c.trim().split('=')[0]).join(',');
  let body: ArrayBuffer | undefined = undefined;
  try {
    body = await readRequestBody(request.getHttpBodyStream());
  } catch (e) {
    logger.warn(`read body failed: ${method} ${url}: ${JSON.stringify(e)}`);
    try {
      resourceHandler.didFail(WebNetErrorList.ERR_CONNECTION_FAILED);
    } catch (e0) {
      // handler 已失效（请求已被内核取消），忽略
    }
    return;
  }
  logger.info(`>> ${method} ${url} body=${body ? body.byteLength : 0}B cookie=[${cookieNames}]`);
  let responseDelivered = false;
  try {
    const raw: ForwardRawResponse = await webClient.forward(method, url, headers, body);
    // 截获 302 Location: pixiv:// 登录回调：直接交给登录页提取 code，请求以 ABORTED 终止
    if (raw.status >= 300 && raw.status < 400) {
      const locValue = getHeaderRaw(raw.headers, 'location');
      const location = (Array.isArray(locValue) ? locValue[0] : locValue) || '';
      logger.info(`Redirect ${raw.status} on ${url}, location: ${location}`);
      if (location.startsWith('pixiv://') && pixivSchemeCallback) {
        logger.info(`pixiv scheme redirect intercepted: ${location}`);
        pixivSchemeCallback(location);
        resourceHandler.didFail(WebNetErrorList.ERR_ABORTED);
        return;
      }
    }
    const response = new webview.WebSchemeHandlerResponse();
    response.setStatus(raw.status);
    const keys = Object.keys(raw.headers);
    for (const key of keys) {
      if (SKIP_RESPONSE_HEADERS.has(key)) {
        continue;
      }
      const value = raw.headers[key];
      if (key.toLowerCase() === 'set-cookie') {
        // Set-Cookie 允许重复出现：逐条写入域隔离 jar（转发 Cookie 头的数据源）
        // 并同步写内核 cookie 存储（页面 JS document.cookie 读取）
        const cookies = Array.isArray(value) ? value : [value];
        logger.info(`set-cookie on ${url}: ${cookies.map((c: string): string => c.split('=')[0].trim()).join(',')}`);
        for (const cookie of cookies) {
          storeSetCookie(url, cookie);
          try {
            webview.WebCookieManager.configCookieSync(url, cookie);
          } catch (e) {
            logger.warn(`config cookie failed: ${cookie}`);
          }
        }
        continue;
      }
      response.setHeaderByName(key, Array.isArray(value) ? value.join(', ') : value, true);
    }
    // content-type 拆出 mimeType 与 charset
    const contentType = getHeaderRaw(raw.headers, 'content-type');
    const ctStr = Array.isArray(contentType) ? contentType[0] : contentType;
    if (ctStr) {
      const parts = ctStr.split(';');
      response.setMimeType(parts[0].trim());
      for (const part of parts) {
        const trimmed = part.trim().toLowerCase();
        if (trimmed.startsWith('charset=')) {
          response.setEncoding(part.trim().substring('charset='.length));
          break;
        }
      }
    }
    logger.info(`<< ${raw.status} ${method} ${url} ${raw.body.byteLength}B ${ctStr || ''}`);
    resourceHandler.didReceiveResponse(response);
    responseDelivered = true;
    try {
      resourceHandler.didReceiveResponseBody(raw.body);
      resourceHandler.didFinish();
    } catch (e2) {
      // 30x 已交付后内核立即跟随重定向会消费 handler，body/finish 阶段抛 17100021 属预期噪音
      logger.info(`handler consumed after delivered (${(e2 as BusinessError).code}), status=${raw.status}`);
    }
  } catch (e) {
    logger.warn(`web forward failed: ${method} ${url}: ${JSON.stringify(e)}`);
    if (!responseDelivered) {
      try {
        resourceHandler.didFail(WebNetErrorList.ERR_CONNECTION_FAILED);
      } catch (e3) {
        // handler 已失效（请求已被内核取消），忽略
      }
    }
  }
}

/**
 * 为 WebView 安装 https 拦截器（WebLogin/RegisterPage/Spotlight 等 Pixiv 网页组件用）
 * 幂等：重复安装会先清理旧 handler
 */
export function installWebSchemeHandler(controller: webview.WebviewController): void {
  try {
    controller.clearWebSchemeHandler();
  } catch (e) {
    // 首次安装时无旧 handler，忽略
  }
  const handler = new webview.WebSchemeHandler();
  handler.onRequestStart((request: webview.WebSchemeHandlerRequest,
    resourceHandler: webview.WebResourceHandler): boolean => {
    const url = request.getRequestUrl();
    const host = extractHost(url);
    // 非直连域名 / 标准模式：放行，走 WebView 默认网络栈
    if (host === '' || PIXIV_DIRECT_DOMAINS.indexOf(host) < 0
      || networkModeState.getModeForHost(host) === NetworkMode.STANDARD) {
      return false;
    }
    forwardToDirect(request, resourceHandler);
    return true;
  });
  controller.setWebSchemeHandler('https', handler);
  logger.info('web scheme handler installed (https -> direct pipeline)');
}
