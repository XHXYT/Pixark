import { PixivNovel, PixivTag } from "../../services/PixivTypes";
import { Column } from "../utils/database/decorator/Decorators";


export default class NovelHistoryInfo {
  @Column({ name: 'id', type: 'INTEGER', isPrimaryKey: true, autoIncrement: true })
  id: number | null = null;

  // 小说 ID，唯一约束
  @Column({ name: 'novel_id', type: 'INTEGER', unique: true, notNull: true })
  novelId: number = 0;

  // 小说标题
  @Column({ name: 'title', type: 'TEXT', notNull: true })
  title: string = '';

  // 封面图 URL
  @Column({ name: 'cover_url', type: 'TEXT' })
  coverUrl: string = '';

  // 字数 (方便在历史列表直接显示字数)
  @Column({ name: 'text_length', type: 'INTEGER' })
  textLength: number = 0;

  // 年龄限制 (0: 全年龄, 1: R18, 2: R18G)
  // 用于显示 R18 标识或进行本地过滤
  @Column({ name: 'x_restrict', type: 'INTEGER' })
  xRestrict: number = 0;

  // 作者 ID
  @Column({ name: 'user_id', type: 'INTEGER' })
  userId: number = 0;

  // 作者名称
  @Column({ name: 'user_name', type: 'TEXT' })
  userName: string = '';

  // 系列 ID (为0或null表示单篇)
  @Column({ name: 'series_id', type: 'INTEGER' })
  seriesId: number = 0;

  // 系列名称
  @Column({ name: 'series_title', type: 'TEXT' })
  seriesTitle: string = '';

  // 标签字符串 (将 PixivTag 数组转成逗号分隔存入，如 "原神,少女,可爱")
  // 本地历史搜索时可以直接用 LIKE 模糊匹配标签
  @Column({ name: 'tags_str', type: 'TEXT' })
  tagsStr: string = '';

  // 最后浏览时间戳
  @Column({ name: 'access_time', type: 'INTEGER', notNull: true })
  accessTime: number = 0;

  /**
   * 构造函数，直接传入 API 返回的 PixivNovel 对象
   */
  constructor(novel?: PixivNovel) {
    if (novel) {
      this.novelId = novel.id;
      this.title = novel.title || '';
      this.coverUrl = novel.image_urls?.medium || '';
      this.textLength = novel.text_length || 0;
      this.xRestrict = novel.x_restrict || 0;
      this.userId = novel.user?.id || 0;
      this.userName = novel.user?.name || '';
      this.seriesId = novel.series?.id || 0;
      this.seriesTitle = novel.series?.title || '';
      this.tagsStr = novel.tags?.map((tag: PixivTag) => tag.name).join(',') || '';
      this.accessTime = new Date().getTime();
    }
  }
}

