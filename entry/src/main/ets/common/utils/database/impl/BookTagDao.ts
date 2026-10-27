
import AutoTable from '../AutoTable';
import { ValueType } from '../AbsTable';
import { Table } from '../decorator/Decorators';
import { Context } from '@kit.AbilityKit';
import BookTagInfo from '../../../entity/BookTagInfo';

/**
 * 收藏标签表
 */
@Table({ db: 'pixiv_manager', name: 'book_tag' })
export class BookTagTable extends AutoTable<BookTagInfo> {

  constructor(context: Context) {
    super(context, 'pixiv_manager', 'book_tag');
  }

  // 返回实体类
  protected getEntityClass(): new (...args: any[]) => BookTagInfo {
    return BookTagInfo;
  }

  /**
   * 获取主键列名
   */
  getColumnId(): string {
    return "id"
  }

  /**
   * 获取实体ID值
   */
  getEntityId(item: BookTagInfo): ValueType {
    return item.id
  }

  /**
   * 查询全部：按使用次数倒序 + 最近使用倒序（常用的排前面）
   */
  async queryAll(): Promise<BookTagInfo[]> {
    return this.query(this.getPredicates().orderByDesc('use_count').orderByDesc('last_used_at'))
  }

  /**
   * 按标签名查询
   */
  async queryByName(name: string): Promise<BookTagInfo[]> {
    return this.query(this.getPredicates().equalTo('name', name))
  }

  /**
   * 判断标签是否已收藏
   */
  async existsByName(name: string): Promise<boolean> {
    const results = await this.queryByName(name)
    return results.length > 0
  }

  /**
   * 按标签名删除
   */
  async deleteByName(name: string): Promise<number> {
    return this.deleteItem(this.getPredicates().equalTo('name', name))
  }
}
