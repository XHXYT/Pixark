import { Context } from '@kit.AbilityKit';
import NovelHistoryInfo from '../../../entity/NovelHistoryInfo';
import AutoTable from '../AutoTable';
import { Table } from '../decorator/Decorators';


@Table({ db: 'pixiv_manager', name: 'novel_history' })
export class NovelHistoryTable extends AutoTable<NovelHistoryInfo> {
  constructor(context: Context) {
    super(context, 'pixiv_manager', 'novel_history');
  }

  protected getEntityClass(): Function {
    return NovelHistoryInfo;
  }

  getColumnId(): string {
    return 'id';
  }

  getEntityId(item: NovelHistoryInfo): number | string {
    return item.id;
  }

  /**
   * 保存或更新浏览记录
   * 直接传入 API 返回的 novel 对象即可
   */
  async saveOrUpdate(novel: any): Promise<void> {
    const novelId = novel.id;
    // 根据 novel_id 查询是否已存在记录
    const predicates = this.getPredicates().equalTo('novel_id', novelId);
    const existingList = await this.query(predicates);
    // 构建实体数据
    const info = new NovelHistoryInfo(novel);
    if (existingList.length > 0) {
      // 已存在：更新主键和访问时间，然后执行 update
      info.id = existingList[0].id;
      info.accessTime = new Date().getTime(); // 刷新浏览时间
      await this.update(info);
    } else {
      // 不存在：直接插入
      await this.insert(info);
    }
  }

  /**
   * 查询所有浏览记录，按最后浏览时间倒序
   */
  async queryAll(): Promise<NovelHistoryInfo[]> {
    let predicates = this.getPredicates().orderByDesc('access_time');
    return this.query(predicates);
  }

  /**
   * 根据标签模糊搜索历史记录
   * 利用我们存的 tagsStr 字段
   */
  async searchByTag(keyword: string, limit: number = 20): Promise<NovelHistoryInfo[]> {
    const predicates = this.getPredicates()
      .like('tags_str', `%${keyword}%`)
      .orderByDesc('access_time')
      .limitAs(limit);
    return this.query(predicates);
  }

  /**
   * 删除指定小说的浏览记录
   */
  async deleteByNovelId(novelId: number): Promise<number> {
    const predicates = this.getPredicates().equalTo('novel_id', novelId);
    return this.deleteItem(predicates);
  }

  async deleteByIds(ids: number[]): Promise<void> {
    const predicates = this.getPredicates().in('id', ids);
    await this.deleteItem(predicates);
  }

  /**
   * 清空所有浏览记录
   */
  async clearAll(): Promise<void> {
    await this.clearTable();
  }

}
