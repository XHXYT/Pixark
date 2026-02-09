
export interface MoreItem {
  symbol: Resource;       // 图标资源
  label: ResourceStr;     // 标题
  name: string;           // 名称
  action: () => void;     // 点击事件
  isDanger?: boolean;     // 是否为危险操作（如退出登录，用于标红）
}