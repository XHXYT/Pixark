import { PixivTrendingTag } from "../../services/PixivTypes";

export type SuggestionType = 'illust_jump' | 'novel_jump' | 'user_jump' | 'keyword_search'

export class SuggestionItem {
  type: SuggestionType;
  text: string;  // 显示文案
  value: string; // 用于跳转 / 搜索的实际值

  constructor(type: SuggestionType, text: string, value: string) {
    this.type = type;
    this.text = text;
    this.value = value;
  }
}

export function generateSuggestions(input: string, trendingTags: PixivTrendingTag[], text: string[], isNovelMode: boolean = false): SuggestionItem[] {
  const list: SuggestionItem[] = [];
  const isNumber = /^\d+$/.test(input);

  if (isNumber) {
    // 根据模式决定展示插画还是小说的 Jump
    if (isNovelMode) {
      list.push({ type: 'novel_jump', text: `${text[0]} ID: ${input}`, value: input });
    } else {
      list.push({ type: 'illust_jump', text: `${text[0]} ID:${input}`, value: input });
    }
    list.push({ type: 'user_jump', text: `${text[1]} ID:${input}`, value: input });
    list.push({ type: 'keyword_search', text: `${text[2]}:${input}`, value: input });
  }

  const matchedTags = trendingTags.filter(t =>
  (t.translated_name?.includes(input)) || (t.tag?.includes(input))
  );

  const maxTags = 5;
  matchedTags.slice(0, maxTags).forEach(t => {
    list.push({ type: 'keyword_search', text: t.translated_name, value: t.tag || t.translated_name });
  });

  if (list.length === 0) {
    list.push({ type: 'keyword_search', text: `${text[2]}:${input}`, value: input });
  }

  return list;
}