import { Column } from "../utils/database/decorator/Decorators"


/**
 * 插画浏览历史记录实体类
 * 用于存储用户的插画浏览进度和历史记录
 */
@ObservedV2
export default class IllustHistoryInfo {

  /**
   * 记录ID，数据库自增主键
   * 新增记录时设置为null，数据库会自动分配ID
   */
  @Column({
    name: 'id',
    type: 'INTEGER',
    isPrimaryKey: true,
    autoIncrement: true
  })
  id: number | null = null

  /**
   * 插画 ID
   */
  @Column({ name: 'pid', type: 'TEXT', notNull: true })
  pid: string = ''

  /**
   * 插画标题
   */
  @Column({ name: 'title', type: 'TEXT' })
  title: string = ''

  /**
   * 插画封面图片URL
   * 用于在历史记录列表中显示缩略图
   */
  @Column({ name: 'coverUrl', type: 'TEXT' })
  coverUrl: string = ''

  /**
   * 访问时间（时间戳）
   * 用于排序和统计，记录最后播放时间
   */
  @Column({ name: 'accessTime', type: 'INTEGER', notNull: true })
  accessTime: number = 0

  /**
   * 构造函数
   * @param pid 插画 ID（必填）
   * @param title 插画标题（可选，默认空字符串）
   * @param accessTime 访问时间（可选，默认当前时间）
   */
  constructor(pid: string, title: string = '', accessTime: number = Date.now()) {
    this.pid = pid
    this.title = title;
    this.accessTime = accessTime;
  }

}

