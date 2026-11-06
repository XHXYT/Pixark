import { rcp } from '@kit.RemoteCommunicationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { createLogger } from './Logger';
import { UrlUtils } from './UrlUtils';

const logger = createLogger('DoHClient');

/**
 * DoH JSON 接口列表（按优先级排序）
 * 阿里/腾讯的 DoH 在国内可直连；Cloudflare 仅海外网络可达，作为兜底
 */
interface DoHEndpoint {
  url: string;
  extraParams?: Record<string, string>;
}

const DOH_ENDPOINTS: DoHEndpoint[] = [
  { url: 'https://dns.alidns.com/resolve' },
  { url: 'https://doh.pub/dns-query' },
  { url: 'https://cloudflare-dns.com/dns-query', extraParams: { 'ct': 'application/dns-json' } },
];

/**
 * DoH JSON 响应类型（简化版）
 */
export interface DoHAnswer {
  name: string;
  type: number; // 1 = A, 65 = HTTPS
  data: string;
  ttl?: number;
}

interface DoHJsonResponse {
  Status?: number;
  Answer?: DoHAnswer[];
}

/** DoH 专用 rcp 会话（懒创建，5s 连接/传输超时） */
let dohSession: rcp.Session | undefined = undefined;

function getDohSession(): rcp.Session {
  if (dohSession === undefined) {
    dohSession = rcp.createSession({
      requestConfiguration: {
        // 4xx/5xx 也正常返回 Response，由调用方按状态码判断
        processing: {
          validateResponse: (_response: rcp.Response): boolean => true
        },
        transfer: {
          timeout: { connectMs: 5000, transferMs: 5000 }
        }
      }
    });
  }
  return dohSession;
}

/**
 * 查询 DoH JSON 接口，返回原始 Answer 列表（多端点依次回退）
 * @param hostname 要查询的域名，例如 "www.pixivision.net"
 * @param type 记录类型（'A' / '65' 等）
 * @returns 拿到非空 Answer 时返回；全部端点失败时返回 null
 */
export async function queryDnsAnswers(hostname: string, type: string): Promise<DoHAnswer[] | null> {
  for (const endpoint of DOH_ENDPOINTS) {
    const queryUrl = UrlUtils.buildUrl(endpoint.url, {
      name: hostname,
      type: type,
      ...(endpoint.extraParams || {}),
    });
    try {
      logger.debug(`Query DoH: ${queryUrl}`);
      const request = new rcp.Request(queryUrl, 'GET',
        { 'accept': 'application/dns-json' } as rcp.RequestHeaders);
      const response = await getDohSession().fetch(request);
      if (response.statusCode !== 200) {
        logger.warn(`DoH ${endpoint.url} HTTP ${response.statusCode}`);
        continue;
      }
      const parsed = JSON.parse(response.toString().trim()) as DoHJsonResponse;
      if (!parsed.Answer || parsed.Answer.length === 0) {
        logger.debug('DoH response has no Answer field');
        continue;
      }
      return parsed.Answer;
    } catch (e) {
      const err = e as BusinessError;
      logger.warn(`DoH query failed: ${endpoint.url} code=${err.code} ${err.message}`);
    }
  }
  logger.warn(`All DoH endpoints failed for ${hostname} type ${type}`);
  return null;
}

/**
 * 使用 DoH JSON 接口查询 A 记录
 * @param hostname 要查询的域名，例如 "www.pixivision.net"
 * @returns IPv4 列表，失败返回空数组
 */
export async function queryDnsA(hostname: string): Promise<string[]> {
  const answers = await queryDnsAnswers(hostname, 'A');
  if (answers === null) {
    return [];
  }
  const results: string[] = [];
  for (const ans of answers) {
    // 只取 A 记录(type=1)且看起来是 IPv4 的 data
    if (ans.type === 1 && isIPv4(ans.data)) {
      if (!results.includes(ans.data)) {
        results.push(ans.data);
      }
    }
  }
  if (results.length === 0) {
    logger.warn(`DoH got answers but no A record for ${hostname}`);
  }
  return results;
}

/**
 * 简单判断字符串是否是一个 IPv4 地址
 */
function isIPv4(s: string): boolean {
  const parts = s.split('.');
  if (parts.length !== 4) return false;
  return parts.every((part) => {
    const num = Number(part);
    return !Number.isNaN(num) && num >= 0 && num <= 255 && part === String(num);
  });
}
