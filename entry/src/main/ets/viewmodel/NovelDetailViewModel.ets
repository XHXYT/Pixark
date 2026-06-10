import { createLogger } from '../common/utils/Logger';
import { pixiv } from '../services/PixivService';
import { PixivNovel, PrevNovel, SeriesNavigation, TextNovel } from '../services/PixivTypes';
import { historyVM } from './HistoryViewModel';
import { UISettings } from '../common/entity/SettingsModel';
import { ReadingMode, getThemeConfig, isPrevNovel, isTextNovel } from '../common/entity/NovelModel';

const logger = createLogger('NovelDetailVM');


@ObservedV2
export class NovelDetailViewModel {
  @Trace novelInfo: PixivNovel | null = null;
  @Trace isLoading: boolean = true;
  @Trace isBookmarked: boolean = false;
  @Trace isBookmarkLoading: boolean = false;

  @Trace novelHtmlString: string = '';
  @Trace isTextLoading: boolean = false;
  @Trace hasTextLoaded: boolean = false;
  @Trace readingMode: ReadingMode = 'native'; // 默认使用原生渲染

  // 存储解析出的系列导航信息
  @Trace seriesNavigation: SeriesNavigation | null = null;

  @Trace fontSize: number = 18;
  @Trace lineHeight: number = 1.8;

  private novelId: number = 0;

  constructor(id: number) {
    this.novelId = id;
    logger.info(`Constructor created with ID: ${id}`);
  }

  async fetchDetail() {
    this.isLoading = true;
    try {
      const info = await pixiv.getNovelDetail(this.novelId);
      this.novelInfo = info;
      this.isBookmarked = info.is_bookmarked;
      if (this.novelInfo) {
        historyVM.addNovelHistory(this.novelInfo);
      }
    } catch (e) {
      logger.error(`fetchDetail error:`, JSON.stringify(e));
    } finally {
      this.isLoading = false;
    }
  }

  async fetchNovelContent() {
    if (this.hasTextLoaded) return;
    this.isTextLoading = true;
    try {
      logger.info(`Calling pixiv.webviewNovelHtml(${this.novelId})...`);
      const html = await pixiv.webviewNovelHtml(this.novelId);
      logger.info(`webviewNovelHtml SUCCESS. HTML length: ${html?.length || 0}`);
      this.novelHtmlString = html || '';
      // 从 HTML 中解析系列导航
      this.seriesNavigation = this.parseSeriesNavigation(html);
      if (this.seriesNavigation) {
        logger.info(`Parsed seriesNavigation: prev=${this.seriesNavigation.prevNovel?.id}, next=${this.seriesNavigation.nextNovel?.id}`);
      }
      this.hasTextLoaded = true;
    } catch (e) {
      logger.error('fetchNovelContent error:', e);
    } finally {
      this.isTextLoading = false;
    }
  }

  get novelHtml(): string {
    return this.novelHtmlString ?? '';
  }

  get novelText(): string {
    const html = this.novelHtmlString;
    if (!html) return '';

    try {
      const match = html.match(/"text"\s*:\s*"([\s\S]*?)"\s*[,}]/);
      if (match && match[1]) {
        const textHtml = JSON.parse(`"${match[1]}"`) as string;
        return textHtml
          .replace(/<br\s*\/?>/gi, '\n')
          .replace(/<p>/gi, '\n')
          .replace(/<\/p>/gi, '')
          .replace(/<[^>]+>/g, '')
          .replace(/&nbsp;/g, ' ')
          .replace(/&lt;/g, '<')
          .replace(/&gt;/g, '>')
          .replace(/&amp;/g, '&')
          .trim();
      }
    } catch (e) {
      logger.warn('Failed to parse novel text from JSON, fallback to regex.', e);
    }

