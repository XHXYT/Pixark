import { PixivIllust, PixivListResult, SpotlightResponse } from './PixivTypes';
import { PixivAuth } from './PixivAuth';
import { createLogger } from '../utils/Logger';

const logger = createLogger('PixivData')

/**
 * 数据服务类
 * 处理各种数据获取接口：搜索、排行、推荐等
 */
export class PixivData {
  constructor(private auth: PixivAuth) {}

  /**
   * 搜索插画
   * @param word 搜索关键词
   * @param page 页码 (从 1 开始)
   * @param pageSize 每页数量
   * @returns 返回搜索结果列表
   */
  async searchIllust(word: string, page: number = 1, pageSize: number = 30): Promise<PixivListResult> {
    if (!this.auth.isLogin()) throw new Error('请先登录');
    logger.info(`Searching: ${word}`);

    const response = await this.auth.axiosInstance.get('/v1/search/illust', {
      params: {
        word: word,
        page: page,
        per_page: pageSize,
        filter: 'for_android',
      },
    });
    return {
      illusts: response.data.illusts || [],
      next_url: response.data.next_url || null,
    };
  }

  /**
   * 获取排行榜
   * @param mode 排行榜模式 (day: 日榜, week: 周榜, month: 月榜, day_r18: R18日榜 等)
   * @param date 指定日期 (格式: 2020-01-01)，不传则默认为最新
   * @returns 返回排行榜插画列表
   */
  async getRanking(mode: string = 'day', date?: string): Promise<PixivListResult> {
    if (!this.auth.isLogin()) throw new Error('请先登录');

    const params: Record<string, string> = {
      mode: mode,
      filter: 'for_android',
    };
    if (date) params.date = date;
    const response = await this.auth.axiosInstance.get('/v1/illust/ranking', { params });
    return {
      illusts: response.data.illusts || [],
      next_url: response.data.next_url || null,
    };
  }

  /**
   * 获取 Pixiv 亮点/专题文章列表
   * 用途：通常用于 App 首页顶部的轮播图（Banner）展示。
   *
   * @param category 文章分类，默认 'all'。
   *                 可选值包括：
   *                 - 'all': 全部分类
   *                 - 'android': 官方精选
   *                 - 'illustration': 插画专题
   * @returns Promise<SpotlightResponse> 返回包含文章列表和下一页 URL 的响应对象
   */
  async getSpotlight(category: string = 'all'): Promise<SpotlightResponse> {
    if (!this.auth.isLogin()) {
      throw new Error('请先登录');
    }
    logger.info(`Fetching spotlight articles. Category: ${category}`);
    try {
      const response = await this.auth.axiosInstance.get('/v1/spotlight/articles', {
        params: {
          category: category,
          filter: 'for_android', // 强制使用 Android 过滤器
          // show_lang: true // 如果需要多语言支持，可以尝试加上这个参数
        },
      });
      // 返回标准化的响应对象
      return response.data;
    } catch (error: any) {
      logger.error('Get spotlight failed: ' + JSON.stringify(error));
      throw error;
    }
  }


  /**
   * 获取个性化推荐
   * 根据用户的收藏和浏览历史推荐作品
   * @param includeRanking 是否在推荐中混入排行榜作品
   * @returns 返回推荐作品列表
   */
  async getRecommended(includeRanking: boolean = true): Promise<PixivListResult> {
    if (!this.auth.isLogin()) throw new Error('请先登录');

    const response = await this.auth.axiosInstance.get('/v1/illust/recommended', {
      params: {
        filter: 'for_android',
        include_ranking_illusts: String(includeRanking),
      },
    });
    return {
      illusts: response.data.illusts || [],
      next_url: response.data.next_url || null,
    };
  }

  /**
   * 获取作品详情
   * 包含图片的高清地址、标签、画师信息等
   * @param illustId 作品 ID
   * @returns 返回作品详细信息对象
   */
  async getIllustDetail(illustId: number): Promise<PixivIllust> {
    if (!this.auth.isLogin()) throw new Error('请先登录');
    const response = await this.auth.axiosInstance.get('/v1/illust/detail', {
      params: { illust_id: illustId, filter: 'for_android' },
    });
    return response.data.illust;
  }

