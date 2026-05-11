import { queryDnsA } from './DoHClient';
import { createLogger } from './Logger';

const logger = createLogger('TestDoh');

export async function testPixivDns() {
  // 查询 www.pixivision.net 的 IP（RainChan 的策略）
  const ips = await queryDnsA('www.pixivision.net');
  logger.info('IPs for www.pixivision.net:', ips);

  // 查询 app-api.pixiv.net 的 IP
  const apiIps = await queryDnsA('app-api.pixiv.net');
  logger.info('IPs for app-api.pixiv.net:', apiIps);
}
