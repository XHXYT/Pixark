import { UserDetailParams } from '../entity/UserDetailEntity';
import { PixState } from '../entryability/AppState';
import { PixivIllust, PixivUser, UserDetailResponse } from '../services/PixivTypes';
import { createLogger } from '../utils/Logger';
import { toastUtil } from '../utils/ToastUtils';

const logger = createLogger('UserDetailViewModel')

@ObservedV2
class UserDetailViewModel {

  // 预加载的用户数据（用于瞬间显示）
  @Trace preUserData: PixivUser | null = null;
  // 完整的用户详情
  @Trace userData: UserDetailResponse | null = null;
  @Trace isFollow: boolean = false;
  @Trace isDetailLoading: boolean = false;

  // 分段控制器索引 (0: 作品, 1: 收藏, 2: 详情)
  @Trace tabIndex: number = 0;

  // --- 作品相关 ---
  @Trace userIllusts: PixivIllust[] = [];
  @Trace isIllustLoading: boolean = false;
  private nextIllustUrl: string = '';

  // --- 收藏相关 ---
  @Trace userBookmarks: PixivIllust[] = [];
  @Trace isBookmarkLoading: boolean = false;
  private nextBookmarkUrl: string = '';

  // 记录是否已经加载过
  private hasLoadedIllusts: boolean = false;
  private hasLoadedBookmarks: boolean = false;

  // 嵌套滚动配置
  get nestedScrollOptions(): NestedScrollOptions {
    return {
      scrollForward: NestedScrollMode.PARENT_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST,
    };
  }

  async onReady(ctx: NavDestinationContext, params: UserDetailParams) {
    const userId = params.id;
    // 重置状态
    // 防止显示上一个用户的旧数据
    this.userIllusts = [];           // 清空作品列表
    this.userBookmarks = [];         // 清空收藏列表
    this.userData = null;            // 清空详情数据（避免闪现上一个用户的信息）

    this.nextIllustUrl = '';         // 重置作品分页
    this.nextBookmarkUrl = '';       // 重置收藏分页

    this.hasLoadedIllusts = false;   // 重置“已加载”标志位
    this.hasLoadedBookmarks = false; // 重置“已加载”标志位
    this.tabIndex = 0;               // 默认回到第一个 Tab (作品)
    // 页面初始化
    logger.debug(`[onReady] Start. UserId: ${userId}, HasPreUserData:${!!params.user}`);
    // 初始化预加载数据
    if (params.user) {
      this.preUserData = params.user;
      this.isFollow = params.user.is_followed;
      logger.debug(`[onReady] PreUserData applied. Name: ${params.user.name}, IsFollow: ${params.user.is_followed}`);
    }
    // 加载用户详细资料
    this.loadUserDetail(userId);
    // 预加载第一个 Tab 的数据（作品）
    if (this.tabIndex === 0) {
      this.loadUserIllusts(userId);
    }
  }

  // --- 核心数据加载 ---
  async loadUserDetail(userId: number) {
    this.isDetailLoading = true;
    logger.debug(`[loadUserDetail] Requesting userId=${userId}`);

    try {
      const data = await PixState.pixiv.getUserDetail(userId);
      this.userData = data;
      // 更新关注状态
      this.isFollow = data.user?.is_followed ?? false;
      const userName = data.user?.name || '未知用户';
      const followCount = data.profile?.total_follow_users ?? 0;
      const hasBackground = !!data.profile?.background_image_url;
      const comment = data.user?.comment || '';
      logger.debug(
        `[loadUserDetail] Success. Name: ${userName}, ` +
          `FollowCount: ${followCount}, Background:${hasBackground}, ` +
          `HasComment: ${comment.length > 0}`
      );
      // 清理预加载数据
      this.preUserData = null;
    } catch (e) {
      logger.error(`[loadUserDetail] Failed name: ${e.name}, message: ${e.message}`);
      toastUtil.showToast({ message: `加载用户信息失败, ${e.message}` });
    } finally {
      this.isDetailLoading = false;
    }
  }

