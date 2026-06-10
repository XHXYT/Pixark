import { DetailPageParams, IIllustSwiperProvider, NovelDetailParams } from "../common/entity/DetailEntity";
import { PixState } from "../entryability/AppState";
import { PixivIllust, PixivNovel, UserPreview } from "../services/PixivTypes";
import { createLogger } from "../common/utils/Logger";
import { pixiv } from "../services/PixivService";
import { appSettings } from "../common/entity/SettingsModel";

const logger = createLogger('FavoriteViewModel');


@ObservedV2
class FavoriteViewModel implements IIllustSwiperProvider {

  // --- 顶部主 Tab 状态 ---
  // 0: 动态, 1: 收藏, 2: 关注
  @Trace mainTabIndex: number = 0;

  // --- 筛选器状态 ---
  // 0: 全部 (公开+私密), 1: 公开, 2: 隐藏
  @Trace filterIndex: number = 0;

  // --- 数据状态 ---
  @Trace isLoadingMore: boolean = false;
  @Trace isRefreshing: boolean = false
  @Trace isInitialLoading: boolean = true;

  // 插画数据
  @Trace trendList: PixivIllust[] = [];
  private nextTrendUrlPublic: string = '';
  private nextTrendUrlPrivate: string = '';
  @Trace collectionList: PixivIllust[] = [];
  private nextCollectionUrlPublic: string = '';
  private nextCollectionUrlPrivate: string = '';

  // 小说数据
  @Trace trendNovels: PixivNovel[] = [];
  private nextTrendNovelUrlPublic: string = '';
  private nextTrendNovelUrlPrivate: string = '';
  @Trace collectionNovels: PixivNovel[] = [];
  private nextCollectionNovelUrlPublic: string = '';
  private nextCollectionNovelUrlPrivate: string = '';

  // 关注数据
  @Trace followList: UserPreview[] = [];
  private nextFollowUrlPublic: string = '';
  private nextFollowUrlPrivate: string = '';

  // 加载记录
  private hasLoadedTrend: boolean = false;
  private hasLoadedCollection: boolean = false;
  private hasLoadedFollow: boolean = false;
  // 小说加载记录
  private hasLoadedTrendNovels: boolean = false;
  private hasLoadedCollectionNovels: boolean = false;

  private lastFilterIndex: number = -1;

  // --- 生命周期 ---
  async onReady() {
    logger.debug('[onReady] Favorite page ready.');
    this.loadCurrentTabData();
  }

  // --- 核心加载逻辑 ---
  // 加载当前 Tab 的数据
  async loadCurrentTabData() {
    if (this.isRefreshing) return; // 防抖：如果正在刷新，不重复触发
    this.isRefreshing = true;
    logger.debug('>>> 开始加载喜欢数据...');
    try {
      if (this.mainTabIndex === 0) {
        appSettings.novel_mode ? await this.loadTrendNovelData() : await this.loadTrendData();
      } else if (this.mainTabIndex === 1) {
        appSettings.novel_mode ? await this.loadCollectionNovelData() : await this.loadCollectionData();
      } else if (this.mainTabIndex === 2) {
        await this.loadFollowData(); // 关注页不分小说/插画
      }
    } catch (e) {
      logger.error(`[loadCurrentTabData] Failed: ${e.message}`);
    } finally {
      // 确保无论成功失败，都要关闭刷新状态
      this.isRefreshing = false;
      // 关闭首次加载动画
      this.isInitialLoading = false;
    }
  }

