/**
 * GIF89a 动图编码器（纯 TS，无依赖）
 *
 * 输入为逐帧像素（HarmonyOS PixelMap.readPixelsToBuffer 读出的 BGRA 布局），
 * 流程：流行色量化建 256 色全局调色板 → 4bit 分桶最近色映射 → 逐帧 LZW 压缩。
 * 输出无限循环（NETSCAPE2.0 扩展）、整帧替换的动画 GIF 字节流。
 */

/** GIF 编码输入帧 */
export interface GifFrameInput {
  /** 像素数据（BGRA，每像素 4 字节，来自 PixelMap.readPixelsToBuffer） */
  pixels: Uint8Array;
  width: number;
  height: number;
  /** 该帧展示时长（ms） */
  delayMs: number;
}

/** 全局调色板大小（GIF 8 位索引） */
const PALETTE_SIZE = 256;
/** 颜色分桶位数（每通道 4bit → 4096 桶） */
const BUCKET_BITS = 4;
const BUCKET_PER_CHANNEL = 1 << BUCKET_BITS; // 16
const BUCKET_COUNT = BUCKET_PER_CHANNEL * BUCKET_PER_CHANNEL * BUCKET_PER_CHANNEL; // 4096
/** 建调色板时的采样帧数上限（帧数多时跨动画均匀抽样） */
const PALETTE_SAMPLE_FRAMES = 8;
/** LZW 码表大小上限（GIF 规范 12bit） */
const LZW_MAX_CODE = 4096;

/**
 * 编码动画 GIF
 * @param frames 帧序列（要求所有帧同尺寸）
 * @returns GIF 文件字节流
 */
export function encodeAnimatedGif(frames: GifFrameInput[]): ArrayBuffer {
  if (frames.length === 0) {
    throw new Error('gif: no frames');
  }
  const width = frames[0].width;
  const height = frames[0].height;
  const pixelsPerFrame = width * height;
  for (const frame of frames) {
    if (frame.width !== width || frame.height !== height) {
      throw new Error('gif: frame size mismatch');
    }
    if (frame.pixels.length < pixelsPerFrame * 4) {
      throw new Error('gif: pixel data too small');
    }
  }

  const palette = buildPalette(frames, pixelsPerFrame);
  const sink = new ByteSink(64 * 1024);

  // 头部 + 逻辑屏幕描述符（全局调色板 256 色）
  writeAscii(sink, 'GIF89a');
  writeU16LE(sink, width);
  writeU16LE(sink, height);
  sink.push(0xF7); // GCT flag=1 / 颜色分辨率=7 / 调色板大小=7(2^7+1=256)
  sink.push(0x00); // 背景色索引
  sink.push(0x00); // 像素宽高比
  for (let i = 0; i < PALETTE_SIZE; i++) {
    sink.push(palette[i * 3]);
    sink.push(palette[i * 3 + 1]);
    sink.push(palette[i * 3 + 2]);
  }

  // NETSCAPE 循环扩展：无限循环
  sink.push(0x21, 0xFF, 0x0B);
  writeAscii(sink, 'NETSCAPE2.0');
  sink.push(0x03, 0x01, 0x00, 0x00, 0x00);

  // 4bit 量化桶 → 调色板索引缓存（全帧序列共享）
  const indexCache = new Int16Array(BUCKET_COUNT).fill(-1);

  for (const frame of frames) {
    // 图形控制扩展：disposal=1（不处置），延迟单位 1/100s（下限 2 防浏览器钳制为 10ms 反而变慢）
    const delayCs = Math.max(2, Math.round(frame.delayMs / 10));
    sink.push(0x21, 0xF9, 0x04, 0x04);
    writeU16LE(sink, delayCs);
    sink.push(0x00, 0x00); // 无透明色 + 块终止

    // 图像描述符
    sink.push(0x2C);
    writeU16LE(sink, 0);
    writeU16LE(sink, 0);
    writeU16LE(sink, width);
    writeU16LE(sink, height);
    sink.push(0x00); // 无局部调色板 / 不隔行

    // LZW 压缩（最小码长 8）+ 255 字节子块封装
    sink.push(8);
    const indices = mapFrameToIndices(frame, palette, indexCache);
    const lzwBytes = lzwEncode(indices, 8);
    let offset = 0;
    while (offset < lzwBytes.length) {
      const count = Math.min(255, lzwBytes.length - offset);
      sink.push(count);
      sink.pushBytes(lzwBytes, offset, count);
      offset += count;
    }
    sink.push(0x00); // 子块终止
  }

  sink.push(0x3B); // Trailer
  return sink.toArrayBuffer();
}

