import { http } from '@kit.NetworkKit';
import { util } from '@kit.ArkTS';
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { BusinessError } from '@kit.BasicServicesKit';

/** SauceNAO 单条 pixiv 匹配 */
export class SauceNaoMatch {
  illustId: number = 0;
  similarity: string = '';
}

const SAUCENAO_URL = 'https://saucenao.com/search.php';
const SAUCENAO_HOME = 'https://saucenao.com/';
const SAUCENAO_UA = 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36';

/** 拉起系统相册选择器选一张图，返回 uri（取消返回 null） */
export async function pickImageUri(): Promise<string | null> {
  const picker = new photoAccessHelper.PhotoViewPicker();
  const options: photoAccessHelper.PhotoSelectOptions = {
    MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
    maxSelectNumber: 1
  };
  const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
  if (!result.photoUris || result.photoUris.length === 0) {
    return null;
  }
  return result.photoUris[0];
}

/**
 * 读取并压缩图片：长边超过 720 时等比缩到 720，JPEG 75%（对齐 pixez）
 * 返回压缩后的 JPEG 字节
 */
export async function compressToJpegBuffer(uri: string): Promise<ArrayBuffer> {
  const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
  try {
    const source = image.createImageSource(file.fd);
    const info = await source.getImageInfo();
    const w = info.size.width;
    const h = info.size.height;
    let tw = w;
    let th = h;
    if (w >= 720 || h >= 720) {
      if (w > h) {
        th = 720;
        tw = Math.round(w * 720 / h);
      } else {
        tw = 720;
        th = Math.round(h * 720 / w);
      }
    }
    const decodeOptions: image.DecodingOptions = {
      desiredSize: { width: tw, height: th }
    };
    const pixelMap = await source.createPixelMap(decodeOptions);
    const packer = image.createImagePacker();
    const data: ArrayBuffer = await packer.packToData(pixelMap, { format: 'image/jpeg', quality: 75 });
    packer.release();
    pixelMap.release();
    source.release();
    return data;
  } finally {
    fileIo.closeSync(file);
  }
}

/**
 * multipart 上传图片到 SauceNAO 搜索，返回结果页 HTML
 */
export async function uploadToSauceNao(jpeg: ArrayBuffer): Promise<string> {
  const boundary = '----PixarkBoundary' + Date.now().toString();
  const encoder = new util.TextEncoder();
  const head = `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="image.jpg"\r\nContent-Type: image/jpeg\r\n\r\n`;
  const tail = `\r\n--${boundary}--\r\n`;
  const headBytes: Uint8Array = encoder.encodeInto(head);
  const tailBytes: Uint8Array = encoder.encodeInto(tail);
  const body = new ArrayBuffer(headBytes.byteLength + jpeg.byteLength + tailBytes.byteLength);
  const bodyView = new Uint8Array(body);
  bodyView.set(headBytes, 0);
  bodyView.set(new Uint8Array(jpeg), headBytes.byteLength);
  bodyView.set(tailBytes, headBytes.byteLength + jpeg.byteLength);

  const client = http.createHttp();
  try {
    const response = await client.request(SAUCENAO_URL, {
      method: http.RequestMethod.POST,
      header: {
        'Content-Type': `multipart/form-data; boundary=${boundary}`,
        'User-Agent': SAUCENAO_UA
      },
      extraData: body,
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 20000,
      readTimeout: 60000
    });
    if (response.responseCode !== 200) {
      throw new Error(`HTTP ${response.responseCode}`);
    }
    return response.result as string;
  } finally {
    client.destroy();
  }
}

/** 从文本中提取 pixiv 作品 ID（artworks/ 链接、illust_id 参数、pixiv_id 字段），无则 -1 */
function extractPixivId(text: string): number {
  const patterns: RegExp[] = [
    /pixiv\.net\/artworks\/(\d+)/,
    /pixiv\.net\/member_illust\.php[^"'\s]*illust_id=(\d+)/,
    /"pixiv_id"\s*:\s*"?(\d+)"?/
  ];
  for (const pattern of patterns) {
    const m = text.match(pattern);
    if (m) {
      return parseInt(m[1], 10);
    }
  }
  return -1;
}

/**
 * 解析 SauceNAO 结果页 HTML，提取 pixiv 匹配（按结果块，去重，保持顺序）
 * 仅保留能提取到 pixiv 作品 ID 的结果（对齐 pixez）
 */
export function parseSauceNaoResults(html: string): SauceNaoMatch[] {
  const results: SauceNaoMatch[] = [];
  const seen = new Set<number>();
  const blocks = html.split('class="result');
  for (let i = 1; i < blocks.length; i++) {
    const block = blocks[i];
    const illustId = extractPixivId(block);
    if (illustId <= 0 || seen.has(illustId)) {
      continue;
    }
    const simMatch = block.match(/([\d.]+)\s*%/);
    const item = new SauceNaoMatch();
    item.illustId = illustId;
    item.similarity = simMatch ? `${simMatch[1]}%` : '';
    seen.add(illustId);
    results.push(item);
  }
  return results;
}

/** 给 SauceNAO 返回的 HTML 注入 base，使相对资源仍解析到 saucenao.com */
export function injectBaseHref(html: string): string {
  if (html.includes('<base ')) {
    return html;
  }
  const baseTag = '<base href="' + SAUCENAO_HOME + '">';
  if (html.includes('<head>')) {
    return html.replace('<head>', '<head>' + baseTag);
  }
  if (html.includes('<HEAD>')) {
    return html.replace('<HEAD>', '<HEAD>' + baseTag);
  }
  return baseTag + html;
}

export { SAUCENAO_URL, SAUCENAO_HOME }
