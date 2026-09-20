import axios from '@ohos/axios';
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
interface DoHJsonAnswer {
  name: string;
  type: number; // 1 = A
  data: string; // IP 字符串
  ttl?: number;
}

interface DoHJsonResponse {
  Status?: number;
  Answer?: DoHJsonAnswer[];
}

/**
 * 使用 Cloudflare DoH JSON 接口查询 A 记录
 * @param hostname 要查询的域名，例如 "www.pixivision.net"
 * @returns IP 列表，失败返回空数组
 */
export async function queryDnsA(hostname: string): Promise<string[]> {
  const params = {
    name: hostname,
    type: 'A',   // 查询 A 记录
  };

  const results: string[] = [];

  for (const endpoint of DOH_ENDPOINTS) {
    try {
      const queryUrl = UrlUtils.buildUrl(endpoint.url, {
        ...params,
        ...(endpoint.extraParams || {}),
      });
      logger.debug(`Query DoH: ${queryUrl}`);

      const response = await axios.get<DoHJsonResponse>(queryUrl, {
        headers: {
          accept: 'application/dns-json',
        },
        timeout: 5000,
      });

      const data = response.data;
      if (!data?.Answer) {
        logger.debug('DoH response has no Answer field');
        continue;
      }

      for (const ans of data.Answer) {
        // 只取 A 记录(type=1)且看起来是 IPv4 的 data
        if (ans.type === 1 && isIPv4(ans.data)) {
          if (!results.includes(ans.data)) {
            results.push(ans.data);
          }
        }
      }

      if (results.length > 0) {
        logger.debug(`DoH success, IPs for ${hostname}:`, results);
        return results;
      }
    } catch (e) {
      logger.warn(`DoH query failed: ${endpoint}`, e);
    }
  }

  logger.warn(`All DoH endpoints failed for ${hostname}`);
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