/**
 * 流行色量化：跨帧采样像素，按 4bit/通道分桶统计，
 * 取人数最多的桶求均值作为调色板色（不足 256 色时补黑）
 */
function buildPalette(frames: GifFrameInput[], pixelsPerFrame: number): Uint8Array {
  const counts = new Uint32Array(BUCKET_COUNT);
  const sumR = new Uint32Array(BUCKET_COUNT);
  const sumG = new Uint32Array(BUCKET_COUNT);
  const sumB = new Uint32Array(BUCKET_COUNT);

  // 跨动画均匀抽取参与采样的帧
  const sampleFrames: GifFrameInput[] = [];
  if (frames.length <= PALETTE_SAMPLE_FRAMES) {
    for (const f of frames) {
      sampleFrames.push(f);
    }
  } else {
    const step = frames.length / PALETTE_SAMPLE_FRAMES;
    for (let i = 0; i < PALETTE_SAMPLE_FRAMES; i++) {
      sampleFrames.push(frames[Math.floor(i * step)]);
    }
  }

  for (const frame of sampleFrames) {
    const pixels = frame.pixels;
    // 隔 2 采样：360k 像素帧采 ~180k，多帧合计仍充分覆盖
    for (let i = 0; i < pixelsPerFrame; i += 2) {
      const p = i * 4;
      const r = pixels[p + 2];
      const g = pixels[p + 1];
      const b = pixels[p];
      const key = ((r >> BUCKET_BITS) << (BUCKET_BITS * 2))
        | ((g >> BUCKET_BITS) << BUCKET_BITS)
        | (b >> BUCKET_BITS);
      counts[key]++;
      sumR[key] += r;
      sumG[key] += g;
      sumB[key] += b;
    }
  }

  // 非空桶索引按人数排序
  const usedBuckets: number[] = [];
  for (let key = 0; key < BUCKET_COUNT; key++) {
    if (counts[key] > 0) {
      usedBuckets.push(key);
    }
  }
  usedBuckets.sort((a: number, b: number): number => counts[b] - counts[a]);

  const palette = new Uint8Array(PALETTE_SIZE * 3);
  const colorCount = Math.min(PALETTE_SIZE, usedBuckets.length);
  for (let i = 0; i < colorCount; i++) {
    const key = usedBuckets[i];
    const count = counts[key];
    palette[i * 3] = Math.round(sumR[key] / count);
    palette[i * 3 + 1] = Math.round(sumG[key] / count);
    palette[i * 3 + 2] = Math.round(sumB[key] / count);
  }
  // 余下槽位保持 0（黑），不影响显示（未被映射到）
  return palette;
}

/**
 * 帧像素 → 调色板索引
 * 用 4bit 桶中心色查最近调色板色并缓存（同桶像素共享结果，逐像素开销 O(1)）
 */
function mapFrameToIndices(frame: GifFrameInput, palette: Uint8Array, indexCache: Int16Array): Uint8Array {
  const pixels = frame.pixels;
  const pixelsPerFrame = frame.width * frame.height;
  const indices = new Uint8Array(pixelsPerFrame);
  for (let i = 0; i < pixelsPerFrame; i++) {
    const p = i * 4;
    // 桶中心色（4bit 量化 + 半桶偏移）
    const r = (pixels[p + 2] & 0xF0) | 0x08;
    const g = (pixels[p + 1] & 0xF0) | 0x08;
    const b = (pixels[p] & 0xF0) | 0x08;
    const key = ((r >> BUCKET_BITS) << (BUCKET_BITS * 2))
      | ((g >> BUCKET_BITS) << BUCKET_BITS)
      | (b >> BUCKET_BITS);
    let index = indexCache[key];
    if (index < 0) {
      index = nearestPaletteIndex(r, g, b, palette);
      indexCache[key] = index;
    }
    indices[i] = index;
  }
  return indices;
}

/** 全调色板线性扫描最近色（加权欧氏距离，人眼对绿更敏感） */
function nearestPaletteIndex(r: number, g: number, b: number, palette: Uint8Array): number {
  let best = 0;
  let bestDist = Number.MAX_SAFE_INTEGER;
  for (let i = 0; i < PALETTE_SIZE; i++) {
    const dr = r - palette[i * 3];
    const dg = g - palette[i * 3 + 1];
    const db = b - palette[i * 3 + 2];
    const dist = dr * dr * 3 + dg * dg * 6 + db * db * 2;
    if (dist < bestDist) {
      bestDist = dist;
      best = i;
      if (dist === 0) {
        break;
      }
    }
  }
  return best;
}

