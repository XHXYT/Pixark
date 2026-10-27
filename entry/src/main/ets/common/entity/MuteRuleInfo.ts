import { Column } from "../utils/database/decorator/Decorators";

/**
 * 屏蔽规则（统一一张表：标签 / 画师 / 作品）
 */
export default class MuteRuleInfo {
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
   * 规则类型：'tag' | 'user' | 'illust'
   */
  @Column({
    name: 'rule_type',
    type: 'TEXT',
    notNull: true
  })
  ruleType: string;

  /**
   * 目标 key：
   * tag    - 标签名原文；以 "re:" 开头表示正则（大小写不敏感）
   * user   - pixiv 用户 ID（字符串）
   * illust - pixiv 作品 ID（字符串）
   */
  @Column({
    name: 'target_key',
    type: 'TEXT',
    notNull: true
  })
  targetKey: string;

  /**
   * 展示名（用户名 / 作品标题；tag 规则与 targetKey 相同）
   */
  @Column({
    name: 'name',
    type: 'TEXT',
    notNull: true,
    defaultValue: ''
  })
  name: string;

  /**
   * 创建时间
   */
  @Column({
    name: 'created_at',
    type: 'INTEGER',
    notNull: true
  })
  createdAt: number;

  constructor(ruleType: string, targetKey: string, name: string = '', createdAt: number = new Date().getTime()) {
    this.ruleType = ruleType;
    this.targetKey = targetKey;
    this.name = name || targetKey;
    this.createdAt = createdAt;
  }
}
