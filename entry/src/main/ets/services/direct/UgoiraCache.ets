import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { zlib } from '@kit.BasicServicesKit';
import { util } from '@kit.ArkTS';
import { createLogger } from '../../common/utils/Logger';
import { _PixState } from '../../entryability/AppState';
import { pixiv } from '../PixivService';
import { UgoiraMetadata } from '../PixivTypes';
import { GifFrameInput } from '../../common/utils/GifEncoder';

const logger = createLogger('UgoiraCache');

/** 动图单帧（已解码 PixelMap） */
export interface UgoiraFrame {
  pixelMap: image.PixelMap;
  /** 该帧展示时长（ms） */
  delay: number;
}

/** 磁盘清单（帧文件名 + 每帧延迟，用于磁盘命中时免请求 metadata） */
export interface UgoiraManifestFrame {
  /** 帧文件名（zip 内路径） */
  file: string;
  /** 该帧展示时长（ms） */
  delay: number;
}

interface UgoiraManifest {
  frames: UgoiraManifestFrame[];
}

/**
 * ugoira（动图）帧缓存服务
 *
 * 流程：getUgoiraMetadata（/v1/ugoira/metadata，zip 地址 + 每帧延迟）
 *   → fetchBytes 拉 zip（i.pximg.net 走 SNI-less 直连 + Referer 防盗链）
 *   → zlib.decompressFile 解压出逐帧 jpg
 *   → 按 metadata 顺序解码为 PixelMap 交给播放器逐帧轮播。
 *
 * 二级缓存：
 * 1. 内存：最近 2 个作品的帧序列（动图帧多，不宜多留）；
 * 2. 磁盘：filesDir/ugoiracache/<id>/ 存解压后的帧 + meta.json 清单，跨启动复用。
 * 3. in-flight 合并：同 id 并发请求只发一次网络。
 */
class UgoiraCacheService {
  /** 内存缓存（Map 插入序即访问序，超限淘汰队首） */
  private readonly memCache: Map<number, UgoiraFrame[]> = new Map();
  /** 内存缓存条目上限（每条为完整帧序列，控制在 2 个作品） */
  private static readonly MEMORY_LIMIT = 2;
  /** 进行中的请求（同 id 合并） */
  private readonly inflight: Map<number, Promise<UgoiraFrame[]>> = new Map();

  /**
   * 加载动图完整帧序列
   * @param illustId 作品 ID
   * @param targetWidthPx 期望解码宽度（px），按帧原始宽高比等比降采样，不会放大
   */
  async load(illustId: number, targetWidthPx: number): Promise<UgoiraFrame[]> {
    const cached = this.memCache.get(illustId);
    if (cached !== undefined) {
      // LRU touch：移到队尾
      this.memCache.delete(illustId);
      this.memCache.set(illustId, cached);
      return cached;
    }
    const running = this.inflight.get(illustId);
    if (running !== undefined) {
      return running;
    }
    const task = this.doLoad(illustId, targetWidthPx);
    this.inflight.set(illustId, task);
    try {
      return await task;
    } finally {
      this.inflight.delete(illustId);
    }
  }

  private async doLoad(illustId: number, targetWidthPx: number): Promise<UgoiraFrame[]> {
    const manifest = await this.ensureManifest(illustId);
    if (manifest.frames.length === 0) {
      throw new Error('empty ugoira manifest');
    }
    // 按清单顺序解码帧
    const dir = this.framesDir(illustId);
    const frames: UgoiraFrame[] = [];
    for (const item of manifest.frames) {
      const path = `${dir}/${item.file}`;
      if (!fileIo.accessSync(path)) {
        throw new Error(`frame missing: ${item.file}`);
      }
      const buf = this.readFile(path);
      const pixelMap = await this.decodeFrame(buf, targetWidthPx);
      frames.push({ pixelMap: pixelMap, delay: item.delay > 0 ? item.delay : 100 });
    }
    this.putMemory(illustId, frames);
    logger.info(`ugoira ${illustId} loaded: ${frames.length} frames`);
    return frames;
  }

  /**
   * 导出 GIF 合成用帧序列：磁盘缓存解出原始尺寸像素（BGRA，不降采样、不驻内存）
   */
  async loadGifFrames(illustId: number): Promise<GifFrameInput[]> {
    const manifest = await this.ensureManifest(illustId);
    if (manifest.frames.length === 0) {
      throw new Error('empty ugoira manifest');
    }
    const dir = this.framesDir(illustId);
    const frames: GifFrameInput[] = [];
    for (const item of manifest.frames) {
      const path = `${dir}/${item.file}`;
      if (!fileIo.accessSync(path)) {
        throw new Error(`frame missing: ${item.file}`);
      }
      const buf = this.readFile(path);
      const source = image.createImageSource(buf);
      try {
        const pixelMap = await source.createPixelMap();
        try {
          const info = await pixelMap.getImageInfo();
          const pixelBuf = new ArrayBuffer(info.size.width * info.size.height * 4);
          // readPixelsToBuffer 按 BGRA_8888 布局写出
          await pixelMap.readPixelsToBuffer(pixelBuf);
          frames.push({
            pixels: new Uint8Array(pixelBuf),
            width: info.size.width,
            height: info.size.height,
            delayMs: item.delay > 0 ? item.delay : 100
          });
        } finally {
          pixelMap.release();
        }
      } finally {
        source.release();
      }
    }
    return frames;
  }

