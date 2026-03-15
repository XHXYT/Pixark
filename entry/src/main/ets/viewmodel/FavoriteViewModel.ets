import { DetailPageParams } from "../entity/IllustDetailEntity";
import { UserDetailParams } from "../entity/UserDetailEntity";
import { PixState } from "../entryability/AppState";
import { PixivIllust, UserPreview } from "../services/PixivTypes";
import { createLogger } from "../utils/Logger";

const logger = createLogger('FavoriteViewModel');

@ObservedV2
class FavoriteViewModel {

  // --- 顶部主 Tab 状态 ---
  // 0: 动态, 1: 收藏, 2: 关注
  @Trace mainTabIndex: number = 0;

  // --- 筛选器状态 ---
  // 0: 全部 (公开+私密), 1: 公开, 2: 隐藏
  @Trace filterIndex: number = 0;

  // --- 数据状态 ---
  // 动态数据
  @Trace trendList: PixivIllust[] = [];
  @Trace isTrendLoading: boolean = false;
  private nextTrendUrlPublic: string = '';
  private nextTrendUrlPrivate: string = '';

  // 收藏数据
  @Trace collectionList: PixivIllust[] = [];
  @Trace isCollectionLoading: boolean = false;
  private nextCollectionUrlPublic: string = '';
  private nextCollectionUrlPrivate: string = '';

  // 关注数据
  @Trace followList: UserPreview[] = [];
  @Trace isFollowLoading: boolean = false;
  private nextFollowUrlPublic: string = '';
  private nextFollowUrlPrivate: string = '';

  // 记录是否已加载过
  private hasLoadedTrend: boolean = false;
  private hasLoadedCollection: boolean = false;
  private hasLoadedFollow: boolean = false;

  // 记录上一次筛选器的索引，用于判断是否需要刷新
  private lastFilterIndex: number = -1;

  // --- 生命周期 ---
  async onReady() {
    logger.debug('[onReady] Favorite page ready.');
    this.loadCurrentTabData();
  }

  // --- 核心加载逻辑 ---
  // 加载当前 Tab 的数据
  async loadCurrentTabData() {
    if (this.mainTabIndex === 0) {
      await this.loadTrendData();
    } else if (this.mainTabIndex === 1) {
      await this.loadCollectionData();
    } else if (this.mainTabIndex === 2) {
      await this.loadFollowData();
    }
  }

