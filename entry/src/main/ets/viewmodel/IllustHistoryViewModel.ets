import { Context } from '@kit.AbilityKit';
import IllustHistoryInfo from '../common/entity/IllustHistoryInfo';
import { IllustHistoryTable } from '../common/utils/database/impl/IllustHistoryDao';
import { createLogger } from '../common/utils/Logger';
import { toastUtil } from '../common/utils/ToastUtils';
import { _PixState } from '../entryability/AppState';

const logger = createLogger('IllustHistoryVM');


@ObservedV2
export class IllustHistoryViewModel {

  @Trace isEditMode: boolean = false;
  @Trace selectedIds: Set<number> = new Set();
  @Trace displayList: IllustHistoryInfo[] = [];

  private allList: IllustHistoryInfo[] = [];
  private db: IllustHistoryTable = new IllustHistoryTable(_PixState.Context);
  private keyword: string = '';

  /** 拉取历史记录 */
  async fetchData() {
    if (!this.db) return;
    try {
      this.allList = await this.db.queryAllByAccessTimeDesc();
      this.filter();
    } catch (e) {
      logger.error('fetchData Error', e);
    }
  }

  /** 搜索历史记录 */
  setKeyword(kw: string) {
    this.keyword = kw;
    this.filter();
  }

  private filter() {
    if (!this.keyword) {
      this.displayList = [...this.allList];
    } else {
      this.displayList = this.allList.filter(i =>
      i.title.includes(this.keyword) || i.pid.includes(this.keyword)
      );
    }
  }

  /** 切换编辑模式 */
  toggleEditMode() {
    this.isEditMode = !this.isEditMode;
    this.selectedIds.clear();
  }

  /** 切换选中状态 */
  toggleSelect(id: number) {
    if (this.selectedIds.has(id)) {
      this.selectedIds.delete(id);
    } else {
      this.selectedIds.add(id);
    }
  }

  /** 判断是否选中 */
  isSelected(id: number): boolean {
    return this.selectedIds.has(id);
  }

  /** 全选当前页面 */
  selectAllVisible() {
    this.selectedIds.clear();
    this.displayList.forEach(item => {
      if (item.id !== null) this.selectedIds.add(item.id!);
    });
  }

  /** 取消全选 */
  deselectAll() {
    this.selectedIds.clear();
  }

  /** 获取选中数量 */
  getSelectedCount(): number {
    return this.selectedIds.size;
  }

  /** 编辑模式点击删除 */
  editDelete() {
    const count = this.selectedIds.size;
    if (count === 0) return;

    let message = '';
    if (count === 1) {
      const item = this.displayList.find(i => i.id === Array.from(this.selectedIds)[0]);
      const title = item?.title || '未知作品';
      message = `确定要删除「${title}」的历史记录吗？`;
    } else {
      message = `确定要删除选中的 ${count} 条历史记录吗？`;
    }

    toastUtil.showAlertDialog({
      title: '确认删除',
      message: message,
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '删除',
        fontColor: Color.Red,
        action: async () => { await this.deleteSelected(); }
      },
      secondaryButton: { value: '取消', action: () => {} }
    });
  }

  /** 批量删除选中 */
  private async deleteSelected() {
    if (!this.db || this.selectedIds.size === 0) return;
    // 直接将 Set<number> 转为数组传给 DAO
    const idsToDelete = Array.from(this.selectedIds);
    await this.db.deleteByIds(idsToDelete);

    this.toggleEditMode();
    await this.fetchData();
  }

  /**
   * 添加浏览记录
   * @param pid 插画ID
   * @param title 插画标题
   * @param coverUrl 封面图URL
   */
  async addHistory(pid: string, title: string, coverUrl: string) {
    if (!this.db) return;
    const item = new IllustHistoryInfo(pid, title);
    item.coverUrl = coverUrl;
    item.accessTime = Date.now(); // 更新为当前访问时间

    await this.db.addHistory(item);
  }

  /** 清空所有历史 */
  clearAllHistory() {
    if (!this.db || this.allList.length === 0) return;
    toastUtil.showAlertDialog({
      title: '清空历史',
      message: '确定要清空所有浏览历史吗？此操作不可恢复。',
      alignment: DialogAlignment.Center,
      primaryButton: {
        value: '清空',
        fontColor: Color.Red,
        action: async () => {
          await this.db.clearAll();
          toastUtil.showToast({ message: '已清空浏览历史' });
          await this.fetchData();
        }
      },
      secondaryButton: { value: '取消', action: () => {} }
    });
  }

}

export const IllustHistoryVM = new IllustHistoryViewModel()
