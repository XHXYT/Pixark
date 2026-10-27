import { PixState } from '../entryability/AppState';
import { PixivIllust, PixivUser, SpotlightArticle, SpotlightResponse, PixivListResult, PixivNovel, SearchUserResult } from '../services/PixivTypes';
import { createLogger } from '../common/utils/Logger';
import { BusinessError } from '@kit.BasicServicesKit';
import { toastUtil } from '../common/utils/ToastUtils';
import { MockData } from '../services/MockData';
import { pixiv } from '../services/PixivService';
import { IIllustSwiperProvider, NovelDetailParams } from '../common/entity/DetailEntity';
import { appSettings } from '../common/entity/SettingsModel';
import { muteFilter } from '../services/MuteFilter';

const logger = createLogger('HomeViewModel')

@ObservedV2
class HomeViewModel implements IIllustSwiperProvider {
  @Trace spotlightList: SpotlightArticle[] = [];
  @Trace recommendedUsers: PixivUser[] = [];

  // 插画数据
  @Trace recommendedIllusts: PixivIllust[] = [];
  @Trace nextRecommendedUrl: string = '';

  // 小说数据
  @Trace recommendedNovels: PixivNovel[] = [];
  @Trace nextRecommendedNovelUrl: string = '';

  @Trace hiddenIllustId: number = -1
  @Trace isRefreshRecommend: boolean = false
  @Trace isLoadingMore: boolean = false;
  @Trace isRefreshing: boolean = false
  @Trace isInitialLoading: boolean = true;

  listScroller: Scroller = new Scroller();

  get nestedScrollOptions(): NestedScrollOptions {
    return { scrollForward: NestedScrollMode.PARENT_FIRST, scrollBackward: NestedScrollMode.SELF_FIRST };
  }

  get illustIds(): number[] {
    if (appSettings.novel_mode) return this.recommendedNovels.map(i => i.id);
    return this.recommendedIllusts.map(i => i.id);
  }

  get hasMore(): boolean {
    if (appSettings.novel_mode) return !!this.nextRecommendedNovelUrl;
    return !!this.nextRecommendedUrl;
  }

  get isLoading(): boolean { return this.isLoadingMore; }

  async loadMore(): Promise<void> { await this.loadMoreRecommended(); }

  hideCard(id: number) { this.hiddenIllustId = id; }

  restoreIllustVisibility() { this.hiddenIllustId = -1; }

  /** 加载首页数据，返回是否成功（失败供冷启动自动重试判断） */
  async loadHomeData(): Promise<boolean> {
    if (this.isRefreshing) return true;
    this.isRefreshing = true
    try {
      if (!pixiv.isLogin() && !PixState.isTest) return true;

      // 快速双切模式时，在途响应对应的是旧模式：丢弃并按新模式重载，防止数据串台/空列表
      for (let attempt = 0; attempt < 3; attempt++) {
        const modeAtStart = appSettings.novel_mode;
        // 构建并发任务：亮点 + 推荐作者 + (插画推荐 或者 小说推荐)
        const tasks: [Promise<SpotlightResponse>, Promise<SearchUserResult>, Promise<PixivListResult>] = [
          pixiv.getSpotlight(),
          pixiv.getUserRecommended(), // 独立接口获取推荐作者
          modeAtStart ? pixiv.getNovelRecommended() : pixiv.getRecommended(true)
        ];

        const results = await Promise.all(tasks);
        // 请求期间模式被再次切换：丢弃过期响应，按新模式重试
        if (appSettings.novel_mode !== modeAtStart && attempt < 2) {
          continue;
        }

        // 处理亮点
        this.spotlightList = results[0].spotlight_articles || [];
        // 处理推荐作者
        const userData = results[1];
        this.recommendedUsers = userData.user_previews?.map(up => up.user).filter(Boolean) || [];

        // 处理推荐插画 / 小说（按发起请求时的模式归位，避免跨桶错位）
        const recData = results[2];
        if (modeAtStart) {
          this.recommendedNovels = muteFilter.filterNovels(recData.novels || []);
          this.nextRecommendedNovelUrl = recData.next_url || '';
        } else {
          this.recommendedIllusts = muteFilter.filterIllusts(recData.illusts || []);
          this.nextRecommendedUrl = recData.next_url || '';
        }
        return true;
      }
      return true;
    } catch (e) {
      const err = e as BusinessError;
      logger.error(`!!! 加载首页数据失败: code[${err.code}], msg[${err.message}]`);
      return false;
    } finally {
      this.isRefreshing = false
      // 注意：不在这里结束骨架屏。首次加载失败时（冷启动 token/链路未就绪）
      // 由外层重试链（EntryAbility.loadHomeWithRetry / resetAndLoad）在最终结果出来后
      // 调用 endInitialLoading()，避免"骨架屏→空列表→数据迟到再刷一下"的跳变
    }
  }