  /**
   * 获取用户的作品列表
   * @param userId 用户 ID
   * @param type 作品类型 (illust: 插画, manga: 漫画)
   * @returns 返回该用户的作品列表
   */
  async getUserIllusts(userId: number, type: 'illust' | 'manga' = 'illust'): Promise<PixivListResult> {
    if (!this.auth.isLogin()) throw new Error('请先登录');
    const response = await this.auth.axiosInstance.get('/v1/user/illusts', {
      params: { user_id: userId, type: type, filter: 'for_android' },
    });
    return {
      illusts: response.data.illusts || [],
      next_url: response.data.next_url || null,
    };
  }

  /**
   * 获取用户的收藏列表 (书签)
   * @param userId 目标用户的 ID
   *               【注意】如果想获取"我自己的"收藏，这里需要传入登录成功后返回的 user.id
   * @param restrict 收藏的类型，可选值：
   *                 - 'public': 公开收藏 (默认，别人也能看到的)
   *                 - 'private': 私密收藏 (只有自己能看到的)
   * @param tag 用于过滤收藏的标签 (可选) 如果你只想看某个标签下的收藏，可以传这个参数
   * @param maxBookmarkId 分页参数 (可选)
   *                     Pixiv 的分页是基于时间戳倒序的，这个值通常是上一次请求列表中"最后一个"作品的 bookmark_id
   *                     传了这个值，接口会返回比这个 ID 更早的收藏，即"上一页"或"加载更多"
   * @returns 返回收藏的插画列表
   */
  async getUserBookmarks(
    userId: number,
    restrict: 'public' | 'private' = 'public',
    tag?: string,
    maxBookmarkId?: number
  ): Promise<PixivListResult> {
    // 检查登录状态
    if (!this.auth.isLogin()) {
      throw new Error('请先登录');
    }
    logger.info(`Getting bookmarks for user: ${userId}, restrict:${restrict}`);
    // 构建请求参数
    const params: Record<string, string | number> = {
      user_id: userId,
      restrict: restrict,
      filter: 'for_android', // 使用 Android 过滤器
    };
    // 处理可选参数
    if (tag) {
      params['tag'] = tag;
    }
    if (maxBookmarkId) {
      params['max_bookmark_id'] = maxBookmarkId;
    }
    try {
      // 发送 GET 请求到收藏接口
      const response = await this.auth.axiosInstance.get('/v1/user/bookmarks/illust', {
        params: params,
      });
      logger.info(`Bookmarks loaded. Count: ${response.data.illusts?.length}`);
      // 返回标准化的结果格式
      return {
        illusts: response.data.illusts || [],
        next_url: response.data.next_url || null,
      };
    } catch (error: any) {
      logger.error('Get bookmarks failed: ' + JSON.stringify(error));
      throw error;
    }
  }

  /**
   * 使用 next_url 获取下一页数据（通用方法）
   * @param nextUrl 上一页接口返回的 next_url，如：
   *                "https://app-api.pixiv.net/v1/search/illust?word=xxx&filter=for_android&offset=30"
   * @returns 下一页的搜索/收藏/排行等结果
   */
  async loadNextPage(nextUrl: string): Promise<PixivListResult> {
    if (!this.auth.isLogin()) {
      throw new Error('请先登录');
    }
    if (!nextUrl) {
      throw new Error('next_url 为空，没有更多数据了');
    }
    logger.info(`Loading next page: ${nextUrl}`);
    try {
      // 注意：这里使用 this.auth.axiosInstance，会自动带 Authorization 和 User-Agent
      const response = await this.auth.axiosInstance.get(nextUrl);
      const count = response.data.illusts?.length ?? 0;
      logger.info(`Next page loaded. Count: ${count}`);
      return {
        illusts: response.data.illusts || [],
        next_url: response.data.next_url || null,
      };
    } catch (error: any) {
      logger.error('Load next page failed: ' + JSON.stringify(error));
      throw error;
    }
  }

}