  // 强制重置并重新加载 (用于切换账号)
  public resetAndLoad() {
    this.trendList = []; this.collectionList = []; this.followList = [];
    this.trendNovels = []; this.collectionNovels = []; // 重置小说

    this.nextTrendUrlPublic = ''; this.nextTrendUrlPrivate = '';
    this.nextCollectionUrlPublic = ''; this.nextCollectionUrlPrivate = '';
    this.nextTrendNovelUrlPublic = ''; this.nextTrendNovelUrlPrivate = '';
    this.nextCollectionNovelUrlPublic = ''; this.nextCollectionNovelUrlPrivate = '';
    this.nextFollowUrlPublic = ''; this.nextFollowUrlPrivate = '';

    this.hasLoadedTrend = false; this.hasLoadedCollection = false; this.hasLoadedFollow = false;
    this.hasLoadedTrendNovels = false; this.hasLoadedCollectionNovels = false;
    this.lastFilterIndex = -1;

    this.isInitialLoading = true;
    this.loadCurrentTabData();
  }

  // 动态获取当前展示的插画 ID 列表
  get illustIds(): number[] {
    return this.currentIllustList.map(i => i.id);
  }

  // 动态判断当前列表是否还有更多数据
  get hasMore(): boolean {
    if (appSettings.novel_mode) {
      if (this.mainTabIndex === 0) {
        if (this.filterIndex === 0) return !!(this.nextTrendNovelUrlPublic || this.nextTrendNovelUrlPrivate);
        if (this.filterIndex === 1) return !!this.nextTrendNovelUrlPublic;
        if (this.filterIndex === 2) return !!this.nextTrendNovelUrlPrivate;
      } else if (this.mainTabIndex === 1) {
        if (this.filterIndex === 0) return !!(this.nextCollectionNovelUrlPublic || this.nextCollectionNovelUrlPrivate);
        if (this.filterIndex === 1) return !!this.nextCollectionNovelUrlPublic;
        if (this.filterIndex === 2) return !!this.nextCollectionNovelUrlPrivate;
      }
    } else {
      if (this.mainTabIndex === 0) {
        if (this.filterIndex === 0) return !!(this.nextTrendUrlPublic || this.nextTrendUrlPrivate);
        if (this.filterIndex === 1) return !!this.nextTrendUrlPublic;
        if (this.filterIndex === 2) return !!this.nextTrendUrlPrivate;
      } else if (this.mainTabIndex === 1) {
        if (this.filterIndex === 0) return !!(this.nextCollectionUrlPublic || this.nextCollectionUrlPrivate);
        if (this.filterIndex === 1) return !!this.nextCollectionUrlPublic;
        if (this.filterIndex === 2) return !!this.nextCollectionUrlPrivate;
      }
    }
    return false;
  }

  get isLoading(): boolean {
    return this.isLoadingMore;
  }

  // 加载动态 (支持全部/公开/隐藏)
  async loadTrendData(isLoadMore: boolean = false) {
    // 检查防抖：如果是加载更多，或者是初次加载，或者是筛选器变了
    if (!isLoadMore && this.hasLoadedTrend && this.lastFilterIndex === this.filterIndex) return;
    try {
      let newData: PixivIllust[] = [];
      // 全部 (请求公开 + 私密)
      if (this.filterIndex === 0) {
        // 并行请求公开和私密
        const results = await Promise.all([
          pixiv.getFollowingIllusts('public', isLoadMore ? this.nextTrendUrlPublic : undefined),
          pixiv.getFollowingIllusts('private', isLoadMore ? this.nextTrendUrlPrivate : undefined)
        ]);
        const publicRes = results[0]
        const privateRes = results[1]
        // 更新分页 URL
        this.nextTrendUrlPublic = publicRes.next_url || '';
        this.nextTrendUrlPrivate = privateRes.next_url || '';

        // 合并数据 (先公开后私密)
        newData = [...(publicRes.illusts || []), ...(privateRes.illusts || [])];
      }
      // 仅公开
      else if (this.filterIndex === 1) {
        const res = await pixiv.getFollowingIllusts('public', isLoadMore ? this.nextTrendUrlPublic : undefined);
        this.nextTrendUrlPublic = res.next_url || '';
        newData = res.illusts || [];
      }
      // 仅私密
      else if (this.filterIndex === 2) {
        const res = await pixiv.getFollowingIllusts('private', isLoadMore ? this.nextTrendUrlPrivate : undefined);
        this.nextTrendUrlPrivate = res.next_url || '';
        newData = res.illusts || [];
      }
      // 处理数据结果
      if (isLoadMore) {
        this.trendList.push(...newData);
      } else {
        this.trendList = newData;
      }
      this.hasLoadedTrend = true;
      this.lastFilterIndex = this.filterIndex;
      logger.debug(`[loadTrendData] Filter: ${this.filterIndex}, Loaded ${newData.length} items.`);
    } catch (e) {
      logger.error(`[loadTrendData] Failed: ${e.message}`);
    }
  }

