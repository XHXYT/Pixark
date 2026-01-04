import { PixState } from '../entryability/AppState';
import { PixivIllust, PixivUser, SpotlightArticle, SpotlightResponse, PixivListResult } from '../services/PixivTypes';
import { createLogger } from '../utils/Logger';
import { BusinessError } from '@kit.BasicServicesKit';
import { toastUtil } from '../utils/ToastUtils';
import { shuffleArray } from '../utils/FisherYates';

const logger = createLogger('HomeViewModel')

@ObservedV2
class HomeViewModel {

  @Trace spotlightList: SpotlightArticle[] = []; // 亮点列表
  @Trace recommendedUsers: PixivUser[] = [];      // 推荐作者列表
  @Trace recommendedIllusts: PixivIllust[] = [];  // 推荐图片列表

  // 存储下一页的 URL，用于加载更多
  @Trace nextRecommendedUrl: string = '';

  isRefreshRecommend: boolean = false
  // 是否正在加载更多（用于防止滚动到底部重复触发）
  isLoadingMore: boolean = false;
  // 是否正在刷新加载所有数据
  isRefreshing: boolean = false

  // 外层 List 的滚动控制器
  listScroller: Scroller = new Scroller();

  // 嵌套滚动配置
  get nestedScrollOptions(): NestedScrollOptions {
    return {
      scrollForward: NestedScrollMode.PARENT_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST,
    };
  }

  async loadHomeData() {
    if (this.isRefreshing) {
      logger.warn('>>> 正在加载所有数据中，忽略重复请求');
      return;
    }
    logger.debug('>>> 开始加载首页数据...');
    this.isRefreshing = true
    try {
      // 检查登录状态
      if (!PixState.pixiv.isLogin()) {
        logger.warn('>>> 用户未登录，停止加载');
        return;
      }
      logger.debug('>>> 用户已登录，开始并发请求推荐接口');
      // 构建并发任务
      const tasks: [Promise<SpotlightResponse>, Promise<PixivListResult>] = [
        PixState.pixiv.getSpotlight(),
        PixState.pixiv.getRecommended(true)
      ];
      // 等待所有任务完成
      const results: [SpotlightResponse, PixivListResult] = await Promise.all(tasks);
      logger.debug('>>> 所有接口请求成功返回');

      // 处理亮点数据
      const spotlightData = results[0];
      if (spotlightData.spotlight_articles) {
        this.spotlightList = spotlightData.spotlight_articles;
        logger.debug(`>>> 亮点文章加载完毕，数量: ${this.spotlightList.length}`);
      } else {
        logger.warn('>>> 亮点文章数据为空');
      }

      // 处理推荐图片
      const recData = results[1];
      if (recData.illusts) {
        // 储存下一页地址
        this.nextRecommendedUrl = recData.next_url || '';
        // 初始加载直接赋值
        this.recommendedIllusts = recData.illusts;
        logger.debug(`>>> 推荐插画加载完毕，数量: ${this.recommendedIllusts.length}`);
      }
      // 提取推荐作者逻辑
      this.extractRecommendedUsers(recData.illusts);

      logger.debug('>>> 首页数据加载流程全部结束');
    } catch (e) {
      const err = e as BusinessError;
      logger.error(`!!! 加载首页数据失败: code[${err.code}], msg[${err.message}]`);
    } finally {
      this.isRefreshing = false
    }
  }

  /**
   * 刷新推荐图片列表
   * 用于刷新推荐图片(双击tab栏图标)等场景，会清空当前列表并重新请求第一页数据
   */
  async refreshRecommended() {
    if (this.isRefreshRecommend) {
      logger.warn('>>> 正在加载推荐图片数据中，忽略重复请求');
      return;
    }
    try {
      logger.debug('>>> 开始刷新推荐列表...');
      this.isRefreshRecommend = true
      // 请求第一页数据
      const data = await PixState.pixiv.getRecommended(true);
      const newIllusts = data.illusts || [];
      // 重置推荐列表
      this.recommendedIllusts = newIllusts;
      // 重置下一页链接
      this.nextRecommendedUrl = data.next_url || '';
      // 重新提取推荐作者 TODO 后续改成用户可选是否更新推荐作者
      this.extractRecommendedUsers(newIllusts);
      logger.debug(`>>> 推荐列表刷新完毕，数量: ${this.recommendedIllusts.length}`);
      toastUtil.showToast({ message: '刷新成功' });
    } catch (e) {
      const err = e as BusinessError;
      logger.error(`!!! 刷新推荐列表失败: code[${err.code}], msg[${err.message}]`);
      toastUtil.showToast({ message: $r('app.string.loading_failed') });
    } finally {
      this.isRefreshRecommend = false
    }
  }