/**
 * GIF 变体 LZW 压缩（码长 9-12bit 动态增长，表满发 CLEAR 重置）
 * @param indices 调色板索引序列
 * @param minCodeSize 最小码长（256 色固定 8）
 */
function lzwEncode(indices: Uint8Array, minCodeSize: number): Uint8Array {
  const clearCode = 1 << minCodeSize; // 256
  const eoiCode = clearCode + 1;      // 257
  const initCodeSize = minCodeSize + 1; // 9
  const writer = new LzwByteWriter(indices.length);
  const table = new Map<number, number>();

  let codeSize = initCodeSize;
  let next = eoiCode + 1; // 258
  writer.writeCode(clearCode, codeSize);
  let prefix = indices[0];

  for (let i = 1; i < indices.length; i++) {
    const k = indices[i];
    const key = (prefix << 8) | k;
    const found = table.get(key);
    if (found !== undefined) {
      prefix = found;
      continue;
    }
    writer.writeCode(prefix, codeSize);
    table.set(key, next);
    next++;
    if (next === LZW_MAX_CODE) {
      // 码表满：发 CLEAR 并复位（刚分配的 4095 仍是合法 12bit 码）
      writer.writeCode(clearCode, codeSize);
      table.clear();
      next = eoiCode + 1;
      codeSize = initCodeSize;
    } else if (next === (1 << codeSize)) {
      codeSize++;
    }
    prefix = k;
  }
  writer.writeCode(prefix, codeSize);
  writer.writeCode(eoiCode, codeSize);
  return writer.finish();
}

/** LZW 位流写出（LSB-first 位填充） */
class LzwByteWriter {
  private bytes: Uint8Array;
  private len: number = 0;
  private bitBuf: number = 0;
  private bitCount: number = 0;

  constructor(capacity: number) {
    // LZW 输出不会膨胀超过输入（实测约为输入的 30%-80%），按输入大小预分配
    this.bytes = new Uint8Array(Math.max(1024, capacity));
  }

  writeCode(code: number, width: number): void {
    this.bitBuf |= code << this.bitCount;
    this.bitCount += width;
    while (this.bitCount >= 8) {
      if (this.len >= this.bytes.length) {
        this.grow();
      }
      this.bytes[this.len++] = this.bitBuf & 0xFF;
      this.bitBuf >>>= 8;
      this.bitCount -= 8;
    }
  }

  finish(): Uint8Array {
    if (this.bitCount > 0) {
      if (this.len >= this.bytes.length) {
        this.grow();
      }
      this.bytes[this.len++] = this.bitBuf & 0xFF;
      this.bitBuf = 0;
      this.bitCount = 0;
    }
    return this.bytes.subarray(0, this.len);
  }

  private grow(): void {
    const next = new Uint8Array(this.bytes.length * 2);
    next.set(this.bytes);
    this.bytes = next;
  }
}

/** 可增长字节汇（GIF 文件级输出） */
class ByteSink {
  private buf: Uint8Array;
  private len: number = 0;

  constructor(capacity: number) {
    this.buf = new Uint8Array(Math.max(1024, capacity));
  }

  push(...bytes: number[]): void {
    this.ensure(bytes.length);
    for (let i = 0; i < bytes.length; i++) {
      this.buf[this.len++] = bytes[i];
    }
  }

  pushBytes(bytes: Uint8Array, from: number, count: number): void {
    this.ensure(count);
    for (let i = 0; i < count; i++) {
      this.buf[this.len++] = bytes[from + i];
    }
  }

  toArrayBuffer(): ArrayBuffer {
    return this.buf.buffer.slice(0, this.len);
  }

  private ensure(extra: number): void {
    if (this.len + extra <= this.buf.length) {
      return;
    }
    let cap = this.buf.length * 2;
    while (cap < this.len + extra) {
      cap *= 2;
    }
    const next = new Uint8Array(cap);
    next.set(this.buf);
    this.buf = next;
  }
}

function writeU16LE(sink: ByteSink, value: number): void {
  sink.push(value & 0xFF, (value >> 8) & 0xFF);
}

function writeAscii(sink: ByteSink, text: string): void {
  for (let i = 0; i < text.length; i++) {
    sink.push(text.charCodeAt(i));
  }
}
