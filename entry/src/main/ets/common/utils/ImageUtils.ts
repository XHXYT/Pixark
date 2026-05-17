import { url } from '@kit.ArkTS';
import { PixivImage } from '../../services/PixivTypes';
import { createLogger } from './Logger';

/**
 * 图片处理工具类
 */
export class ImageUtils {

  private static readonly logger = createLogger('ImageUtils');

  /**
   * 重写 Pixiv 图片 URL 的域名 TODO 自定义图源(Image Host)
   * 用于实现"自定义图床"功能
   *
   * @param originalUrl Pixiv 原始图片 URL (例如 https://i.pximg.net/...)
   * @param customHost 自定义的图床 Host (例如 "i.pixiv.re" 或 "i.pixiv.cat")
   * @returns 替换后的 URL
   */
  static rewriteImageUrl(originalUrl: string, customHost?: string): string {
    // 如果没有设置自定义图床，直接返回原图地址
    if (!customHost) {
      return originalUrl;
    }

    // 简单的防错处理
    if (!originalUrl || originalUrl === '') {
      return '';
    }

    try {
      const finalUrl = url.URL.parseURL(originalUrl);
      // 只有当原地址是 Pixiv 官方图床域名时才替换
      if (finalUrl.hostname.includes('pximg.net')) {
        finalUrl.hostname = customHost;
        return finalUrl.toString();
      }
    } catch (e) {
      ImageUtils.logger.error(`Rewrite URL error: ${e}`);
    }

    return originalUrl;
  }

  /**
   * 根据画质获取图片 URL
   *
   * @param img Pixiv 图片对象
   * @param quality 画质要求 ('original' | 'large' | 'medium')
   * @returns 对应画质的图片 URL
   */
  static getImageUrlByQuality(img: PixivImage, quality: string): string {
    if (quality === 'original') {
      return img.original || img.large || img.medium || '';
    }

    if (quality === 'large') {
      return img.large || img.medium || '';
    }

    // medium 及其他情况兜底
    return img.medium || '';
  }

}
