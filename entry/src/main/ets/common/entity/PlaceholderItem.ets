
export interface SharePlaceholderItem {
  tag: string;
  desc: ResourceStr;
  example: ResourceStr;
  isFullInsert?: boolean; // 标记是否为整段文本插入（如URL）
}


export interface SavePlaceholderItem {
  tag: string;
  desc: ResourceStr;
  example: ResourceStr;
}