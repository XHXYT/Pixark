import { IIllustSwiperProvider } from '../common/entity/IllustDetailEntity';
import IllustHistoryInfo from '../common/entity/IllustHistoryInfo';
import NovelHistoryInfo from '../common/entity/NovelHistoryInfo';
import { appSettings } from '../common/entity/SettingsModel';
import { IllustHistoryTable } from '../common/utils/database/impl/IllustHistoryDao';
import { NovelHistoryTable } from '../common/utils/database/impl/NovelHistoryDao';
import { createLogger } from '../common/utils/Logger';
import { toastUtil } from '../common/utils/ToastUtils';
import { _PixState } from '../entryability/AppState';
import { PixivNovel } from '../services/PixivTypes';


const logger = createLogger('HistoryVM');

@ObservedV2
export class HistoryViewModel implements IIllustSwiperProvider {
  @Trace isEditMode: boolean = false;
  @Trace selectedIds: Set<number> = new Set();
  // 使用联合类型支持两种数据
  @Trace displayList: Array<IllustHistoryInfo | NovelHistoryInfo> = [];
  private allList: Array<IllustHistoryInfo | NovelHistoryInfo> = [];

  // 数据库懒加载，防止 Context 未初始化
  private illustDb: IllustHistoryTable | null = null;
  private novelDb: NovelHistoryTable | null = null;
  private keyword: string = '';

  private getIllustDB(): IllustHistoryTable {
    if (!this.illustDb) this.illustDb = new IllustHistoryTable(_PixState.Context);
    return this.illustDb;
  }

  private getNovelDB(): NovelHistoryTable {
    if (!this.novelDb) this.novelDb = new NovelHistoryTable(_PixState.Context);
    return this.novelDb;
  }

  private isNovelMode(): boolean {
    return appSettings.novel_mode;
  }

  // SwiperProvider 接口实现
  get illustIds(): number[] {
    if (this.isNovelMode()) return [];
    return this.displayList.map(i => Number((i as IllustHistoryInfo).pid));
  }
  get hasMore(): boolean { return false; }
  get isLoading(): boolean { return false; }
  async loadMore(): Promise<void> {}

  /** 拉取历史记录 */
  async fetchData() {
    try {
      if (this.isNovelMode()) {
        this.allList = await this.getNovelDB().queryAll();
      } else {
        this.allList = await this.getIllustDB().queryAllByAccessTimeDesc();
      }
      this.filter();
    } catch (e) {
      logger.error('fetchData Error', e);
    }
  }

  /**
   * 添加插画浏览记录
   */
  async addIllustHistory(pid: string, title: string, coverUrl: string) {
    try {
      const item = new IllustHistoryInfo(pid, title);
      item.coverUrl = coverUrl;
      item.accessTime = Date.now(); // 更新为当前访问时间
      await this.getIllustDB().addHistory(item);
    } catch (e) {
      logger.error('addIllustHistory Error', e);
    }
  }

  /**
   * 添加小说浏览记录
   * 直接传入 API 返回的 PixivNovel 对象即可，去重和转换逻辑在 DAO 层处理
   */
  async addNovelHistory(novel: PixivNovel) {
    try {
      await this.getNovelDB().saveOrUpdate(novel);
    } catch (e) {
      logger.error('addNovelHistory Error', e);
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
      return;
    }

    if (this.isNovelMode()) {
      // 小说：搜索标题、ID、作者、标签
      this.displayList = this.allList.filter(i => {
        const n = i as NovelHistoryInfo;
        return n.title.includes(this.keyword) ||
          String(n.novelId).includes(this.keyword) ||
          n.userName.includes(this.keyword) ||
          n.tagsStr.includes(this.keyword);
      });
    } else {
      // 插画：搜索标题、PID
      this.displayList = this.allList.filter(i => {
        const il = i as IllustHistoryInfo;
        return il.title.includes(this.keyword) || il.pid.includes(this.keyword);
      });
    }
  }

  /** 切换编辑模式 */
  toggleEditMode() {
    this.isEditMode = !this.isEditMode;
    this.selectedIds.clear();
  }

  toggleSelect(id: number) {
    if (this.selectedIds.has(id)) this.selectedIds.delete(id);
    else this.selectedIds.add(id);
  }

  isSelected(id: number): boolean {
    return this.selectedIds.has(id);
  }

  selectAllVisible() {
    this.selectedIds.clear();
    this.displayList.forEach(item => {
      if (item.id !== null) this.selectedIds.add(item.id!);
    });
  }

  deselectAll() { this.selectedIds.clear(); }
  getSelectedCount(): number { return this.selectedIds.size; }

  /** 编辑模式点击删除 */
  editDelete() {
    const count = this.selectedIds.size;
    if (count === 0) return;

    let message = count === 1
      ? `确定要删除该条历史记录吗？`
      : `确定要删除选中的 ${count} 条历史记录吗？`;

    toastUtil.showAlertDialog({
      title: '确认删除', message: message, alignment: DialogAlignment.Center,
      primaryButton: { value: $r('app.string.delete'), fontColor: Color.Red, action: async () => { await this.deleteSelected(); } },
      secondaryButton: { value: $r('app.string.cancel'), action: () => {} }
    });
  }

  /** 批量删除选中 */
  private async deleteSelected() {
    if (this.selectedIds.size === 0) return;
    const idsToDelete = Array.from(this.selectedIds);

    if (this.isNovelMode()) {
      await this.getNovelDB().deleteByIds(idsToDelete);
    } else {
      await this.getIllustDB().deleteByIds(idsToDelete);
    }

    this.toggleEditMode();
    await this.fetchData();
  }

  /** 清空所有历史 */
  clearAllHistory() {
    if (this.allList.length === 0) return;
    const typeStr = this.isNovelMode() ? $r('app.string.novel') : $r('app.string.illust');
    toastUtil.showAlertDialog({
      title: $r('app.string.clear_browse_history'),
      message: `确定要清空所有${typeStr}浏览历史吗？此操作不可恢复。`,
      alignment: DialogAlignment.Center,
      primaryButton: { value: $r('app.string.clear'), fontColor: Color.Red, action: async () => {
        if (this.isNovelMode()) await this.getNovelDB().clearAll();
        else await this.getIllustDB().clearAll();
        toastUtil.showToast({ message: `已清空${typeStr}浏览历史` });
        await this.fetchData();
      }},
      secondaryButton: { value: $r('app.string.cancel'), action: () => {} }
    });
  }

}

export const historyVM = new HistoryViewModel();
