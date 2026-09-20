/**
 * 网络连接模式全局状态（对齐上游 PixEz NetworkMode 机制）
 *
 * .ts 服务层不可 import .ets（SettingsModel），故设置页持久化的模式值
 * 在加载/变更时同步进本模块，DirectHttp 等直连层统一从读取路由。
 */

import { createLogger } from '../../common/utils/Logger';

const logger = createLogger('NetworkModeState');

/**
 * 连接模式
 * - ECH：ECH 直连（加密 ClientHello 穿墙，失败自动回退 COMPAT）
 * - COMPAT：兼容模式（SNI-less + Host 头路由 + DoH/IP 直连）
 * - STANDARD：标准模式（系统网络栈：系统 DNS / 系统代理 / 正常证书校验）
 */
export enum NetworkMode {
  ECH = 'ech',
  COMPAT = 'compat',
  STANDARD = 'standard',
}

/** 身份验证域名组（oauth / accounts） */
const AUTH_HOSTS: string[] = ['oauth.secure.pixiv.net', 'accounts.pixiv.net'];
/** API 服务域名组（app-api / www / sketch） */
const API_HOSTS: string[] = ['app-api.pixiv.net', 'www.pixiv.net', 'sketch.pixiv.net'];
/** 图片 CDN 域名组（i.pximg.net 主图床，s.pximg.net 静态资源） */
export const IMAGE_CDN_HOSTS: string[] = ['i.pximg.net', 's.pximg.net'];
/** 默认图床源 */
export const DEFAULT_IMAGE_HOST = 'i.pximg.net';

/**
 * 解析持久化的模式字符串
 * 缺省/非法值回退标准模式（对齐上游 PixEz NetworkMode.fromCode）
 */
export function parseNetworkMode(code: string | undefined | null): NetworkMode {
  if (code === NetworkMode.ECH || code === NetworkMode.COMPAT || code === NetworkMode.STANDARD) {
    return code;
  }
  return NetworkMode.STANDARD;
}

class NetworkModeState {
  /** 身份验证组模式（默认标准模式，对齐上游） */
  authMode: NetworkMode = NetworkMode.STANDARD;
  /** API 服务组模式（默认标准模式，对齐上游） */
  apiMode: NetworkMode = NetworkMode.STANDARD;
  /** 图床源（默认 i.pximg.net，可配置镜像/自定义 host） */
  pictureSource: string = DEFAULT_IMAGE_HOST;

  setAuthMode(mode: NetworkMode): void {
    this.authMode = mode;
    logger.info(`auth mode -> ${mode}`);
  }

  setApiMode(mode: NetworkMode): void {
    this.apiMode = mode;
    logger.info(`api mode -> ${mode}`);
  }

  setPictureSource(host: string): void {
    this.pictureSource = host;
    logger.info(`picture source -> ${host}`);
  }

  /**
   * 解析域名所属分组并返回应使用的连接模式
   * 非 Pixiv 域名一律 STANDARD（系统网络）
   */
  getModeForHost(host: string): NetworkMode {
    if (AUTH_HOSTS.includes(host)) {
      return this.authMode;
    }
    if (API_HOSTS.includes(host)) {
      return this.apiMode;
    }
    if (IMAGE_CDN_HOSTS.includes(host)) {
      // 图床源被替换为镜像/自定义 host 时走系统网络（改写后的 URL 不会命中本分支，双保险）；
      // API 组为标准模式时图片也走系统网络（上游 allowsImageSource 同款语义）
      if (this.pictureSource !== DEFAULT_IMAGE_HOST) {
        return NetworkMode.STANDARD;
      }
      return this.apiMode === NetworkMode.STANDARD ? NetworkMode.STANDARD : NetworkMode.COMPAT;
    }
    return NetworkMode.STANDARD;
  }
}

export const networkModeState = new NetworkModeState();
