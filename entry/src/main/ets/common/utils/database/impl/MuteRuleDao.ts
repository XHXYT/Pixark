
import AutoTable from '../AutoTable';
import { ValueType } from '../AbsTable';
import { Table } from '../decorator/Decorators';
import { Context } from '@kit.AbilityKit';
import MuteRuleInfo from '../../../entity/MuteRuleInfo';

/**
 * 屏蔽规则表（标签 / 画师 / 作品共用一张表，rule_type 区分）
 */
@Table({ db: 'pixiv_manager', name: 'mute_rule' })
export class MuteRuleTable extends AutoTable<MuteRuleInfo> {

  constructor(context: Context) {
    super(context, 'pixiv_manager', 'mute_rule');
  }

  // 返回实体类
  protected getEntityClass(): new (...args: any[]) => MuteRuleInfo {
    return MuteRuleInfo;
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
  getEntityId(item: MuteRuleInfo): ValueType {
    return item.id
  }

  /**
   * 查询全部规则，按创建时间倒序（新添加的排前面）
   */
  async queryAll(): Promise<MuteRuleInfo[]> {
    return this.query(this.getPredicates().orderByDesc('created_at'))
  }

  /**
   * 按类型查询规则
   */
  async queryByType(ruleType: string): Promise<MuteRuleInfo[]> {
    return this.query(this.getPredicates().equalTo('rule_type', ruleType).orderByDesc('created_at'))
  }

  /**
   * 判断规则是否已存在（同类型同 key 视为重复）
   */
  async exists(ruleType: string, targetKey: string): Promise<boolean> {
    const results = await this.query(
      this.getPredicates().equalTo('rule_type', ruleType).and().equalTo('target_key', targetKey)
    )
    return results.length > 0
  }

  /**
   * 按类型 + key 删除规则
   */
  async deleteByKey(ruleType: string, targetKey: string): Promise<number> {
    return this.deleteItem(
      this.getPredicates().equalTo('rule_type', ruleType).and().equalTo('target_key', targetKey)
    )
  }
}
