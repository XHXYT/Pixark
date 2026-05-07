import { Column } from "../../utils/database/decorator/Decorators";

/**
 * 搜索历史记录
 */
export default class SearchHistoryInfo {
  /**
   * 记录ID，新增时设置为 null 可实现自增
   */
  @Column({
    name: 'id',
    type: 'INTEGER',
    isPrimaryKey: true,
    autoIncrement: true
  })
  id: number | null = null;

  /**
   * 搜索词
   */
  @Column({
    name: 'keyword',
    type: 'TEXT',
    notNull: true
  })
  keyword: string;

  /**
   * 访问时间
   */
  @Column({
    name: 'accessTime',
    type: 'INTEGER',
    notNull: true
  })
  accessTime: number;

  constructor(keyword: string, accessTime: number = new Date().getTime()) {
    this.keyword = keyword;
    this.accessTime = accessTime;
  }
}
