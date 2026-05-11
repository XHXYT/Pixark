import { Column } from "../utils/database/decorator/Decorators";

/**
 * 下载记录实体
 */
@ObservedV2
export default class DownloadRecordInfo {
  /**
   * 记录ID，自增主键
   */
  @Column({ name: 'id', type: 'INTEGER', isPrimaryKey: true, autoIncrement: true })
  id: number | null = null;

  /**
   * 系统下载任务的唯一标识
   */
  @Column({ name: 'task_id', type: 'TEXT', notNull: true, unique: true }) // 唯一索引，防止重复记录
  task_id: string = '';

  /**
   * Pixiv 作品 ID
   */
  @Column({ name: 'illust_id', type: 'INTEGER', notNull: true })
  illust_id: number = 0;

  /**
   * 作品标题
   */
  @Column({ name: 'title', type: 'TEXT' })
  title: string = '';

  /**
   * 画师名字
   */
  @Column({ name: 'artist_name', type: 'TEXT' })
  artistName: string = '';

  /**
   * 画师头像 URL
   */
  @Column({ name: 'artist_avatar', type: 'TEXT' })
  artist_avatar: string = '';

  /**
   * 作品缩略图 URL (用于在列表显示)
   */
  @Column({ name: 'thumbnail', type: 'TEXT' })
  thumbnail: string = '';

  /**
   * 本地文件保存路径
   */
  @Column({ name: 'file_path', type: 'TEXT' })
  filePath: string = '';

  /**
   * 下载原图 URL
   */
  @Column({ name: 'url', type: 'TEXT' })
  url: string = '';

  /**
   * 下载状态 (0:进行中, 1:已完成, 2:失败, 3:已暂停)
   */
  @Trace
  @Column({ name: 'status', type: 'INTEGER', notNull: true })
  status: number = 0;

  /**
   * 下载进度
   */
  @Trace
  progress: number = 0;

  /**
   * 创建时间
   */
  @Column({ name: 'create_time', type: 'INTEGER', notNull: true })
  create_time: number = Date.now();

  constructor() {
  }
}
