
import AutoTable from '../AutoTable';
import { ValueType } from '../AbsTable';
import { Table } from '../decorator/Decorators';
import { Context } from '@kit.AbilityKit';
import { createLogger } from '../../Logger';
import SearchHistoryInfo from '../../../entity/SearchHistoryInfo';

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
   * 查询所有搜索历史，按时间倒序（保留原样，不改动）
   */
  async queryAll(): Promise<SearchHistoryInfo[]> {
    return this.query(this.getPredicates().orderByDesc('accessTime'))
  }

  /**
   * 根据模式查询搜索历史
   * @param mode 当前模式 'illust' 或 'novel'，不传则查全部
   */
  async queryByMode(mode?: 'illust' | 'novel'): Promise<SearchHistoryInfo[]> {
    let predicates = this.getPredicates().orderByDesc('accessTime');
    if (mode) {
      predicates = predicates.equalTo('search_type', mode);
    }
    return this.query(predicates)
  }

  /**
   * 保存或更新搜索关键词，需带上类型
   */
  async saveOrUpdate(keyword: string, type: string = 'illust'): Promise<number> {
    logger.debug('saveOrUpdate', `keyword = ${keyword}, type =${type}`)

    // 查询时，必须同时匹配 keyword 和 type
    let results = await this.query(
      this.getPredicates().equalTo('keyword', keyword).and().equalTo('search_type', type)
    )

    let result;
    if (!results || results.length == 0) {
      // 插入时，传入类型
      result = await this.insert(new SearchHistoryInfo(keyword, type))
    } else {
      let info = results[0]
      info.accessTime = new Date().getTime()
      result = await this.update(info)
    }
    return result
  }

  // 清空历史也支持按类型清空
  async clearAll(type?: string): Promise<void> {
    if (type) {
      await this.deleteItem(this.getPredicates().equalTo('search_type', type))
    } else {
      await this.clearTable()
    }
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
   * 查询最近N条(默认为10)搜索历史
   */
  async queryRecent(limit: number = 10): Promise<SearchHistoryInfo[]> {
    return this.query(this.getPredicates().orderByDesc('accessTime').limitAs(limit))
  }

  /**
   * 临时修复方法：给 search_type 为 NULL 或 空字符串的历史记录补上默认值
   */
  async fixNullSearchType(): Promise<void> {
    let db = await this.futureDb;
    const sql = `UPDATE ${this.tableName} SET search_type = 'illust' WHERE search_type IS NULL OR search_type = ''`;
    await db.executeSql(sql);
    logger.info('修复 NULL search_type 完成');
  }

}