  // 加载动态 (支持全部/公开/隐藏)
  async loadTrendData(isLoadMore: boolean = false) {
    // 检查防抖：如果是加载更多，或者是初次加载，或者是筛选器变了
    if (!isLoadMore && this.hasLoadedTrend && this.lastFilterIndex === this.filterIndex) return;
    this.isTrendLoading = true;
    try {
      let newData: PixivIllust[] = [];
      // 全部 (请求公开 + 私密)
      if (this.filterIndex === 0) {
        // 并行请求公开和私密
        const results = await Promise.all([
          PixState.pixiv.getFollowingIllusts('public', isLoadMore ? this.nextTrendUrlPublic : undefined),
          PixState.pixiv.getFollowingIllusts('private', isLoadMore ? this.nextTrendUrlPrivate : undefined)
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
        const res = await PixState.pixiv.getFollowingIllusts('public', isLoadMore ? this.nextTrendUrlPublic : undefined);
        this.nextTrendUrlPublic = res.next_url || '';
        newData = res.illusts || [];
      }
      // 仅私密
      else if (this.filterIndex === 2) {
        const res = await PixState.pixiv.getFollowingIllusts('private', isLoadMore ? this.nextTrendUrlPrivate : undefined);
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
    } finally {
      this.isTrendLoading = false;
    }
  }

  // 加载收藏 (支持全部/公开/隐藏)
  async loadCollectionData(isLoadMore: boolean = false) {
    if (!isLoadMore && this.hasLoadedCollection && this.lastFilterIndex === this.filterIndex) return;
    this.isCollectionLoading = true;
    try {
      const userId = PixState.currentUser?.id || 0;
      let newData: PixivIllust[] = [];
      if (this.filterIndex === 0) {
        const results = await Promise.all([
          PixState.pixiv.getUserBookmarks(userId, 'public', undefined, undefined, isLoadMore ? this.nextCollectionUrlPublic : undefined),
          PixState.pixiv.getUserBookmarks(userId, 'private', undefined, undefined, isLoadMore ? this.nextCollectionUrlPrivate : undefined)
        ]);
        const publicRes = results[0]
        const privateRes = results[1]
        this.nextCollectionUrlPublic = publicRes.next_url || '';
        this.nextCollectionUrlPrivate = privateRes.next_url || '';
        newData = [...(publicRes.illusts || []), ...(privateRes.illusts || [])];
      } else if (this.filterIndex === 1) {
        const res = await PixState.pixiv.getUserBookmarks(userId, 'public', undefined, undefined, isLoadMore ? this.nextCollectionUrlPublic : undefined);
        this.nextCollectionUrlPublic = res.next_url || '';
        newData = res.illusts || [];
      } else if (this.filterIndex === 2) {
        const res = await PixState.pixiv.getUserBookmarks(userId, 'private', undefined, undefined, isLoadMore ? this.nextCollectionUrlPrivate : undefined);
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
    } finally {
      this.isCollectionLoading = false;
    }
  }

  // 加载关注 (支持全部/公开/隐藏)
  async loadFollowData(isLoadMore: boolean = false) {
    if (!isLoadMore && this.hasLoadedFollow && this.lastFilterIndex === this.filterIndex) return;
    this.isFollowLoading = true;
    try {
      const userId = PixState.currentUser?.id || 0;
      let newData: UserPreview[] = [];

      if (this.filterIndex === 0) {
        const results = await Promise.all([
          PixState.pixiv.getUserFollowing(userId, 'public', isLoadMore ? this.nextFollowUrlPublic : undefined),
          PixState.pixiv.getUserFollowing(userId, 'private', isLoadMore ? this.nextFollowUrlPrivate : undefined)
        ]);
        const publicRes = results[0]
        const privateRes = results[1]
        this.nextFollowUrlPublic = publicRes.next_url || '';
        this.nextFollowUrlPrivate = privateRes.next_url || '';
        newData = [...(publicRes.user_previews || []), ...(privateRes.user_previews || [])];
      } else if (this.filterIndex === 1) {
        const res = await PixState.pixiv.getUserFollowing(userId, 'public', isLoadMore ? this.nextFollowUrlPublic : undefined);
        this.nextFollowUrlPublic = res.next_url || '';
        newData = res.user_previews || [];
      } else if (this.filterIndex === 2) {
        const res = await PixState.pixiv.getUserFollowing(userId, 'private', isLoadMore ? this.nextFollowUrlPrivate : undefined);
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
    } finally {
      this.isFollowLoading = false;
    }
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
    // 切换筛选器时，重置数据并重新加载
    if (this.mainTabIndex === 0) {
      this.trendList = [];
      this.hasLoadedTrend = false;
      this.loadTrendData();
    } else if (this.mainTabIndex === 1) {
      this.collectionList = [];
      this.hasLoadedCollection = false;
      this.loadCollectionData();
    } else if (this.mainTabIndex === 2) {
      this.followList = [];
      this.hasLoadedFollow = false;
      this.loadFollowData();
    }
  }

  handleIllustClick(illust: PixivIllust) {
    const params: DetailPageParams = {
      id: illust.id,
      illust: illust
    };
    PixState.pageStack.pushPathByName('illust_detail', params, true);
  }

  // --- 加载更多 ---
  async loadMore() {
    if (this.mainTabIndex === 0) {
      // 判断是否有下一页（任意一方有下一页就继续加载）
      if (this.filterIndex === 0) {
        if (this.nextTrendUrlPublic || this.nextTrendUrlPrivate) {
          await this.loadTrendData(true);
        }
      } else if (this.filterIndex === 1 && this.nextTrendUrlPublic) {
        await this.loadTrendData(true);
      } else if (this.filterIndex === 2 && this.nextTrendUrlPrivate) {
        await this.loadTrendData(true);
      }
    } else if (this.mainTabIndex === 1) {
      if (this.filterIndex === 0) {
        if (this.nextCollectionUrlPublic || this.nextCollectionUrlPrivate) {
          await this.loadCollectionData(true);
        }
      } else if (this.filterIndex === 1 && this.nextCollectionUrlPublic) {
        await this.loadCollectionData(true);
      } else if (this.filterIndex === 2 && this.nextCollectionUrlPrivate) {
        await this.loadCollectionData(true);
      }
    } else if (this.mainTabIndex === 2) {
      if (this.filterIndex === 0) {
        if (this.nextFollowUrlPublic || this.nextFollowUrlPrivate) {
          await this.loadFollowData(true);
        }
      } else if (this.filterIndex === 1 && this.nextFollowUrlPublic) {
        await this.loadFollowData(true);
      } else if (this.filterIndex === 2 && this.nextFollowUrlPrivate) {
        await this.loadFollowData(true);
      }
    }
  }

  get currentIllustList(): PixivIllust[] {
    if (this.mainTabIndex === 0) return this.trendList;
    if (this.mainTabIndex === 1) return this.collectionList;
    return [];
  }

  get isFilterEnabled(): boolean {
    return true;
  }

}

export const favVM = new FavoriteViewModel();
