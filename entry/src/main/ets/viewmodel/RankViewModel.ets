import { pixiv } from '../services/PixivService';
import { PixivIllust, PixivNovel } from '../services/PixivTypes';
import { createLogger } from '../common/utils/Logger';
import { appSettings } from '../common/entity/SettingsModel';
import { toastUtil } from '../common/utils/ToastUtils';
import { FunctionConstants } from '../common/constants/FunctionConstants';
import { RankTab } from '../common/entity/RankModel';
import { DetailPageParams, IIllustSwiperProvider } from '../common/entity/IllustDetailEntity';
import { PixState } from '../entryability/AppState';

const logger = createLogger('RankVM');

@ObservedV2
export class RankViewModel implements IIllustSwiperProvider {
  // 插画数据
  @Trace rankList: PixivIllust[] = [];
  private nextUrl: string = '';

  // 小说数据
  @Trace rankNovels: PixivNovel[] = [];
  private nextNovelUrl: string = '';

  @Trace currentMode: string = 'day';
  @Trace currentDate: string = '';
  @Trace isLoading: boolean = false;

  @Trace editingModes: string[] = [];
  @Trace editingSelected: Set<string> = new Set();

  get illustIds(): number[] {
    return appSettings.novel_mode ? this.rankNovels.map(n => n.id) : this.rankList.map(i => i.id);
  }

  get hasMore(): boolean {
    return appSettings.novel_mode ? !!this.nextNovelUrl : !!this.nextUrl;
  }

  // 获取当前激活的 Tab 列表
  get activeTabs(): RankTab[] {
    // 根据模式选择对应的配置数组
    const modes = appSettings.novel_mode
      ? (appSettings.novel_rank_modes || Object.keys(FunctionConstants.NOVEL_RANK_MODES))
      : appSettings.rank_modes;
    return modes.map(key => {
      const tab = new RankTab();
      tab.key = key;
      // 根据模式取对应的 label
      tab.label = appSettings.novel_mode
        ? (FunctionConstants.NOVEL_RANK_MODES[key] || key)
        : (FunctionConstants.ILLUST_RANK_MODES[key] || key);
      return tab;
    });
  }

  get isEmptyConfig(): boolean { return appSettings.rank_modes.length === 0; }

  changeMode(mode: string) {
    if (this.currentMode === mode) return;
    this.currentMode = mode;
    this.fetchRanking();
  }

  changeDate(date: Date) {
    this.currentDate = this.getFormattedDate(date);
    this.fetchRanking();
  }

  /** 加载排行榜数据 */
  async fetchRanking() {
    // 切换模式时，如果当前 mode 不再支持，自动回退
    // 获取当前模式下的可用 modes (优先用用户自定义的，没有则用全量默认)
    const supportedModes = appSettings.novel_mode
      ? (appSettings.novel_rank_modes || Object.keys(FunctionConstants.NOVEL_RANK_MODES))
      : (appSettings.rank_modes || Object.keys(FunctionConstants.ILLUST_RANK_MODES));

    if (supportedModes.length > 0 && !supportedModes.includes(this.currentMode)) {
      this.currentMode = supportedModes[0];
      logger.debug(`[fetchRanking] 当前mode不支持，自动回退至: ${this.currentMode}`);
    }

    if (this.isLoading) return;
    this.isLoading = true;
    this.rankList = [];
    this.rankNovels = [];
    this.nextUrl = '';
    this.nextNovelUrl = '';

    // date 参数，空字符串时不传
    const dateParam = this.currentDate || undefined;
    logger.debug(`[fetchRanking] 开始请求: mode=${this.currentMode}, date=${dateParam || '无'}, novelMode=${appSettings.novel_mode}`);
    try {
      if (appSettings.novel_mode) {
        const res = await pixiv.getNovelRanking(this.currentMode, dateParam);
        this.rankNovels = res.novels || [];
        this.nextNovelUrl = res.next_url || '';
      } else {
        const res = await pixiv.getRanking(this.currentMode, dateParam);
        this.rankList = res.illusts || [];
        this.nextUrl = res.next_url || '';
      }
    } catch (e) {
      logger.error(`[fetchRanking] 请求失败: ${JSON.stringify(e)}`);
      toastUtil.showToast({ message: '加载排行榜失败' });
    } finally {
      this.isLoading = false;
    }
  }

