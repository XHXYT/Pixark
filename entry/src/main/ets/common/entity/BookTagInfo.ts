import { Column } from "../utils/database/decorator/Decorators";

/**
 * 收藏标签（常用标签快捷搜索）
 */
export default class BookTagInfo {
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
   * 标签名原文
   */
  @Column({
    name: 'name',
    type: 'TEXT',
    notNull: true
  })
  name: string;

  /**
   * 标签翻译（收藏时若能取到则一并保存）
   */
  @Column({
    name: 'translation',
    type: 'TEXT',
    notNull: true,
    defaultValue: ''
  })
  translation: string;

  /**
   * 搜索使用次数（用于智能排序）
   */
  @Column({
    name: 'use_count',
    type: 'INTEGER',
    notNull: true,
    defaultValue: '0'
  })
  useCount: number;

  /**
   * 最近一次搜索时间
   */
  @Column({
    name: 'last_used_at',
    type: 'INTEGER',
    notNull: true,
    defaultValue: '0'
  })
  lastUsedAt: number;

  /**
   * 收藏时间
   */
  @Column({
    name: 'created_at',
    type: 'INTEGER',
    notNull: true
  })
  createdAt: number;

  constructor(name: string, translation: string = '', createdAt: number = new Date().getTime()) {
    this.name = name;
    this.translation = translation;
    this.useCount = 0;
    this.lastUsedAt = createdAt;
    this.createdAt = createdAt;
  }
}