  /** 结束首页骨架屏（加载 settles 或重试耗尽后调用） */
  endInitialLoading(): void {
    this.isInitialLoading = false;
  }

  public resetAndLoad() {
    this.recommendedIllusts = [];
    this.recommendedNovels = []; //
    this.recommendedUsers = [];
    this.spotlightList = [];
    this.nextRecommendedUrl = '';
    this.nextRecommendedNovelUrl = ''; //
    this.isInitialLoading = true;
    this.loadHomeData().then(() => {
      this.endInitialLoading();
    });
  }

  async refreshRecommended() {
    if (this.isRefreshRecommend) return;
    try {
      this.isRefreshRecommend = true
      let data: PixivListResult;
      if (appSettings.novel_mode) {
        data = await pixiv.getNovelRecommended();
        this.recommendedNovels = muteFilter.filterNovels(data.novels || []);
        this.nextRecommendedNovelUrl = data.next_url || '';
      } else {
        data = await pixiv.getRecommended(true);
        this.recommendedIllusts = muteFilter.filterIllusts(data.illusts || []);
        this.nextRecommendedUrl = data.next_url || '';
      }
      toastUtil.showToast({ message: '刷新成功' });
    } catch (e) {
      toastUtil.showToast({ message: $r('app.string.loading_failed') });
    } finally {
      this.isRefreshRecommend = false
    }
  }

  async loadMoreRecommended() {
    if (this.isLoadingMore) return;
    if (!this.hasMore) {
      toastUtil.showToast({ message: $r('app.string.recommend_not_tips') });
      return;
    }
    try {
      this.isLoadingMore = true;
      toastUtil.showToast({ message: $r('app.string.loading_more'), duration: 3000 })

      if (appSettings.novel_mode) {
        const data = await pixiv.getNovelRecommended(this.nextRecommendedNovelUrl);
        const newNovels = data.novels || [];
        this.nextRecommendedNovelUrl = data.next_url || '';
        this.mergeAndLimitRecommendedNovels(newNovels);
      } else {
        const data = await pixiv.getRecommended(undefined, this.nextRecommendedUrl);
        const newIllusts = data.illusts || [];
        this.nextRecommendedUrl = data.next_url || '';
        this.mergeAndLimitRecommended(newIllusts);
      }
    } catch (e) {
      toastUtil.showToast({ message: $r('app.string.loading_failed') });
    } finally {
      this.isLoadingMore = false;
    }
  }

  // 小说合并去重（过滤屏蔽项）
  private mergeAndLimitRecommendedNovels(newNovels: PixivNovel[]) {
    const filtered = muteFilter.filterNovels(newNovels);
    if (filtered.length === 0) return;
    const uniqueMap = new Map<number, PixivNovel>();
    this.recommendedNovels.forEach(n => uniqueMap.set(n.id, n));
    filtered.forEach(n => { if (!uniqueMap.has(n.id)) uniqueMap.set(n.id, n); });
    this.recommendedNovels = Array.from(uniqueMap.values());
  }

  // 插画合并去重（过滤屏蔽项）
  private mergeAndLimitRecommended(newIllusts: PixivIllust[]) {
    const filtered = muteFilter.filterIllusts(newIllusts);
    if (filtered.length === 0) return;
    const uniqueMap = new Map<number, PixivIllust>();
    this.recommendedIllusts.forEach(i => uniqueMap.set(i.id, i));
    filtered.forEach(i => { if (!uniqueMap.has(i.id)) uniqueMap.set(i.id, i); });
    this.recommendedIllusts = Array.from(uniqueMap.values());
  }

}

export const homeViewModel = new HomeViewModel();
