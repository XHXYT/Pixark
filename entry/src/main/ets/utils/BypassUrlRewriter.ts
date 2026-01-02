import { getPixivHostIp } from './HostMap';
import { url } from '@kit.ArkTS';

export interface RewriteResult {
  finalUrl: string;     // 最终要请求的 URL（host 可能被替换成 IP）
  extraHeaders: Record<string, string>; // 需要额外附加的 HTTP 头
}

/**
 * 重写 Pixiv 域名 URL，使用 IP 直连 + Host 头
 * - 如果目标域名不在映射表中，直接返回原 URL
 * - 否则，用替换后的 IP 重新构造 URL，并在 extraHeaders 里带上 Host
 */
export function rewritePixivUrl(originUrl: string): RewriteResult {
  if (!originUrl) {
    return { finalUrl: originUrl, extraHeaders: {} };
  }

  if (!originUrl.startsWith('https://')) {
    // 非 HTTPS 不处理，避免误伤别的地方的 HTTP 请求
    return { finalUrl: originUrl, extraHeaders: {} };
  }

  try {
    const urlObj = url.URL.parseURL(originUrl);
    const originHost = urlObj.hostname;

    // 查询映射 IP
    const mappedIp = getPixivHostIp(originHost);
    if (!mappedIp) {
      // 不在映射表里，不做任何处理
      return { finalUrl: originUrl, extraHeaders: {} };
    }

    // 替换 host 为 IP
    urlObj.hostname = mappedIp;

    const finalUrl = urlObj.toString();

    // 构造 Host 头
    const extraHeaders: Record<string, string> = {
      Host: originHost,
    };

    // 补一下 Referer（对 Pixiv 图片有帮助）
    if (originHost.endsWith('pximg.net')) {
      extraHeaders.Referer = 'https://www.pixiv.net/';
    }

    return { finalUrl, extraHeaders };
  } catch (e) {
    // URL 解析失败，直接返回原串
    return { finalUrl: originUrl, extraHeaders: {} };
  }
}
