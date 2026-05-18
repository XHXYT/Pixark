import { Context } from '@kit.AbilityKit';
import { Table } from '../decorator/Decorators';
import AutoTable from '../AutoTable';
import { ValueType } from '@kit.ArkData';
import { createLogger } from '../../Logger';
import IllustHistoryInfo from '../../../entity/IllustHistoryInfo';

const logger = createLogger('IllustHistoryDao');

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
   * 获取主键列名
   * @returns 主键列名 'id'
   */
  getColumnId(): string {
    return 'id'
  }

  /**
   * 获取实体的主键值
   * @param item 历史记录实体对象
   * @returns 实体的主键值
   */
  getEntityId(item: IllustHistoryInfo): ValueType {
    return item.id || -1
  }

  /**
   * 获取实体类类型，用于AutoTable实例化
   * @returns IllustHistoryInfo类的构造函数
   */
  protected getEntityClass(): Function {
    return IllustHistoryInfo;
  }

  /**
   * 保存或更新历史记录（基于 pid 判重）
   * 根据pid判断是否存在，存在则更新（如更新访问时间），不存在则新增
   * @param item 要保存的历史记录对象
   * @returns 操作影响的行数
   */
  async save(item: IllustHistoryInfo): Promise<number> {
    logger.debug('save item=' + JSON.stringify(item))
    let existingItems = await this.queryByPid(item.pid)
    logger.debug('save existingItems = ' + JSON.stringify(existingItems))
    let result: number = -1;
    if (existingItems && existingItems.length > 0) {
      // 存在则更新（取第一条），保留原有ID
      item.id = existingItems[0].id;
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
   * 根据插画PID查询历史记录
   * @param pid 插画ID
   * @returns 查找到的历史记录数组
   */
  async queryByPid(pid: string): Promise<IllustHistoryInfo[]> {
    logger.debug('queryByPid pid = ' + pid)
    return this.query(this.getPredicates().equalTo('pid', pid))
  }

  /**
   * 根据插画PID删除历史记录
   * @param pid 插画ID
   * @returns 删除的记录数量
   */
  async deleteByPid(pid: string): Promise<number> {
    logger.debug('deleteByPid pid = ' + pid)
    return this.deleteItem(this.getPredicates().equalTo('pid', pid))
  }

  /**
   * 根据多个插画PID批量查询历史记录
   * @param pids 插画ID数组
   * @returns 包含指定pid的历史记录数组
   */
  async queryByPids(pids: string[]): Promise<IllustHistoryInfo[]> {
    logger.debug('queryByPids pids = ' + JSON.stringify(pids))
    if (!pids || pids.length === 0) return [];
    return this.query(this.getPredicates().in('pid', pids))
  }

  /**
   * 根据多个ID批量删除历史记录 (主键批量删除，性能最优)
   * @param ids 记录ID数组
   * @returns 删除的记录数量
   */
  async deleteByIds(ids: (number | null)[]): Promise<number> {
    logger.debug('deleteByIds ids = ' + JSON.stringify(ids))
    // 过滤掉 null 并转为字符串数组，适配 in 查询
    const validIds = ids.filter(id => id !== null).map(String);
    if (validIds.length === 0) return 0;
    return this.deleteItem(this.getPredicates().in('id', validIds))
  }

  /**
   * 暴露给外界的添加历史记录接口
   * 如果已存在相同 pid 则更新，不存在则新增
   * @param item 要添加的历史记录对象
   * @returns 操作影响的行数
   */
  async addHistory(item: IllustHistoryInfo): Promise<number> {
    logger.debug('addHistory item=' + JSON.stringify(item))
    return this.save(item);
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
   * 查询最近增加的历史记录
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
