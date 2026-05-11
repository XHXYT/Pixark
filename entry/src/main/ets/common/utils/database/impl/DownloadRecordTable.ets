import AutoTable from '../AutoTable';
import { ValueType } from '../AbsTable';
import { Table } from '../decorator/Decorators';
import { Context } from '@kit.AbilityKit';
import DownloadRecordInfo from '../../../entity/DownloadRecordInfo';

/**
 * 下载记录表
 */
@Table({ db: 'pixiv_manager', name: 'download_record' })
export class DownloadRecordTable extends AutoTable<DownloadRecordInfo> {

  constructor(context: Context) {
    super(context, 'pixiv_manager', 'download_record');
  }

  protected getEntityClass(): Function {
    return DownloadRecordInfo;
  }

  getColumnId(): string {
    return "id";
  }

  getEntityId(item: DownloadRecordInfo): ValueType {
    return item.id as ValueType;
  }

  /**
   * 根据系统任务ID查询记录
   * (用于系统回调时更新数据库)
   */
  async queryByTaskId(task_id: string): Promise<DownloadRecordInfo | null> {
    const results = await this.query(this.getPredicates().equalTo('task_id', task_id));
    return results.length > 0 ? results[0] : null;
  }

  /**
   * 查询所有记录，按创建时间倒序
   */
  async queryAllDesc(): Promise<DownloadRecordInfo[]> {
    return this.query(this.getPredicates().orderByDesc('create_time'));
  }

  /**
   * 根据状态查询
   */
  async queryByStatus(status: number): Promise<DownloadRecordInfo[]> {
    return this.query(this.getPredicates().equalTo('status', status).orderByDesc('create_time'));
  }

  /**
   * 更新下载状态
   */
  async updateStatus(task_id: string, status: number): Promise<number> {
    const record = await this.queryByTaskId(task_id);
    if (record) {
      record.status = status;
      return this.update(record);
    }
    return -1;
  }

  /**
   * 删除指定关键词的历史记录
   */
  async deleteByID(id: number): Promise<number> {
    return this.deleteItem(this.getPredicates().equalTo('id', id))
  }

}

// 导出单例，方便在 ViewModel 中调用
let downloadRecordTable: DownloadRecordTable | null = null;

export const getDownloadRecordTable = (context: Context): DownloadRecordTable => {
  if (!downloadRecordTable) {
    downloadRecordTable = new DownloadRecordTable(context);
  }
  return downloadRecordTable;
};
