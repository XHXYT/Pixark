
import AutoTable from '../AutoTable';
import { ValueType } from '../AbsTable';
import { Table } from '../decorator/Decorators';
import { Context } from '@kit.AbilityKit';
import { createLogger } from '../../Logger';
import SearchHistoryInfo from '../../../common/entity/SearchHistoryInfo';

const logger = createLogger('SearchHistoryTable');

/**
 * 搜索记录
 */
@Table({ db: 'pixiv_manager', name: 'search_history' })
export class SearchHistoryTable extends AutoTable<SearchHistoryInfo> {

  constructor(context: Context) {
    super(context, 'pixiv_manager', 'search_history');
  }

  // 返回实体类
  protected getEntityClass(): new (...args: any[]) => SearchHistoryInfo {
    return SearchHistoryInfo;
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
  getEntityId(item: SearchHistoryInfo): ValueType {
    return item.id
  }

  /**
   * 查询所有搜索历史，按时间倒序
   */
  async queryAll(): Promise<SearchHistoryInfo[]> {
    return this.query(this.getPredicates().orderByDesc('accessTime'))
  }

  /**
   * 保存或更新搜索关键词
   */
  async saveOrUpdate(keyword: string): Promise<number> {
    logger.debug('saveOrUpdate', 'saveOrUpdate keyword = ' + keyword)
    // 查询是否已存在
    let results = await this.query(this.getPredicates().equalTo('keyword', keyword))
    let result;
    if (!results || results.length == 0) {
      // 不存在则插入新记录
      result = await this.insert(new SearchHistoryInfo(keyword))
    } else {
      // 存在则更新访问时间
      let info = results[0]
      info.accessTime = new Date().getTime()
      result = await this.update(info)
    }
    logger.debug('saveOrUpdate', 'saveOrUpdate result = ' + result)
    return result
  }

  /**
   * 删除指定关键词的历史记录
   */
  async deleteByID(id: number): Promise<number> {
    return this.deleteItem(this.getPredicates().equalTo('id', id))
  }

  /**
   * 删除指定关键词的历史记录
   */
  async deleteByKeyword(keyword: string): Promise<number> {
    return this.deleteItem(this.getPredicates().equalTo('keyword', keyword))
  }

  /**
   * 清空所有搜索历史
   */
  async clearAll(): Promise<void> {
    await this.clearTable()
  }

  /**
   * 查询最近N条(默认为10)搜索历史
   */
  async queryRecent(limit: number = 10): Promise<SearchHistoryInfo[]> {
    return this.query(this.getPredicates().orderByDesc('accessTime').limitAs(limit))
  }

}

