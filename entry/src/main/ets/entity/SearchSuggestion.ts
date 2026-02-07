import { PixivTrendingTag } from "../services/PixivTypes";

export type SuggestionType = 'illust_jump' | 'user_jump' | 'keyword_search'

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

export function generateSuggestions(input: string, trendingTags: PixivTrendingTag[], text: string[]): SuggestionItem[] {
  const list: SuggestionItem[] = [];
  const isNumber = /^\d+$/.test(input);

  if (isNumber) {
    list.push(
      { type: 'illust_jump', text: `${text[0]} ID: ${input}`, value: input },
      { type: 'user_jump', text: `${text[1]} ID: ${input}`, value: input },
      { type: 'keyword_search', text: `${text[2]}: ${input}`, value: input }
    );
  }
  const matchedTags = trendingTags.filter(t =>
  // 翻译名存在且包含输入 -> 匹配
  (t.translated_name?.includes(input))
    || (t.tag?.includes(input))
  );
  // TODO 历史记录查询匹配

  const maxTags = 5;
  matchedTags.slice(0, maxTags).forEach(t => {
    list.push({
      type: 'keyword_search',
      text: t.translated_name,
      value: t.tag || t.translated_name
    });
  });
  if (list.length === 0) {
    list.push({
      type: 'keyword_search',
      text: `${text[2]}: ${input}`,
      value: input
    });
  }
  return list;
}