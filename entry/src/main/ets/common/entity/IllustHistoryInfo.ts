import { Column } from "../../utils/database/decorator/Decorators"


/** TODO 待更改
 * 插画浏览历史记录实体类
 * 用于存储用户的插画浏览进度和历史记录
 */
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
   * 视频页面链接
   * 用作业务层面的唯一标识
   */
  @Column({ name: 'link', type: 'TEXT', notNull: true })
  link: string = ''

  /**
   * 视频标题
   * 用于显示在历史记录列表中
   */
  @Column({ name: 'title', type: 'TEXT', notNull: true })
  title: string = ''

  /**
   * 视频总时长（毫秒）
   * 用于计算播放进度百分比
   */
  @Column({ name: 'totalTime', type: 'INTEGER' })
  totalTime: number = 0

  /**
   * 当前播放进度（毫秒）
   * 记录用户上次播放到的位置
   */
  @Column({ name: 'currentTime', type: 'INTEGER' })
  currentTime: number = 0

  /**
   * 视频封面图片URL
   * 用于在历史记录列表中显示缩略图
   */
  @Column({ name: 'coverUrl', type: 'TEXT' })
  coverUrl: string = ''

  /**
   * 剧集列表索引
   * 对于多剧集视频，记录当前所在的剧集列表
   */
  @Column({ name: 'episodeListIndex', type: 'INTEGER' })
  episodeListIndex: number = 0

  /**
   * 剧集索引
   * 对于多剧集视频，记录当前播放的具体剧集
   */
  @Column({ name: 'episodeIndex', type: 'INTEGER' })
  episodeIndex: number = 0

  /**
   * 剧集名称
   * 当前播放剧集的显示名称
   */
  @Column({ name: 'episodeName', type: 'TEXT' })
  episodeName: string = ''

  /**
   * 插画 URL
   * 实际的视频流地址
   */
  @Column({ name: 'videoUrl', type: 'TEXT' })
  videoUrl: string = ''

  /**
   * 播放进度（0-1之间的小数）
   * 浮点数（小数）, 便于直接显示进度百分比
   */
  @Column({ name: 'videoProgress', type: 'REAL' })
  videoProgress: number = 0

  /**
   * 数据源标识
   * 用于区分不同视频源
   */
  @Column({ name: 'sourceKey', type: 'TEXT' })
  sourceKey: string = ''

  /**
   * 访问时间（时间戳）
   * 用于排序和统计，记录最后播放时间
   */
  @Column({ name: 'accessTime', type: 'INTEGER', notNull: true })
  accessTime: number = 0

  /**
   * 构造函数
   * @param link 视频链接（必填）
   * @param title 视频标题（可选，默认空字符串）
   * @param accessTime 访问时间（可选，默认当前时间）
   */
  constructor(link: string, title: string = '', accessTime: number = Date.now()) {
    this.link = link;
    this.title = title;
    this.accessTime = accessTime;
  }

}

