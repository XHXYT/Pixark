import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { createLogger } from '../../common/utils/Logger';
import { _PixState } from '../../entryability/AppState';
import { pixiv } from '../PixivService';

const logger = createLogger('ImageCache');

/** 内存缓存上限（张），超出入队最早者淘汰（不主动 release，可能仍在显示中，交由 GC 回收） */
const MEMORY_LIMIT = 24;

/**
 * 缓存解码结果
 */
export interface CachedImage {
  pixelMap: image.PixelMap;
  /** 原图宽度（px） */
  width: number;
  /** 原图高度（px） */
  height: number;
}

/**
 * pximg 图片缓存服务
 *
 * 背景：i.pximg.net / s.pximg.net 被运营商 SNI 阻断（真实 SNI 即 RST），
 * ImageKnife 等通用图片库走系统网络栈必然失败，因此图片统一经
 * DirectHttpClient.fetchBytes（SNI-less 直连 + Referer 防盗链）拉取字节，
 * 再本地解码为 PixelMap 交给组件渲染。
 *
 * 三级结构：
 * 1. 内存 LRU：url@目标解码宽度 → 解码后的 PixelMap；
 * 2. 磁盘缓存：filesDir/imgcache/<hash>.img 存原始字节（跨启动复用）；
 * 3. in-flight 合并：同 key 并发请求只发一次网络。
 */
class ImageCacheService {
  /** 内存 LRU（Map 插入序即访问序，命中时 delete+set 移到队尾） */
  private readonly memCache: Map<string, CachedImage> = new Map();
  /** 进行中的请求（同 key 合并） */
  private readonly inflight: Map<string, Promise<CachedImage>> = new Map();

  /**
   * 加载图片（内存 → 磁盘 → 网络），返回解码后的 PixelMap
   * @param url pximg 图片地址
   * @param targetWidthPx 期望解码宽度（px），按原图宽高比等比降采样，不会放大
   */
  async load(url: string, targetWidthPx: number): Promise<CachedImage> {
    const key = `${url}@${Math.round(targetWidthPx)}`;
    const cached = this.memCache.get(key);
    if (cached !== undefined) {
      // LRU touch：移到队尾
      this.memCache.delete(key);
      this.memCache.set(key, cached);
      return cached;
    }
    const running = this.inflight.get(key);
    if (running !== undefined) {
      return running;
    }
    const task = this.doLoad(url, targetWidthPx, key);
    this.inflight.set(key, task);
    try {
      return await task;
    } finally {
      this.inflight.delete(key);
    }
  }

  private async doLoad(url: string, targetWidthPx: number, key: string): Promise<CachedImage> {
    // 1. 磁盘命中：直接解码；解码失败（缓存损坏）则删除文件走网络
    const disk = this.readDisk(url);
    if (disk !== null) {
      try {
        const fromDisk = await this.decode(disk, targetWidthPx);
        this.putMemory(key, fromDisk);
        return fromDisk;
      } catch (e) {
        logger.warn(`disk cache corrupt, refetch: ${url}`);
        this.removeDisk(url);
      }
    }
    // 2. 网络拉取 + 写磁盘
    const bytes = await pixiv.fetchBytes(url);
    this.writeDisk(url, bytes);
    // 3. 解码 + 内存缓存
    const result = await this.decode(bytes, targetWidthPx);
    this.putMemory(key, result);
    return result;
  }

  /**
   * 解码为 PixelMap，按 targetWidthPx 等比降采样（不超过原始尺寸）
   */
  private async decode(buf: ArrayBuffer, targetWidthPx: number): Promise<CachedImage> {
    const source = image.createImageSource(buf);
    try {
      const info = await source.getImageInfo();
      const srcW = info.size.width;
      const srcH = info.size.height;
      if (srcW <= 0 || srcH <= 0) {
        throw new Error(`invalid image size ${srcW}x${srcH}`);
      }
      const scale = Math.min(1, targetWidthPx / srcW);
      const options: image.DecodingOptions = {
        desiredSize: {
          width: Math.max(1, Math.round(srcW * scale)),
          height: Math.max(1, Math.round(srcH * scale))
        }
      };
      const pixelMap = await source.createPixelMap(options);
      return { pixelMap: pixelMap, width: srcW, height: srcH };
    } finally {
      source.release();
    }
  }

  private putMemory(key: string, value: CachedImage): void {
    this.memCache.set(key, value);
    while (this.memCache.size > MEMORY_LIMIT) {
      const oldest = this.memCache.keys().next();
      if (oldest.done) {
        break;
      }
      this.memCache.delete(oldest.value);
    }
  }

  private getCacheDir(): string {
    return `${_PixState.Context.filesDir}/imgcache`;
  }

  private diskPath(url: string): string {
    return `${this.getCacheDir()}/${hashUrl(url)}.img`;
  }

  private ensureDir(): void {
    const dir = this.getCacheDir();
    if (!fileIo.accessSync(dir)) {
      fileIo.mkdirSync(dir, true);
    }
  }

  private readDisk(url: string): ArrayBuffer | null {
    const path = this.diskPath(url);
    try {
      if (!fileIo.accessSync(path)) {
        return null;
      }
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
      try {
        const stat = fileIo.statSync(file.fd);
        const buf = new ArrayBuffer(stat.size);
        fileIo.readSync(file.fd, buf);
        return buf;
      } finally {
        fileIo.closeSync(file);
      }
    } catch (e) {
      logger.warn(`read disk cache failed: ${e}`);
      return null;
    }
  }

  private writeDisk(url: string, buf: ArrayBuffer): void {
    try {
      this.ensureDir();
      const path = this.diskPath(url);
      if (fileIo.accessSync(path)) {
        return;
      }
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, buf);
      } finally {
        fileIo.closeSync(file);
      }
    } catch (e) {
      // 磁盘缓存写失败不影响显示
      logger.warn(`write disk cache failed: ${e}`);
    }
  }

  private removeDisk(url: string): void {
    try {
      const path = this.diskPath(url);
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path);
      }
    } catch (e) {
      logger.warn(`remove disk cache failed: ${e}`);
    }
  }
}

/**
 * cyrb53 哈希（53-bit），用于磁盘缓存文件名
 */
function hashUrl(url: string): string {
  let h1 = 0xdeadbeef;
  let h2 = 0x41c6ce57;
  for (let i = 0; i < url.length; i++) {
    const ch = url.charCodeAt(i);
    h1 = Math.imul(h1 ^ ch, 2654435761);
    h2 = Math.imul(h2 ^ ch, 1597334677);
  }
  h1 = Math.imul(h1 ^ (h1 >>> 16), 2246822507) ^ Math.imul(h2 ^ (h2 >>> 13), 3266489909);
  h2 = Math.imul(h2 ^ (h2 >>> 16), 2246822507) ^ Math.imul(h1 ^ (h1 >>> 13), 3266489909);
  return (4294967296 * (2097151 & h2) + (h1 >>> 0)).toString(16);
}

export const imageCache = new ImageCacheService();
