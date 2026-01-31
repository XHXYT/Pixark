import { PixivIllust, PixivListResult, PixivTrendingTag,
  SearchFilterOptions,
  SearchUserResult, SpotlightResponse } from './PixivTypes';
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
   * 搜索插画 (支持高级筛选)
   * @param word 关键词
   * @param nextUrl 分页 URL (用于加载更多)
   * @param options 筛选选项 (仅在 nextUrl 为空时生效)
   */
  async searchIllust(word: string, nextUrl?: string, options?: SearchFilterOptions): Promise<PixivListResult> {
    if (!this.auth.isLogin()) throw new Error('请先登录');

    let url = '/v1/search/illust';
    let params: Record<string, any> | undefined = undefined;

    if (nextUrl) {
      // --- 加载更多 ---
      // nextUrl 已经包含了 word, sort, minBookmark 等所有参数，直接用即可
      url = nextUrl;
      params = undefined;
    } else {
      // --- 新搜索 (带上筛选参数) ---
      logger.info(`Searching: ${word}, Options: ${JSON.stringify(options)}`);
      params = {
        word: word,
        filter: 'for_android',
      };
      // 处理排序 (默认最新)
      params.sort = options?.sort || 'date_desc';
      // 处理匹配范围 (默认部分标签匹配)
      params.search_target = options?.searchTarget || 'partial_match_for_tags';
      // 处理时间范围
      if (options?.startDate) params.start_date = options.startDate;
      if (options?.endDate) params.end_date = options.endDate;
      // 处理收藏数筛选
      if (options?.minBookmark && options.minBookmark > 0) {
        params.bookmark_count_min = options.minBookmark;
      }
      // 处理 AI 筛选 (可选)
      if (options?.aiType !== undefined) {
        params.search_ai_type = options.aiType;
      }
    }
    const response = await this.auth.axiosInstance.get<PixivListResult>(url, { params });
    return {
      illusts: response.data.illusts || [],
      next_url: response.data.next_url || null,
    };
  }

  /**
   * 搜索用户（画师）
   * @param word 搜索词（作者名 / 账号名）
   * @param nextUrl 可选，用于翻页
   */
  async searchUser(word: string, nextUrl?: string): Promise<SearchUserResult> {
    if (!this.auth.isLogin()) {
      throw new Error('请先登录');
    }
    let url = '/v1/search/user';
    let params: Record<string, string> | undefined = undefined;
    if (nextUrl) {
      // 加载更多
      url = nextUrl;
      params = undefined;
    } else {
      // 搜索
      params = {
        word,
        filter: 'for_android',
      };
    }
    const resp = await this.auth.axiosInstance.get<SearchUserResult>(url, { params });
    return {
      user_previews: resp.data.user_previews || [],
      next_url: resp.data.next_url || null,
    };
  }

  /**
   * 获取热门标签（用于搜索页推荐）
   * @returns 返回热门标签列表
   */
  async getTrendingTags(): Promise<PixivTrendingTag[]> {
    const response = await this.auth.axiosInstance.get('/v1/trending-tags/illust');
    return response.data.trend_tags || [];
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
   * @param includeRanking 是否在推荐中混入排行榜作品 (默认: true)
   * @param url 分页的 next_url (可选，如果传入了 url，includeRanking 参数将被忽略)
   * @returns 返回推荐作品列表
   */
  async getRecommended(includeRanking: boolean = true, url?: string): Promise<PixivListResult> {
    if (!this.auth.isLogin()) throw new Error('请先登录');

    let requestUrl = '/v1/illust/recommended';
    let params: Record<string, any> | undefined = undefined;
    if (url) {
      // --- 优先处理分页 URL ---
      // 兼容处理：完整URL、相对路径、纯参数字符串
      if (url.startsWith('http')) {
        requestUrl = url;
      } else if (url.startsWith('/')) {
        requestUrl = url;
      } else {
        // 兜底：如果是类似 "filter=xxx" 的参数串
        requestUrl = `/v1/illust/recommended?${url}`;
      }
    } else {
      // --- 常规加载 ---
      params = {
        filter: 'for_android',
        include_ranking_illusts: String(includeRanking),
      };
    }
    const response = await this.auth.axiosInstance.get(requestUrl, { params });
    return {
      illusts: response.data.illusts || [],
      next_url: response.data.next_url || null,
    };
  }

  /**
   * 获取关注用户的插画动态流
   * @param restrict 关注类型：'public'=公开关注，'private'=私密关注（仅在 nextUrl 为空时生效）
   * @param nextUrl 分页 URL（可选，传入后会忽略 restrict 参数，直接用该 URL 请求）
   * @returns 返回插画列表和下一页 URL
   */
  async getFollowIllusts(restrict: 'public' | 'private' = 'public', nextUrl?: string): Promise<PixivListResult> {
    if (!this.auth.isLogin()) {
      throw new Error('请先登录');
    }

    let requestUrl = '/v2/illust/follow';
    let params: Record<string, any> | undefined = undefined;

    if (nextUrl) {
      // --- 优先处理分页 URL ---
      // 兼容处理：完整URL、相对路径、纯参数字符串
      if (nextUrl.startsWith('http')) {
        requestUrl = nextUrl;
      } else if (nextUrl.startsWith('/')) {
        requestUrl = nextUrl;
      } else {
        // 兜底：纯参数串
        requestUrl = `/v2/illust/follow?${nextUrl}`;
      }
    } else {
      // --- 常规加载 ---
      params = {
        restrict: restrict,
        filter: 'for_android',
      };
    }

    const response = await this.auth.axiosInstance.get(requestUrl, { params });

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
   * 获取相关推荐作品
   * @param illustId 当前插画 ID
   * @returns 返回相关推荐作品列表
   */
  async getRelatedIllusts(illustId: number): Promise<PixivListResult> {
    if (!this.auth.isLogin()) throw new Error('请先登录');
    logger.info(`Fetching related illusts for ID: ${illustId}`);
    // 使用 v2 接口获取相关推荐，功能比 v1 更全
    const response = await this.auth.axiosInstance.get('/v2/illust/related', {
      params: {
        illust_id: illustId,
        filter: 'for_android',
        // seed: illustId // 可选，有时为了结果稳定性可以加上
      },
    });

    return {
      illusts: response.data.illusts || [],
      next_url: response.data.next_url || null,
    };
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