  // 加载收藏 (支持全部/公开/隐藏)
  async loadCollectionData(isLoadMore: boolean = false) {
    if (!isLoadMore && this.hasLoadedCollection && this.lastFilterIndex === this.filterIndex) return;
    try {
      const userId = PixState.currentUser?.id || 0;
      let newData: PixivIllust[] = [];
      if (this.filterIndex === 0) {
        const results = await Promise.all([
          pixiv.getUserBookmarks(userId, 'public', undefined, undefined, isLoadMore ? this.nextCollectionUrlPublic : undefined),
          pixiv.getUserBookmarks(userId, 'private', undefined, undefined, isLoadMore ? this.nextCollectionUrlPrivate : undefined)
        ]);
        const publicRes = results[0]
        const privateRes = results[1]
        this.nextCollectionUrlPublic = publicRes.next_url || '';
        this.nextCollectionUrlPrivate = privateRes.next_url || '';
        newData = [...(publicRes.illusts || []), ...(privateRes.illusts || [])];
      } else if (this.filterIndex === 1) {
        const res = await pixiv.getUserBookmarks(userId, 'public', undefined, undefined, isLoadMore ? this.nextCollectionUrlPublic : undefined);
        this.nextCollectionUrlPublic = res.next_url || '';
        newData = res.illusts || [];
      } else if (this.filterIndex === 2) {
        const res = await pixiv.getUserBookmarks(userId, 'private', undefined, undefined, isLoadMore ? this.nextCollectionUrlPrivate : undefined);
        this.nextCollectionUrlPrivate = res.next_url || '';
        newData = res.illusts || [];
      }

      if (isLoadMore) {
        this.collectionList.push(...newData);
      } else {
        this.collectionList = newData;
      }

      this.hasLoadedCollection = true;
      this.lastFilterIndex = this.filterIndex;
      logger.debug(`[loadCollectionData] Filter: ${this.filterIndex}, Loaded ${newData.length} items.`);
    } catch (e) {
      logger.error(`[loadCollectionData] Failed: ${e.message}`);
    }
  }

  // 加载关注 (支持全部/公开/隐藏)
  async loadFollowData(isLoadMore: boolean = false) {
    if (!isLoadMore && this.hasLoadedFollow && this.lastFilterIndex === this.filterIndex) return;
    try {
      const userId = PixState.currentUser?.id || 0;
      let newData: UserPreview[] = [];

      if (this.filterIndex === 0) {
        const results = await Promise.all([
          pixiv.getUserFollowing(userId, 'public', isLoadMore ? this.nextFollowUrlPublic : undefined),
          pixiv.getUserFollowing(userId, 'private', isLoadMore ? this.nextFollowUrlPrivate : undefined)
        ]);
        const publicRes = results[0]
        const privateRes = results[1]
        this.nextFollowUrlPublic = publicRes.next_url || '';
        this.nextFollowUrlPrivate = privateRes.next_url || '';
        newData = [...(publicRes.user_previews || []), ...(privateRes.user_previews || [])];
      } else if (this.filterIndex === 1) {
        const res = await pixiv.getUserFollowing(userId, 'public', isLoadMore ? this.nextFollowUrlPublic : undefined);
        this.nextFollowUrlPublic = res.next_url || '';
        newData = res.user_previews || [];
      } else if (this.filterIndex === 2) {
        const res = await pixiv.getUserFollowing(userId, 'private', isLoadMore ? this.nextFollowUrlPrivate : undefined);
        this.nextFollowUrlPrivate = res.next_url || '';
        newData = res.user_previews || [];
      }

      if (isLoadMore) {
        this.followList.push(...newData);
      } else {
        this.followList = newData;
      }

      this.hasLoadedFollow = true;
      this.lastFilterIndex = this.filterIndex;
      logger.debug(`[loadFollowData] Filter: ${this.filterIndex}, Loaded ${newData.length} users.`);
    } catch (e) {
      logger.error(`[loadFollowData] Failed: ${e.message}`);
    }
  }

