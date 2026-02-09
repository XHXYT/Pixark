/*

import { Context } from '@kit.AbilityKit';
import { Table } from '../decorator/Decorators';
import AutoTable from '../AutoTable';
import { ValueType } from '@kit.ArkData';
import { createLogger } from '../../Logger';

const logger = createLogger('TagCollectionTable');

*/
/**
 * 标签收藏记录
 *//*

@Table({ db: 'pixiv_manager', name: 'tag_collection' })
export class TagCollectionTable extends AutoTable<TagCollectionInfo> {

  constructor(context: Context) {
    super(context, 'pixiv_manager', 'video_collection');
  }

  protected getEntityClass(): new (...args: any[]) => TagCollectionInfo {
    return TagCollectionInfo;
  }

  */
/**
   * 获取主键列名 - 改为 id
   *//*

  getColumnId(): string {
    return 'id'
  }

  */
/**
   * 获取实体ID值
   *//*

  getEntityId(item: TagCollectionInfo): ValueType {
    return item.id
  }

  */
/**
   * 根据链接查询（保持原有业务逻辑）
   *//*

  async queryByLink(link: string): Promise<TagCollectionInfo> {
    logger.debug('queryByLink', 'queryByLink link = ' + link)
    let items = await this.query(this.getPredicates().equalTo('link', link))
    return items[0]
  }

  */
/**
   * 保存或更新（根据link判断是否存在）
   *//*

  async save(item: TagCollectionInfo): Promise<number> {
    logger.debug('save', 'save item = ' + JSON.stringify(item))
    let existingItem = await this.queryByLink(item.link)
    logger.debug('save', 'save existingItem=' + JSON.stringify(existingItem))
    let result;
    if (existingItem) {
      // 设置id，然后更新
      item.id = existingItem.id
      result = await this.update(item)
    } else {
      // id设为null，让数据库自增
      item.id = null
      result = await this.insert(item)
    }
    logger.debug('save', 'save result=' + result)
    return result
  }

  */
/**
   * 根据ID删除
   *//*

  async deleteById(id: number): Promise<number> {
    logger.debug('deleteById', 'deleteById id = ' + id)
    return this.deleteItem(this.getPredicates().equalTo('id', id))
  }

  */
/**
   * 根据标题查询收藏记录
   *//*

  async queryByName(title: string): Promise<TagCollectionInfo[]> {
    logger.debug('queryByName', 'queryByTitle title=' + title)
    // 使用模糊查询
    let items = await this.query(this.getPredicates().like('title', `%${title}%`))
    return items
  }

  */
/**
   * 根据标题精确查询
   *//*

  async queryByNameExact(title: string): Promise<TagCollectionInfo[]> {
    logger.debug('queryByNameExact', 'queryByTitleExact title=' + title)

    // 精确匹配
    let items = await this.query(this.getPredicates().equalTo('title', title))
    return items
  }

  */
/**
   * 根据标题查询单条记录（取第一条）
   *//*

  async queryOneByName(title: string): Promise<TagCollectionInfo> {
    logger.debug('queryOneByName', 'queryOneByTitle title=' + title)

    let items = await this.queryByNameExact(title)
    return items[0] || null
  }

}
*/
