import { PrevNovel, TextNovel } from '../../services/PixivTypes';


// 定义基础类型
export type ReadingTheme = 'light' | 'sepia' | 'dark';
export type ReadingMode = 'webview' | 'native';

// 阅读主题配置
export class ThemeConfig {
  bg: string = '';
  text: string = '';
  subtext: string = '';
  accent: string = '';
  divider: string = '';
  cardBg: string = '';
  topBarBg: string = '';

  constructor(data: ThemeConfig) {
    this.bg = data.bg;
    this.text = data.text;
    this.subtext = data.subtext;
    this.accent = data.accent;
    this.divider = data.divider;
    this.cardBg = data.cardBg;
    this.topBarBg = data.topBarBg;
  }
}

const THEME_MAP: Record<ReadingTheme, ThemeConfig> = {
  light: new ThemeConfig({
    bg: '#FFFFFF',
    text: '#333333',
    subtext: '#666666',
    accent: '#007DFF',
    divider: '#F0F0F0',
    cardBg: '#F8F8F8',
    topBarBg: '#F5F5F5'
  }),
  sepia: new ThemeConfig({
    bg: '#FBF5E5',
    text: '#5B4636',
    subtext: '#8B7355',
    accent: '#8B6914',
    divider: '#E8DCC8',
    cardBg: '#F5EDD5',
    topBarBg: '#EBE1C9'
  }),
  dark: new ThemeConfig({
    bg: '#1A1A2E',
    text: '#E0E0E0',
    subtext: '#999999',
    accent: '#4D8AFF',
    divider: '#2A2A3E',
    cardBg: '#222240',
    topBarBg: '#252540'
  })
};

/** 获取主题配置 */
export function getThemeConfig(theme: ReadingTheme): ThemeConfig {
  return THEME_MAP[theme];
}

/** 判断是否为 PrevNovel (带有 viewable 字段) */
export function isPrevNovel(obj: Object): obj is PrevNovel {
  return 'viewable' in obj && 'contentOrder' in obj;
}

/** 判断是否为 TextNovel (简单的 id/title 结构) */
export function isTextNovel(obj: Object): obj is TextNovel {
  return !isPrevNovel(obj) && 'id' in obj && 'title' in obj;
}