  /** 磁盘清单不存在时拉 metadata + zip 解压落盘，返回清单 */
  private async ensureManifest(illustId: number): Promise<UgoiraManifest> {
    let manifest = this.readManifest(illustId);
    if (manifest === null) {
      const meta = await pixiv.getUgoiraMetadata(illustId);
      const zipBytes = await pixiv.fetchBytes(meta.zip_urls.medium);
      this.extractFrames(illustId, zipBytes, meta);
      manifest = this.readManifest(illustId);
    }
    if (manifest === null) {
      throw new Error('empty ugoira manifest');
    }
    return manifest;
  }

  /** 解码单帧 jpg，按 targetWidthPx 等比降采样（不超过原始尺寸） */
  private async decodeFrame(buf: ArrayBuffer, targetWidthPx: number): Promise<image.PixelMap> {
    const source = image.createImageSource(buf);
    try {
      const info = await source.getImageInfo();
      const srcW = info.size.width;
      const srcH = info.size.height;
      if (srcW <= 0 || srcH <= 0) {
        throw new Error(`invalid frame size ${srcW}x${srcH}`);
      }
      const scale = Math.min(1, targetWidthPx / srcW);
      const options: image.DecodingOptions = {
        desiredSize: {
          width: Math.max(1, Math.round(srcW * scale)),
          height: Math.max(1, Math.round(srcH * scale))
        }
      };
      return await source.createPixelMap(options);
    } finally {
      source.release();
    }
  }

  /** zip 解压到缓存目录并写入清单（已存在时先清空重建） */
  private extractFrames(illustId: number, zipBytes: ArrayBuffer, meta: UgoiraMetadata): void {
    const root = this.rootDir();
    if (!fileIo.accessSync(root)) {
      fileIo.mkdirSync(root, true);
    }
    const dir = this.framesDir(illustId);
    if (fileIo.accessSync(dir)) {
      fileIo.rmdirSync(dir);
    }
    fileIo.mkdirSync(dir, true);

    const zipPath = `${root}/${illustId}.zip`;
    const zipFile = fileIo.openSync(zipPath,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(zipFile.fd, zipBytes);
    } finally {
      fileIo.closeSync(zipFile);
    }
    try {
      zlib.decompressFile(zipPath, dir);
    } finally {
      // 无论成败都清理临时 zip
      try {
        fileIo.unlinkSync(zipPath);
      } catch (e) { /* 忽略 */ }
    }
    // 写清单（帧名 + 延迟）
    const manifest: UgoiraManifest = {
      frames: meta.frames.map((f): UgoiraManifestFrame => {
        const frame: UgoiraManifestFrame = { file: f.file, delay: f.delay };
        return frame;
      })
    };
    const manifestPath = `${dir}/meta.json`;
    const file = fileIo.openSync(manifestPath,
      fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
    try {
      fileIo.writeSync(file.fd, JSON.stringify(manifest));
    } finally {
      fileIo.closeSync(file);
    }
  }

  private readManifest(illustId: number): UgoiraManifest | null {
    try {
      const path = `${this.framesDir(illustId)}/meta.json`;
      if (!fileIo.accessSync(path)) {
        return null;
      }
      const raw = this.readFileText(path);
      const manifest = JSON.parse(raw) as UgoiraManifest;
      if (manifest === null || manifest.frames === undefined || manifest.frames.length === 0) {
        return null;
      }
      return manifest;
    } catch (e) {
      logger.warn(`read manifest failed: ${e}`);
      return null;
    }
  }

  private readFile(path: string): ArrayBuffer {
    const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
    try {
      const stat = fileIo.statSync(file.fd);
      const buf = new ArrayBuffer(stat.size);
      fileIo.readSync(file.fd, buf);
      return buf;
    } finally {
      fileIo.closeSync(file);
    }
  }

  private readFileText(path: string): string {
    const buf = this.readFile(path);
    return util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf));
  }

  private putMemory(illustId: number, frames: UgoiraFrame[]): void {
    this.memCache.set(illustId, frames);
    while (this.memCache.size > UgoiraCacheService.MEMORY_LIMIT) {
      const oldest = this.memCache.keys().next();
      if (oldest.done) {
        break;
      }
      this.memCache.delete(oldest.value);
    }
  }

  private rootDir(): string {
    return `${_PixState.Context.filesDir}/ugoiracache`;
  }

  private framesDir(illustId: number): string {
    return `${this.rootDir()}/${illustId}`;
  }
}

export const ugoiraCache = new UgoiraCacheService();