    return html
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<p>/gi, '\n')
      .replace(/<\/p>/gi, '')
      .replace(/<[^>]+>/g, '')
      .replace(/&nbsp;/g, ' ')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&amp;/g, '&')
      .trim();
  }

  get prevNovel(): PrevNovel | null {
    return this.seriesNavigation?.prevNovel || null;
  }

  get hasPrev(): boolean {
    const prev = this.prevNovel;
    // 不仅要存在，还要有阅读权限 (viewable)
    return prev !== null && prev.viewable;
  }

  get hasNext(): boolean {
    const next = this.nextNovel;
    return next !== null;
  }

  get nextNovel(): PrevNovel | null {
    return this.seriesNavigation?.nextNovel || null;
  }

  get prevTitle(): string {
    return this.prevNovel?.title || '上一篇';
  }

  get nextTitle(): string {
    return '下一篇';
  }

  get isInSeries(): boolean {
    return !!this.novelInfo?.series;
  }

  get estimatedReadTime(): string {
    const len = this.novelInfo?.text_length || 0;
    const minutes = Math.ceil(len / 500);
    if (minutes < 60) return `约 ${minutes} 分钟`;
    return `约 ${Math.floor(minutes / 60)} 小时 ${minutes % 60} 分钟`;
  }

  // 从 HTML 字符串中提取 seriesNavigation 的 JSON
  private parseSeriesNavigation(html: string): SeriesNavigation | null {
    if (!html) return null;

    const key = '"seriesNavigation"';
    const startIndex = html.indexOf(key);
    if (startIndex === -1) return null;

    let braceStart = html.indexOf('{', startIndex + key.length);
    if (braceStart === -1) return null;

    let level = 0;
    let inString = false;
    let escape = false;

    for (let i = braceStart; i < html.length; i++) {
      const char = html[i];

      if (char === '\\' && !escape) {
        escape = true;
        continue;
      }

      if (char === '"' && !escape) {
        inString = !inString;
      }

      escape = false;

      if (!inString) {
        if (char === '{') {
          level++;
        } else if (char === '}') {
          level--;
          if (level === 0) {
            const jsonStr = html.substring(braceStart, i + 1);
            try {
              return JSON.parse(jsonStr) as SeriesNavigation;
            } catch (e) {
              logger.warn('Failed to parse seriesNavigation JSON string', e);
              return null;
            }
          }
        }
      }
    }

    return null;
  }

  getReadingCSS(): string {
    const t = getThemeConfig(UISettings.reading_color_mode);
    return `body{background:${t.bg};color:${t.text};font-size:${this.fontSize}px;line-height:${this.lineHeight};padding:20px;}`;
  }

  getReadingHTML(): string {
    const originalHtml = this.novelHtmlString;
    if (!originalHtml) {
      return `<!DOCTYPE html><html><head><style>${this.getReadingCSS()}</style></head><body><p>正文加载失败...</p></body></html>`;
    }
    const css = this.getReadingCSS();
    const injectTag = `</head>`;
    if (originalHtml.includes(injectTag)) {
      return originalHtml.replace(injectTag, `<style>${css}</style>${injectTag}`);
    } else {
      return `<!DOCTYPE html><html><head><style>${css}</style></head><body>${originalHtml}</body></html>`;
    }
  }

  formatDate(dateStr: string | undefined): string {
    if (!dateStr) return '';
    const date = new Date(dateStr);
    return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
  }

  formatWordCount(count: number): string {
    if (count < 1000) return `${count}字`;
    if (count < 10000) return `${(count / 1000).toFixed(1)}千字`;
    return `${(count / 10000).toFixed(1)}万字`;
  }

  async toggleBookmark() {
    if (this.isBookmarkLoading) return;
    this.isBookmarkLoading = true;
    try {
      if (this.isBookmarked) await pixiv.deleteNovelBookmark(this.novelId);
      else await pixiv.addNovelBookmark(this.novelId);
      this.isBookmarked = !this.isBookmarked;
    } catch (e) {
      logger.error(e);
    } finally {
      this.isBookmarkLoading = false;
    }
  }

}