  // 小说请求逻辑
  async loadTrendNovelData(isLoadMore: boolean = false) {
    if (!isLoadMore && this.hasLoadedTrendNovels && this.lastFilterIndex === this.filterIndex) return;
    try {
      let newData: PixivNovel[] = [];
      if (this.filterIndex === 0) {
        const results = await Promise.all([
          pixiv.getNovelFollow('public', isLoadMore ? this.nextTrendNovelUrlPublic : undefined),
          pixiv.getNovelFollow('private', isLoadMore ? this.nextTrendNovelUrlPrivate : undefined)
        ]);
        this.nextTrendNovelUrlPublic = results[0].next_url || '';
        this.nextTrendNovelUrlPrivate = results[1].next_url || '';
        newData = [...(results[0].novels || []), ...(results[1].novels || [])];
      } else if (this.filterIndex === 1) {
        const res = await pixiv.getNovelFollow('public', isLoadMore ? this.nextTrendNovelUrlPublic : undefined);
        this.nextTrendNovelUrlPublic = res.next_url || '';
        newData = res.novels || [];
      } else if (this.filterIndex === 2) {
        const res = await pixiv.getNovelFollow('private', isLoadMore ? this.nextTrendNovelUrlPrivate : undefined);
        this.nextTrendNovelUrlPrivate = res.next_url || '';
        newData = res.novels || [];
      }
      this.trendNovels.push(...newData);
      this.hasLoadedTrendNovels = true;
      this.lastFilterIndex = this.filterIndex;
    } catch (e) { logger.error(`[loadTrendNovelData] Failed: ${e.message}`); }
  }

  async loadCollectionNovelData(isLoadMore: boolean = false) {
    if (!isLoadMore && this.hasLoadedCollectionNovels && this.lastFilterIndex === this.filterIndex) return;
    try {
      const userId = PixState.currentUser?.id || 0;
      let newData: PixivNovel[] = [];
      if (this.filterIndex === 0) {
        const results = await Promise.all([
          pixiv.getUserBookmarkNovel(userId, 'public', isLoadMore ? this.nextCollectionNovelUrlPublic : undefined),
          pixiv.getUserBookmarkNovel(userId, 'private', isLoadMore ? this.nextCollectionNovelUrlPrivate : undefined)
        ]);
        this.nextCollectionNovelUrlPublic = results[0].next_url || '';
        this.nextCollectionNovelUrlPrivate = results[1].next_url || '';
        newData = [...(results[0].novels || []), ...(results[1].novels || [])];
      } else if (this.filterIndex === 1) {
        const res = await pixiv.getUserBookmarkNovel(userId, 'public', isLoadMore ? this.nextCollectionNovelUrlPublic : undefined);
        this.nextCollectionNovelUrlPublic = res.next_url || '';
        newData = res.novels || [];
      } else if (this.filterIndex === 2) {
        const res = await pixiv.getUserBookmarkNovel(userId, 'private', isLoadMore ? this.nextCollectionNovelUrlPrivate : undefined);
        this.nextCollectionNovelUrlPrivate = res.next_url || '';
        newData = res.novels || [];
      }
      this.collectionNovels = isLoadMore ? [...this.collectionNovels, ...newData] : newData;
      this.hasLoadedCollectionNovels = true;
      this.lastFilterIndex = this.filterIndex;
    } catch (e) { logger.error(`[loadCollectionNovelData] Failed: ${e.message}`); }
  }

