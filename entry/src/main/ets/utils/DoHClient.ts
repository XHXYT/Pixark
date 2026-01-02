import axios from '@ohos/axios';
import { createLogger } from './Logger';

const logger = createLogger('DoHClient');

/**
 * Cloudflare DoH JSON 接口地址列表
 */
const DOH_ENDPOINTS = [
  'https://cloudflare-dns.com/dns-query',
  'https://1.0.0.1/dns-query',
  'https://1.1.1.1/dns-query',
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
    ct: 'application/dns-json',
  };

  const results: string[] = [];

  for (const endpoint of DOH_ENDPOINTS) {
    try {
      logger.debug(`Query DoH: ${endpoint}?name=${hostname}`);

      const response = await axios.get<DoHJsonResponse>(endpoint, {
        params,
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
