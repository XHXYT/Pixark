
import { Context } from '@kit.AbilityKit';
import { Table } from '../decorator/Decorators';
import AutoTable from '../AutoTable';
import { ValueType } from '@kit.ArkData';
import { createLogger } from '../../Logger';
import IllustHistoryInfo from '../../../entity/IllustHistoryInfo';

const logger = createLogger('MoreViewModel');

/**
 * 插画浏览历史记录数据访问对象
 * 提供历史记录的增删改查操作
 */
@Table({ db: 'pixiv_manager', name: 'illust_history' })
export class IllustHistoryTable extends AutoTable<IllustHistoryInfo> {

  /**
   * 构造函数
   * @param context 应用上下文，用于数据库操作
   */
  constructor(context: Context) {
    super(context, 'pixiv_manager', 'illust_history');
  }

  /**
   * 获取主键列名 - 改为 id
   */
  getColumnId(): string {
    return 'id'
  }

  /**
   * 获取实体ID值
   */
  getEntityId(item: IllustHistoryInfo): ValueType {
    return item.id
  }

  /**
   * 获取实体类类型
   * @returns IllustHistoryInfo类的构造函数
   */
  protected getEntityClass(): new (...args: any[]) => IllustHistoryInfo {
    return IllustHistoryInfo;
  }

  /**
   * 根据插画链接查询历史记录
   * 用于判断某个插画是否已有播放记录
   * @param link 插画链接
   * @returns 查找到的历史记录，如果不存在返回undefined
   */
  async queryByLink(link: string): Promise<IllustHistoryInfo> {
    logger.debug('queryByLink', 'queryByLink link = ' + link)
    let items = await this.query(this.getPredicates().equalTo('link', link))
    return items[0]
  }

  /**
   * 保存或更新历史记录
   * 根据link判断是否存在，存在则更新，不存在则新增
   * @param item 要保存的历史记录对象
   * @returns 操作影响的行数
   */
  async save(item: IllustHistoryInfo): Promise<number> {
    logger.debug('save item=' + JSON.stringify(item))
    let existingItem = await this.queryByLink(item.link)
    logger.debug('save existingItem = ' + JSON.stringify(existingItem))
    let result;
    if (existingItem) {
      // 保留原有ID，更新其他字段
      item.id = existingItem.id
      result = await this.update(item)
    } else {
      // ID设为null，让数据库自动分配
      item.id = null
      result = await this.insert(item)
    }
    logger.debug('save result=' + result)
    return result
  }

  /**
   * 根据访问时间倒序查询所有历史记录
   * 最晚播放的记录排在前面
   * @returns 历史记录数组，按访问时间倒序排列
   */
  async queryAllByAccessTimeDesc(): Promise<IllustHistoryInfo[]> {
    logger.debug('queryAllByAccessTimeDesc')
    return this.query(this.getPredicates().orderByDesc('accessTime'))
  }

  /**
   * 根据访问时间正序查询所有历史记录
   * 最早播放的记录排在前面
   * @returns 历史记录数组，按访问时间正序排列
   */
  async queryAllByAccessTimeAsc(): Promise<IllustHistoryInfo[]> {
    logger.debug('queryAllByAccessTimeAsc')
    return this.query(this.getPredicates().orderByAsc('accessTime'))
  }

  /**
   * 根据标题模糊查询历史记录
   * 用于搜索功能
   * @param title 搜索关键词
   * @returns 包含关键词的历史记录数组
   */
  async queryByTitle(title: string): Promise<IllustHistoryInfo[]> {
    logger.debug('queryByTitle title = ' + title)
    return this.query(this.getPredicates().like('title', `%${title}%`))
  }

  /**
   * 根据数据源查询历史记录
   * 用于筛选特定来源的插画
   * @param sourceKey 数据源标识
   * @returns 指定数据源的历史记录数组
   */
  async queryBySourceKey(sourceKey: string): Promise<IllustHistoryInfo[]> {
    logger.debug('queryBySourceKey sourceKey = ' + sourceKey)
    return this.query(this.getPredicates().equalTo('sourceKey', sourceKey))
  }

  /**
   * 查询最近播放的历史记录
   * 用于首页显示最近观看的插画
   * @param limit 返回记录数量限制，默认10条
   * @returns 最近的历史记录数组
   */
  async queryRecent(limit: number = 10): Promise<IllustHistoryInfo[]> {
    logger.debug('queryRecent limit = ' + limit)
    return this.query(this.getPredicates().orderByDesc('accessTime').limitAs(limit))
  }

  /**
   * 根据ID删除历史记录
   * 用于精确删除某条记录
   * @param id 记录ID
   * @returns 删除的记录数量
   */
  async deleteById(id: number): Promise<number> {
    logger.debug('deleteById id = ' + id)
    return this.deleteItem(this.getPredicates().equalTo('id', id))
  }

  /**
   * 根据链接删除历史记录
   * 用于删除特定插画的所有播放记录
   * @param link 插画链接
   * @returns 删除的记录数量
   */
  async deleteByLink(link: string): Promise<number> {
    logger.debug('deleteByLink link=' + link)
    return this.deleteItem(this.getPredicates().equalTo('link', link))
  }

  /**
   * 清空所有历史记录
   * 用于隐私保护或重置功能
   * @returns 删除的记录数量
   */
  async clearAll(): Promise<number> {
    logger.debug('clearAll')
    return this.deleteItem(this.getPredicates())
  }

  /**
   * 完全重置历史记录表
   * 删除所有记录并重置自增ID
   */
  async resetTable(): Promise<void> {
    logger.debug('resetTable')
    return this.clearTable()
  }

}