  // --- 交互逻辑 ---
  handleMainTabChange(index: number) {
    if (this.mainTabIndex === index) return;
    this.mainTabIndex = index;
    this.loadCurrentTabData();
  }

  handleFilterChange(index: number) {
    if (this.filterIndex === index) return;
    this.filterIndex = index;

    if (appSettings.novel_mode) {
      if (this.mainTabIndex === 0) {
        this.trendNovels = []; this.hasLoadedTrendNovels = false; this.loadTrendNovelData();
      } else if (this.mainTabIndex === 1) {
        this.collectionNovels = []; this.hasLoadedCollectionNovels = false; this.loadCollectionNovelData();
      } else {
        this.followList = []; this.hasLoadedFollow = false; this.loadFollowData();
      }
    } else {
      if (this.mainTabIndex === 0) {
        this.trendList = []; this.hasLoadedTrend = false; this.loadTrendData();
      } else if (this.mainTabIndex === 1) {
        this.collectionList = []; this.hasLoadedCollection = false; this.loadCollectionData();
      } else {
        this.followList = []; this.hasLoadedFollow = false; this.loadFollowData();
      }
    }
  }

  // 统一的点击处理逻辑
  handleIllustClick(illust: PixivIllust) {
    // 判断是否处于真正的插画列表上下文中
    const isIllustContext = this.mainTabIndex === 0 || this.mainTabIndex === 1;
    // 计算索引：只有在插画上下文中才去查索引，否则默认 0
    const index = isIllustContext ? this.currentIllustList.findIndex(i => i.id === illust.id) : 0;

    const params: DetailPageParams = {
      id: illust.id,
      // 只有在插画上下文才传 Provider，关注页传 undefined！
      swiperProvider: isIllustContext ? this : undefined,
      swiperIndex: index >= 0 ? index : 0,
      // 数据兜底, 如果 illust 对象没有 user 信息，说明是残缺数据，强制置空，让详情页自己拉
      illust: illust.user ? illust : undefined
    };
    // 执行跳转
    PixState.pageStack.pushPathByName('illust_detail', params, true);
  }

  handleNovelClick(novel: PixivNovel) {
    const params: NovelDetailParams = {
      id: novel.id,
    };
    // 执行跳转
    PixState.pageStack.pushPathByName('novel_detail', params, true);
  }

  // --- 加载更多 ---
  async loadMore(): Promise<void> {
    if (this.isLoadingMore || !this.hasMore) return;
    this.isLoadingMore = true;
    try {
      if (appSettings.novel_mode) {
        if (this.mainTabIndex === 0) await this.loadTrendNovelData(true);
        else if (this.mainTabIndex === 1) await this.loadCollectionNovelData(true);
      } else {
        if (this.mainTabIndex === 0) await this.loadTrendData(true);
        else if (this.mainTabIndex === 1) await this.loadCollectionData(true);
      }
    } finally {
      this.isLoadingMore = false;
    }
  }

  get currentIllustList(): PixivIllust[] {
    if (this.mainTabIndex === 0) return this.trendList;
    if (this.mainTabIndex === 1) return this.collectionList;
    return [];
  }

  // 获取当前小说列表
  get currentNovels(): PixivNovel[] {
    if (this.mainTabIndex === 0) return this.trendNovels;
    if (this.mainTabIndex === 1) return this.collectionNovels;
    return [];
  }

  get isFilterEnabled(): boolean {
    return true;
  }

}

export const favVM = new FavoriteViewModel();