  /**
   * 加载更多推荐图片
   * 用于滚动加载更多推荐
   */
  async loadMoreRecommended(url?: string) {
    // 防抖：如果正在加载中，直接返回
    if (this.isLoadingMore) {
      logger.warn('>>> 正在加载中，忽略重复请求');
      return;
    }
    // 判断是否有更多数据
    if (!url && !this.nextRecommendedUrl) {
      toastUtil.showToast({ message: $r('app.string.recommend_not_tips') });
      logger.warn('>>> 没有更多推荐可加载了');
      return;
    }
    try {
      // 上锁
      this.isLoadingMore = true;
      toastUtil.showToast({ message: $r('app.string.loading_more'), duration: 3000 })
      // 确定请求目标
      const targetUrl = url || this.nextRecommendedUrl;
      logger.debug(`>>> 开始加载更多推荐，URL: ${targetUrl}`);
      // 请求数据
      const data = await PixState.pixiv.getRecommended(undefined, targetUrl);
      const newIllusts = data.illusts || [];
      // 更新下一页链接
      if (data.next_url) {
        this.nextRecommendedUrl = data.next_url;
      } else {
        this.nextRecommendedUrl = '';
      }
      // 合并、去重
      this.mergeAndLimitRecommended(newIllusts);
      logger.debug(`>>> 推荐图片更新完毕，当前总数: ${this.recommendedIllusts.length}`);
    } catch (e) {
      const err = e as BusinessError;
      logger.error(`!!! 加载更多推荐失败: code[${err.code}], msg[${err.message}]`);
      toastUtil.showToast({ message: $r('app.string.loading_failed') });
    } finally {
      // 解锁
      this.isLoadingMore = false;
    }
  }

  /**
   * 提取推荐图片的作者（随机选取）
   */
  private extractRecommendedUsers(illusts: PixivIllust[]) {
    if (!illusts || illusts.length === 0) return;
    // 先使用 Map 去重，拿到所有唯一的作者
    const uniqueUserMap = new Map<number, PixivUser>();
    illusts.forEach(illust => {
      if (!uniqueUserMap.has(illust.user.id)) {
        uniqueUserMap.set(illust.user.id, illust.user);
      }
    });
    // 将 Map 转换为数组
    const allUniqueUsers = Array.from(uniqueUserMap.values());
    // 如果总作者数小于等于 20，直接使用
    if (allUniqueUsers.length <= 20) {
      this.recommendedUsers = allUniqueUsers;
    } else {
      // 作者过多，先打乱数组(直接更改数组顺序)，再取前 20 个
      shuffleArray(allUniqueUsers);
      this.recommendedUsers = allUniqueUsers.slice(0, 20);
    }
    logger.info(`>>> 提取随机推荐作者，数量: ${this.recommendedUsers.length}`);
  }

  /**
   * 工具函数：合并新推荐、去重
   */
  private mergeAndLimitRecommended(newIllusts: PixivIllust[]) {
    if (newIllusts.length === 0) return;

    const uniqueMap = new Map<number, PixivIllust>();
    // 先把旧数据放入 Map (保持顺序在前面)
    this.recommendedIllusts.forEach(illust => {
      uniqueMap.set(illust.id, illust);
    });
    // 遍历新数据，如果 ID 不在 Map 中，则追加到后面
    newIllusts.forEach(illust => {
      if (!uniqueMap.has(illust.id)) {
        uniqueMap.set(illust.id, illust);
      }
    });
    let mergedList = Array.from(uniqueMap.values());
    this.recommendedIllusts = mergedList;
  }

}

export const homeViewModel = new HomeViewModel();