  async loadUserIllusts(userId: number, url?: string) {
    const isLoadMore = !!url;
    // 防止重复请求
    if (!isLoadMore && this.hasLoadedIllusts) {
      logger.debug(`[loadUserIllusts] Skipped (already loaded). UserId: ${userId}`);
      return;
    }
    this.isIllustLoading = true;
    logger.debug(`[loadUserIllusts] ${isLoadMore ? 'LoadMore' : 'Init'}. UserId: ${userId}, NextUrl: ${url ? 'Exists' : 'None'}`);

    try {
      const data = await PixState.pixiv.getUserIllusts(userId, 'illust', url);
      const newIllusts = data.illusts || [];

      if (isLoadMore) {
        this.userIllusts.push(...newIllusts);
      } else {
        this.userIllusts = newIllusts;
      }

      this.nextIllustUrl = data.next_url || '';
      this.hasLoadedIllusts = true;
      // 作品加载成功
      logger.debug(`[loadUserIllusts] Success. NewItems: ${newIllusts.length}, Total: ${this.userIllusts.length}, HasNext: ${!!this.nextIllustUrl}`);
    } catch (e) {
      logger.error(`[loadUserIllusts] Failed: ${JSON.stringify(e)}`);
    } finally {
      this.isIllustLoading = false;
    }
  }

  async loadUserBookmarks(userId: number, url?: string) {
    const isLoadMore = !!url;
    if (!isLoadMore && this.hasLoadedBookmarks) {
      logger.debug(`[loadUserBookmarks] Skipped (already loaded). UserId: ${userId}`);
      return;
    }
    this.isBookmarkLoading = true;
    logger.debug(`[loadUserBookmarks] ${isLoadMore ? 'LoadMore' : 'Init'}. UserId: ${userId}`);

    try {
      // tag 和 maxBookmarkId 这里不需要，传 undefined
      const data = await PixState.pixiv.getUserBookmarks(userId, 'public', undefined, undefined, url);
      const newBookmarks = data.illusts || [];
      if (isLoadMore) {
        this.userBookmarks.push(...newBookmarks);
      } else {
        this.userBookmarks = newBookmarks;
      }
      this.nextBookmarkUrl = data.next_url || '';
      this.hasLoadedBookmarks = true;
      // 收藏加载成功
      logger.debug(`[loadUserBookmarks] Success. NewItems: ${newBookmarks.length}, Total: ${this.userBookmarks.length}, HasNext: ${!!this.nextBookmarkUrl}`);
    } catch (e) {
      logger.error(`[loadUserBookmarks] Failed: ${JSON.stringify(e)}`);
      toastUtil.showToast({ message: "无法加载收藏（可能未公开）" });
    } finally {
      this.isBookmarkLoading = false;
    }
  }

  // --- 交互逻辑 ---
  handleTabChange(index: number) {
    this.tabIndex = index;
    const userId = this.userData?.user.id;
    logger.debug(`[handleTabChange] Index: ${index}, UserId: ${userId}`);
    if (!userId) {
      logger.warn(`[handleTabChange] No userId found, skipping load.`);
      return;
    }
    if (index === 0) {
      this.loadUserIllusts(userId);
    } else if (index === 1) {
      this.loadUserBookmarks(userId);
    }
  }

  async followOrCancel() {
    if (!this.userData) return;
    const userId = this.userData.user.id;
    const action = this.isFollow ? 'Unfollow' : 'Follow';

    logger.debug(`[followOrCancel] Start. Action: ${action}, UserId: ${userId}`);

    try {
      if (this.isFollow) {
        await PixState.pixiv.unfollowUser(userId, 'public');
        this.isFollow = false;
        if (this.userData.user) this.userData.user.is_followed = false;
      } else {
        await PixState.pixiv.followUser(userId, 'public');
        this.isFollow = true;
        if (this.userData.user) this.userData.user.is_followed = true;
      }
      logger.debug(`[followOrCancel] Success. Action: ${action}`);
    } catch (e) {
      logger.error(`[followOrCancel] Failed: ${JSON.stringify(e)}`);
      toastUtil.showToast({ message: "操作失败" });
    }
  }

  // --- 辅助获取 ---
  get currentIllustList(): PixivIllust[] {
    if (this.tabIndex === 0) {
      return this.userIllusts;
    } else if (this.tabIndex === 1) {
      return this.userBookmarks;
    }
    return [];
  }

  async loadMoreCurrentData() {
    const userId = this.userData?.user.id;
    if (!userId) {
      logger.warn(`[loadMoreCurrentData] No userId found.`);
      return;
    }

    if (this.tabIndex === 0 && this.nextIllustUrl) {
      logger.debug(`[loadMoreCurrentData] Triggering Illust LoadMore.`);
      await this.loadUserIllusts(userId, this.nextIllustUrl);
    } else if (this.tabIndex === 1 && this.nextBookmarkUrl) {
      logger.debug(`[loadMoreCurrentData] Triggering Bookmark LoadMore.`);
      await this.loadUserBookmarks(userId, this.nextBookmarkUrl);
    } else {
      logger.debug(`[loadMoreCurrentData] No more data to load. Tab: ${this.tabIndex}`);
    }
  }

}

export const uDV = new UserDetailViewModel();
