
/**
 * Pixiv 域名 -> IP 映射表（静态 fallback）
 * 参考：
 * - PixEz-Flutter: lib/er/hoster.dart 中的 _constMap
 * - RainChan: 使用 www.pixivision.net 对应的 IP 来绕过 SNI
 */
export const PixivStaticHostMap: Record<string, string> = {
  // API 域名
  'oauth.secure.pixiv.net': '172.64.145.76',
  'app-api.pixiv.net': '172.64.145.17',
  'www.pixiv.net': '172.64.145.76',

  // 图片域名：可以尝试用 Cloudflare IP
  'i.pximg.net': '104.18.42.180',
  's.pximg.net': '104.18.42.180',
};

/**
 * 获取某个域名的映射 IP，如果没有则返回 null
 */
export function getPixivHostIp(originHost: string): string | null {
  return PixivStaticHostMap[originHost] ?? null;
}