  async loadMore() {
    if (this.isLoading || !this.hasMore) return;
    this.isLoading = true;
    try {
      if (appSettings.novel_mode) {
        const res = await pixiv.getNovelRanking(this.currentMode, this.currentDate, this.nextNovelUrl);
        const newNovels = res.novels || [];
        this.rankNovels = [...this.rankNovels, ...newNovels];
        this.nextNovelUrl = res.next_url || '';
      } else {
        const res = await pixiv.getRanking(this.currentMode, this.currentDate, this.nextUrl);
        const newIllusts = res.illusts || [];
        this.rankList = [...this.rankList, ...newIllusts];
        this.nextUrl = res.next_url || '';
      }
    } catch (e) {
      logger.error(`[loadMore] 请求失败: ${JSON.stringify(e)}`);
    } finally {
      this.isLoading = false;
    }
  }

  // 编辑面板逻辑
  openEditMode() {
    const allAvailableKeys = Object.keys(FunctionConstants.ILLUST_RANK_MODES)
      .filter(key => appSettings.show_H || !key.includes('r18'));
    const currentSelectedKeys = appSettings.rank_modes.filter(key => allAvailableKeys.includes(key));
    this.editingSelected = new Set(currentSelectedKeys);
    const unselectedKeys = allAvailableKeys.filter(key => !this.editingSelected.has(key));
    this.editingModes = [...currentSelectedKeys, ...unselectedKeys];
  }

  toggleModeInEdit(key: string) {
    const newSet = new Set(this.editingSelected);
    if (newSet.has(key)) { newSet.delete(key); } else { newSet.add(key); }
    this.editingSelected = newSet;
  }

  onDropTo(fromIndex: number, toIndex: number) {
    if (fromIndex < 0 || toIndex < 0 || fromIndex === toIndex) return;
    const arr = [...this.editingModes];
    const item = arr.splice(fromIndex, 1)[0];
    arr.splice(toIndex, 0, item);
    this.editingModes = arr;
  }

  saveModes() {
    const finalModes = this.editingModes.filter(key => this.editingSelected.has(key));
    if (finalModes.length === 0) { toastUtil.showToast({ message: '至少选择一个项目' }); return; }
    const isSame = finalModes.length === appSettings.rank_modes.length && finalModes.every((value, index) => value === appSettings.rank_modes[index]);
    if (isSame) return;
    appSettings.rank_modes = [...finalModes];
    if (!appSettings.rank_modes.includes(this.currentMode)) {
      this.currentMode = appSettings.rank_modes[0];
      this.fetchRanking();
    }
    toastUtil.showToast({ message: '配置已保存' });
  }

  // 插画点击逻辑
  handleIllustClick(illust: PixivIllust) {
    const index = this.rankList.findIndex(i => i.id === illust.id);
    const params: DetailPageParams = {
      id: illust.id, swiperProvider: this, swiperIndex: index >= 0 ? index : 0,
      illust: illust.user ? illust : undefined
    };
    PixState.pageStack.pushPathByName('illust_detail', params, true);
  }

  // 小说点击逻辑
  handleNovelClick(novel: PixivNovel) {
    // TODO: 跳转小说详情
    logger.info(`[handleNovelClick] Clicked novel: ${novel.id}`);
  }

  private getFormattedDate(date: Date): string {
    const y = date.getFullYear();
    const m = (date.getMonth() + 1).toString().padStart(2, '0');
    const d = date.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

}

export const rankVM = new RankViewModel();
