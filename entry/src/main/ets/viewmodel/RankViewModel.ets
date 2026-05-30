import { pixiv } from '../services/PixivService';
import { PixivIllust } from '../services/PixivTypes';
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
  // 当前展示的插画列表
  @Trace rankList: PixivIllust[] = [];
  // 当前选中的 Tab mode
  @Trace currentMode: string = 'day';
  // 当前选中的日期 (YYYY-MM-DD)
  @Trace currentDate: string = '';
  // 是否正在加载
  @Trace isLoading: boolean = false;
  // 下一页 URL
  private nextUrl: string = '';

  // 编辑面板状态
  // 正在编辑的有序数组（包含已选和未选，用于 Grid 渲染和拖拽排序）
  @Trace editingModes: string[] = [];
  // 正在编辑的选中状态集合（只记录谁被选中了）
  @Trace editingSelected: Set<string> = new Set();

  // 获取当前所有插画的 ID 数组
  get illustIds(): number[] {
    return this.rankList.map(item => item.id);
  }

  // 是否还有更多数据
  get hasMore(): boolean {
    return !!this.nextUrl;
  }

  // 获取当前激活的 Tab 列表
  get activeTabs(): RankTab[] {
    return appSettings.rank_modes.map(key => {
      const tab = new RankTab();
      tab.key = key;
      tab.label = FunctionConstants.RANK_MODE_OPTIONS[key] || key;
      return tab;
    });
  }

  // 是否显示空状态（未配置任何项目）
  get isEmptyConfig(): boolean {
    return appSettings.rank_modes.length === 0;
  }

  /** 切换当前 Tab */
  changeMode(mode: string) {
    if (this.currentMode === mode) return;
    this.currentMode = mode;
    this.fetchRanking();
  }

  /** 切换日期 */
  changeDate(date: Date) {
    this.currentDate = this.getFormattedDate(date);
    this.fetchRanking();
  }

  /** 加载排行榜数据 */
  async fetchRanking() {
    if (this.isLoading) return;
    this.isLoading = true;
    this.rankList = [];
    this.nextUrl = '';
    logger.debug(`[fetchRanking] 开始请求: mode=${this.currentMode}, date=${this.currentDate}`);
    try {
      const res = await pixiv.getRanking(this.currentMode, this.currentDate || undefined);
      logger.debug(`[fetchRanking] 请求成功: 获取到 ${res.illusts?.length ?? 0} 条数据, nextUrl=${res.next_url || '无'}`);
      this.rankList = res.illusts || [];
      this.nextUrl = res.next_url || '';
    } catch (e) {
      logger.error(`[fetchRanking] 请求失败: ${JSON.stringify(e)}`);
      toastUtil.showToast({ message: '加载排行榜失败' });
    } finally {
      this.isLoading = false;
    }
  }


  /** 加载更多 */
  async loadMore() {
    if (this.isLoading || !this.nextUrl) return;
    this.isLoading = true;
    try {
      const res = await pixiv.getRanking(this.currentMode, this.currentDate, this.nextUrl);
      logger.debug(`[loadMore] 请求成功: 获取到 ${res.illusts?.length ?? 0} 条数据, nextUrl=${res.next_url || '无'}`);
      const newIllusts = res.illusts || [];
      this.rankList = [...this.rankList, ...newIllusts];
      this.nextUrl = res.next_url || '';
    } catch (e) {
      logger.error(`[loadMore] 请求失败: ${JSON.stringify(e)}`);
    } finally {
      this.isLoading = false;
    }
  }

  // 编辑面板逻辑
  /** 打开编辑面板，初始化：已选的排在前面，未选的按默认顺序追加在后面 */
  openEditMode() {
    // 获取所有可选 key
    const allAvailableKeys = Object.keys(FunctionConstants.RANK_MODE_OPTIONS)
      .filter(key => appSettings.show_H || !key.includes('r18'));
    const currentSelectedKeys = appSettings.rank_modes.filter(key => allAvailableKeys.includes(key));

    this.editingSelected = new Set(currentSelectedKeys);
    // 未选的 key = 所有可用的 - 已选的
    const unselectedKeys = allAvailableKeys.filter(key => !this.editingSelected.has(key));
    // 拼接：已选在前面，未选在后面
    this.editingModes = [...currentSelectedKeys, ...unselectedKeys];
  }

  /** 切换勾选状态（不影响顺序） */
  toggleModeInEdit(key: string) {
    const newSet = new Set(this.editingSelected);
    if (newSet.has(key)) {
      newSet.delete(key);
    } else {
      newSet.add(key);
    }
    this.editingSelected = newSet;
    logger.debug(`[toggleModeInEdit] 选中项: [${Array.from(this.editingSelected).join(', ')}]`);
  }

  /** 拖拽排序 */
  onDropTo(fromIndex: number, toIndex: number) {
    logger.debug(`[onDropTo] 触发: from=${fromIndex}, to=${toIndex}`);
    if (fromIndex < 0 || toIndex < 0 || fromIndex === toIndex) return;

    const arr = [...this.editingModes];
    logger.debug(`[onDropTo] 变动前: [${arr.join(', ')}]`);

    const item = arr.splice(fromIndex, 1)[0];
    arr.splice(toIndex, 0, item);

    logger.debug(`[onDropTo] 变动后: [${arr.join(', ')}]`);
    this.editingModes = arr;
  }

  /** 保存编辑结果 */
  saveModes() {
    const finalModes = this.editingModes.filter(key => this.editingSelected.has(key));
    if (finalModes.length === 0) {
      toastUtil.showToast({ message: '至少选择一个项目' });
      return;
    }

    // 校验：比较新旧配置，如果没有实质变化就不保存不提示
    const isSame = finalModes.length === appSettings.rank_modes.length &&
      finalModes.every((value, index) => value === appSettings.rank_modes[index]);
    if (isSame) {
      logger.debug(`[saveModes] 配置无实质变化，跳过保存`);
      return;
    }
    appSettings.rank_modes = [...finalModes];
    // 如果当前正在查看的 mode 被删除了，自动切回第一个
    if (!appSettings.rank_modes.includes(this.currentMode)) {
      this.currentMode = appSettings.rank_modes[0];
      this.fetchRanking();
    }
    toastUtil.showToast({ message: '配置已保存' });
  }

  /** 统一的点击处理逻辑 */
  handleIllustClick(illust: PixivIllust) {
    const index = this.rankList.findIndex(i => i.id === illust.id);
    const params: DetailPageParams = {
      id: illust.id,
      swiperProvider: this,
      swiperIndex: index >= 0 ? index : 0,
      // 数据兜底, 如果 illust 对象没有 user 信息，说明是残缺数据，强制置空，让详情页自己拉
      illust: illust.user ? illust : undefined
    };

    // 执行跳转
    PixState.pageStack.pushPathByName('illust_detail', params, true);
  }

  /** 格式化日期 */
  private getFormattedDate(date: Date): string {
    const y = date.getFullYear();
    const m = (date.getMonth() + 1).toString().padStart(2, '0');
    const d = date.getDate().toString().padStart(2, '0');
    return `${y}-${m}-${d}`;
  }

}

export const rankVM = new RankViewModel();
