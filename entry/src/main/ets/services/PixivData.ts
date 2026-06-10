import {
  PixivCommentsResponse,
  PixivIllust,
  PixivListResult,
  PixivNovel,
  PixivTrendingTag,
  SearchFilterOptions,
  SearchUserResult,
  SpotlightResponse,
  UserDetailResponse,
  UserPreview,
  NovelTextResponse,
  NovelWebResponse,
  NovelSeriesResponse,
  NovelWatchListResponse,
  MangaWatchListResponse,
  IllustSeriesResponse,
  IllustSeriesIllustResponse,
  UgoiraMetadata,
  IllustBookmarkDetail,
  BookmarkTag,
  FollowDetail,
  AutoCompleteResponse,
  UserAISettingsResponse,
  UserRestrictedModeResponse,
  BookmarkTagsResponse,
  UgoiraMetadataResponse,
  IllustBookmarkDetailResponse,
} from './PixivTypes';
import { PixivAuth } from './PixivAuth';
import { createLogger } from '../common/utils/Logger';

const logger = createLogger('PixivData');

/**
 * 数据服务类
 * 处理各种数据获取接口：搜索、排行、推荐等
 */
export class PixivData {
  constructor(private auth: PixivAuth) {}

  /**
   * 通用 GET 请求封装
   */
  private async fetchApi<T>(
    initialUrl: string,
    initialParams: Record<string, any> | undefined,
    nextUrl?: string
  ): Promise<T> {
    if (!this.auth.isLogin()) throw new Error('请先登录');
    const url = nextUrl || initialUrl;
    const params = nextUrl ? undefined : initialParams;
    const response = await this.auth.axiosInstance.get<T>(url, { params });
    return response.data;
  }

  // ==============================
  // 插画模块
  // ==============================

  /**
   * 搜索插画
   */
  async searchIllust(
    word: string,
    nextUrl?: string,
    options?: SearchFilterOptions
  ): Promise<PixivListResult> {
    const params: Record<string, any> = {
      word,
      filter: 'for_android',
      merge_plain_keyword_results: true,
      sort: options?.sort || 'date_desc',
      search_target: options?.searchTarget || 'partial_match_for_tags',
    };
    if (options?.startDate) params.start_date = options.startDate;
    if (options?.endDate) params.end_date = options.endDate;
    if (options?.minBookmark && options.minBookmark > 0) params.bookmark_num_min = options.minBookmark;
    if (options?.maxBookmark && options.maxBookmark > 0) params.bookmark_num_max = options.maxBookmark;
    if (options?.aiType !== undefined) params.search_ai_type = options.aiType;

    const data = await this.fetchApi<PixivListResult>('/v1/search/illust', params, nextUrl);
    return { illusts: data.illusts || [], next_url: data.next_url || null };
  }

  /**
   * 搜索热门预览
   */
  async getPopularPreview(keyword: string): Promise<PixivListResult> {
    const params = {
      word: keyword,
      filter: 'for_android',
      include_translated_tag_results: true,
      merge_plain_keyword_results: true,
      search_target: 'partial_match_for_tags',
    };
    const data = await this.fetchApi<PixivListResult>(
      '/v1/search/popular-preview/illust',
      params
    );
    return { illusts: data.illusts || [], next_url: data.next_url || null };
  }

  /**
   * 插画排行榜
   */
  async getRanking(
    mode: string = 'day',
    date?: string,
    nextUrl?: string
  ): Promise<PixivListResult> {
    const params = { mode, date, filter: 'for_android' };
    const data = await this.fetchApi<PixivListResult>(
      '/v1/illust/ranking',
      params,
      nextUrl
    );
    return { illusts: data.illusts || [], next_url: data.next_url || null };
  }

  /**
   * 推荐插画
   */
  async getRecommended(
    includeRanking: boolean = true,
    nextUrl?: string
  ): Promise<PixivListResult> {
    const params = {
      filter: 'for_ios', // Dart 版使用 for_ios
      include_ranking_label: true,
    };
    const data = await this.fetchApi<PixivListResult>(
      '/v1/illust/recommended',
      params,
      nextUrl
    );
    return { illusts: data.illusts || [], next_url: data.next_url || null };
  }

  /**
   * 推荐漫画
   */
  async getMangaRecommended(nextUrl?: string): Promise<PixivListResult> {
    const params = { filter: 'for_ios', include_ranking_label: true };
    const data = await this.fetchApi<PixivListResult>(
      '/v1/manga/recommended',
      params,
      nextUrl
    );
    return { illusts: data.illusts || [], next_url: data.next_url || null };
  }

  /**
   * 关注用户的插画
   */
  async getFollowIllusts(
    restrict: 'public' | 'private' = 'public',
    nextUrl?: string
  ): Promise<PixivListResult> {
    const params = { restrict };
    const data = await this.fetchApi<PixivListResult>(
      '/v2/illust/follow',
      params,
      nextUrl
    );
    return { illusts: data.illusts || [], next_url: data.next_url || null };
  }

  /**
   * 插画详情
   */
  async getIllustDetail(illust_id: number): Promise<PixivIllust> {
    const data = await this.fetchApi<{ illust: PixivIllust }>(
      '/v1/illust/detail',
      { illust_id, filter: 'for_android' }
    );
    return data.illust;
  }

  /**
   * 相关插画
   */
  async getRelatedIllusts(
    illust_id: number,
    nextUrl?: string
  ): Promise<PixivListResult> {
    const params = { illust_id, filter: 'for_android' };
    const data = await this.fetchApi<PixivListResult>(
      '/v2/illust/related',
      params,
      nextUrl
    );
    return { illusts: data.illusts || [], next_url: data.next_url || null };
  }

  /**
   * 动图元数据
   */
  async getUgoiraMetadata(illust_id: number): Promise<UgoiraMetadata> {
    const data = await this.fetchApi<UgoiraMetadataResponse>(
      '/v1/ugoira/metadata',
      { illust_id }
    );
    return data.ugoira_metadata;
  }

  /**
   * 插画收藏详情（含标签列表）
   */
  async getIllustBookmarkDetail(illust_id: number): Promise<IllustBookmarkDetail> {
    const data = await this.fetchApi<IllustBookmarkDetailResponse>(
      '/v2/illust/bookmark/detail',
      { illust_id }
    );
    return data.bookmark_detail;
  }

  /**
   * walkthrough 插画
   */
  async walkthroughIllusts(): Promise<PixivListResult> {
    const data = await this.fetchApi<PixivListResult>(
      '/v1/walkthrough/illusts',
      undefined
    );
    return { illusts: data.illusts || [], next_url: null };
  }

  /**
   * 插画热门标签
   */
  async getIllustTrendTags(): Promise<PixivTrendingTag[]> {
    const data = await this.fetchApi<PixivTrendingTag[]>(
      '/v1/trending-tags/illust',
      { filter: 'for_android' }
    );
    return data['trend_tags'] || [];
  }

  /**
   * 搜索自动补全
   */
  async getSearchAutocomplete(word: string): Promise<AutoCompleteResponse> {
    return this.fetchApi<AutoCompleteResponse>(
      '/v2/search/autocomplete',
      { word, merge_plain_keyword_results: true }
    );
  }

  /**
   * 插画系列
   */
  async illustSeries(
    illustSeriesId: number,
    nextUrl?: string
  ): Promise<IllustSeriesResponse> {
    const params = { illust_series_id: illustSeriesId, filter: 'for_ios' };
    return this.fetchApi<IllustSeriesResponse>(
      '/v1/illust/series',
      params,
      nextUrl
    );
  }

  /**
   * 插画系列中的插画
   */
  async illustSeriesIllust(
    illustId: number,
    nextUrl?: string
  ): Promise<IllustSeriesIllustResponse> {
    const params = { illust_id: illustId };
    return this.fetchApi<IllustSeriesIllustResponse>(
      '/v1/illust-series/illust',
      params,
      nextUrl
    );
  }

  // ==============================
  // 小说模块
  // ==============================

  /**
   * 搜索小说
   */
  async searchNovel(
    word: string,
    nextUrl?: string,
    options?: SearchFilterOptions
  ): Promise<PixivListResult> {
    const params: Record<string, any> = {
      word,
      filter: 'for_android',
      merge_plain_keyword_results: true,
      sort: options?.sort || 'date_desc',
      search_target: options?.searchTarget || 'partial_match_for_tags',
    };
    if (options?.startDate) params.start_date = options.startDate;
    if (options?.endDate) params.end_date = options.endDate;
    if (options?.minBookmark) params.bookmark_num = options.minBookmark;

    const data = await this.fetchApi<PixivListResult>(
      '/v1/search/novel',
      params,
      nextUrl
    );
    return { novels: data.novels || [], next_url: data.next_url || null };
  }

  /**
   * 小说排行榜
   */
  async getNovelRanking(
    mode: string,
    date?: string,
    nextUrl?: string
  ): Promise<PixivListResult> {
    const params = { mode, date, filter: 'for_android' };
    const data = await this.fetchApi<PixivListResult>(
      '/v1/novel/ranking',
      params,
      nextUrl
    );
    return { novels: data.novels || [], next_url: data.next_url || null };
  }

  /**
   * 推荐小说
   */
  async getNovelRecommended(nextUrl?: string): Promise<PixivListResult> {
    const params = {
      include_privacy_policy: true,
      filter: 'for_android',
      include_ranking_novels: true,
    };
    const data = await this.fetchApi<PixivListResult>(
      '/v1/novel/recommended',
      params,
      nextUrl
    );
    return { novels: data.novels || [], next_url: data.next_url || null };
  }

  /**
   * 关注用户的小说
   */
  async getNovelFollow(
    restrict: string,
    nextUrl?: string
  ): Promise<PixivListResult> {
    const data = await this.fetchApi<PixivListResult>(
      '/v1/novel/follow',
      { restrict },
      nextUrl
    );
    return { novels: data.novels || [], next_url: data.next_url || null };
  }

  /**
   * 小说详情
   */
  async getNovelDetail(novel_id: number): Promise<PixivNovel> {
    const data = await this.fetchApi<{ novel: PixivNovel }>(
      '/v2/novel/detail',
      { novel_id }
    );
    return data.novel;
  }

  /**
   * 获取小说文本
   * @returns 完整响应，包含标记和系列导航
   */
  async getNovelText(novel_id: number): Promise<NovelTextResponse> {
    return this.fetchApi<NovelTextResponse>('/v1/novel/text', { novel_id });
  }

  /**
   * WebView 小说（HTML web返回值版）
   */
  async webviewNovel(novel_id: number): Promise<NovelWebResponse> {
    return this.fetchApi<NovelWebResponse>('/webview/v2/novel', { id: novel_id });
  }

  /**
   * WebView 小说（HTML 富文本版）
   */
  async webviewNovelHtml(novel_id: number): Promise<string> {
    return this.fetchApi<string>('/webview/v2/novel', { id: novel_id });
  }

  /**
   * 用户的小说
   */
  async getUserNovels(
    userId: number,
    nextUrl?: string
  ): Promise<PixivListResult> {
    const params = { user_id: userId, filter: 'for_android' };
    const data = await this.fetchApi<PixivListResult>(
      '/v1/user/novels',
      params,
      nextUrl
    );
    return { novels: data.novels || [], next_url: data.next_url || null };
  }

  /**
   * 小说热门标签
   */
  async getNovelTrendTags(): Promise<PixivTrendingTag[]> {
    const data = await this.fetchApi<{ trend_tags: PixivTrendingTag[] }>(
      '/v1/trending-tags/novel',
      { filter: 'for_android' }
    );
    return data.trend_tags || [];
  }

  /**
   * 小说评论列表
   */
  async getNovelComments(
    novel_id: number,
    nextUrl?: string
  ): Promise<PixivCommentsResponse> {
    const data = await this.fetchApi<PixivCommentsResponse>(
      '/v3/novel/comments',
      { novel_id },
      nextUrl
    );
    return { comments: data.comments || [], next_url: data.next_url || null };
  }

  /**
   * 小说评论回复
   */
  async getNovelCommentsReplies(
    comment_id: number,
    nextUrl?: string
  ): Promise<PixivCommentsResponse> {
    const data = await this.fetchApi<PixivCommentsResponse>(
      '/v2/novel/comment/replies',
      { comment_id },
      nextUrl
    );
    return { comments: data.comments || [], next_url: data.next_url || null };
  }

  /**
   * 小说系列详情
   */
  async novelSeries(
    series_id: number,
    nextUrl?: string
  ): Promise<NovelSeriesResponse> {
    return this.fetchApi<NovelSeriesResponse>(
      '/v2/novel/series',
      { series_id },
      nextUrl
    );
  }

  /**
   * 小说关注列表
   */
  async watchListNovel(nextUrl?: string): Promise<NovelWatchListResponse> {
    return this.fetchApi<NovelWatchListResponse>(
      '/v1/watchlist/novel',
      undefined,
      nextUrl
    );
  }

  /**
   * 漫画关注列表
   */
  async watchListManga(nextUrl?: string): Promise<MangaWatchListResponse> {
    return this.fetchApi<MangaWatchListResponse>(
      '/v1/watchlist/manga',
      undefined,
      nextUrl
    );
  }

  // ==============================
  // 用户模块
  // ==============================

  /**
   * 搜索用户
   * 对应 Dart getSearchUser
   */
  async searchUser(
    word: string,
    nextUrl?: string
  ): Promise<SearchUserResult> {
    const params = { word, filter: 'for_android' };
    const data = await this.fetchApi<SearchUserResult>(
      '/v1/search/user',
      params,
      nextUrl
    );
    return {
      user_previews: data.user_previews || [],
      next_url: data.next_url || null,
    };
  }

  /**
   * 推荐用户
   */
  async getUserRecommended(nextUrl?: string): Promise<SearchUserResult> {
    const params = { filter: 'for_android' };
    const data = await this.fetchApi<SearchUserResult>(
      '/v1/user/recommended',
      params,
      nextUrl
    );
    return {
      user_previews: data.user_previews || [],
      next_url: data.next_url || null,
    };
  }

  /**
   * 用户详情
   */
  async getUserDetail(userId: number): Promise<UserDetailResponse> {
    return this.fetchApi<UserDetailResponse>('/v1/user/detail', {
      user_id: userId,
      filter: 'for_android',
    });
  }

  /**
   * 用户的插画/漫画
   */
  async getUserIllusts(
    userId: number,
    type: 'illust' | 'manga' = 'illust',
    nextUrl?: string
  ): Promise<PixivListResult> {
    const params = { user_id: userId, type, filter: 'for_android' };
    const data = await this.fetchApi<PixivListResult>(
      '/v1/user/illusts',
      params,
      nextUrl
    );
    return { illusts: data.illusts || [], next_url: data.next_url || null };
  }

  /**
   * 用户收藏的插画
   */
  async getUserBookmarks(
    userId: number,
    restrict: 'public' | 'private' = 'public',
    tag?: string,
    maxBookmarkId?: number,
    nextUrl?: string
  ): Promise<PixivListResult> {
    const params: Record<string, any> = {
      user_id: userId,
      restrict,
      filter: 'for_android',
    };
    if (tag) params.tag = tag;
    if (maxBookmarkId) params.max_bookmark_id = maxBookmarkId;

    const data = await this.fetchApi<PixivListResult>(
      '/v1/user/bookmarks/illust',
      params,
      nextUrl
    );
    return { illusts: data.illusts || [], next_url: data.next_url || null };
  }

  /**
   * 用户收藏的小说
   */
  async getUserBookmarkNovel(
    userId: number,
    restrict: string,
    nextUrl?: string
  ): Promise<PixivListResult> {
    const params = { user_id: userId, restrict };
    const data = await this.fetchApi<PixivListResult>(
      '/v1/user/bookmarks/novel',
      params,
      nextUrl
    );
    return { novels: data.novels || [], next_url: data.next_url || null };
  }

  /**
   * 用户收藏标签列表
   */
  async getUserBookmarkTagsIllust(
    userId: number,
    restrict: string = 'public'
  ): Promise<BookmarkTagsResponse> {
    return this.fetchApi<BookmarkTagsResponse>('/v1/user/bookmark-tags/illust', {
      user_id: userId,
      restrict,
    });
  }

  /**
   * 用户正在关注的人
   */
  async getUserFollowing(
    userId: number,
    restrict: 'public' | 'private' = 'public',
    nextUrl?: string
  ): Promise<SearchUserResult> {
    const params = { user_id: userId, restrict, filter: 'for_android' };
    const data = await this.fetchApi<SearchUserResult>(
      '/v1/user/following',
      params,
      nextUrl
    );
    return {
      user_previews: data.user_previews || [],
      next_url: data.next_url || null,
    };
  }

  /**
   * 用户的粉丝/关注者
   */
  async getFollowUser(
    userId: number,
    restrict: 'public' | 'private' = 'public',
    nextUrl?: string
  ): Promise<SearchUserResult> {
    const params = { user_id: userId, restrict, filter: 'for_android' };
    const data = await this.fetchApi<SearchUserResult>(
      '/v1/user/follower',
      params,
      nextUrl
    );
    return {
      user_previews: data.user_previews || [],
      next_url: data.next_url || null,
    };
  }

  /**
   * 用户关注详情
   */
  async getUserFollowDetail(userId: number): Promise<FollowDetail> {
    const data = await this.fetchApi<{ follow_detail: FollowDetail }>(
      '/v1/user/follow/detail',
      { user_id: userId }
    );
    return data.follow_detail;
  }

  /**
   * 获取所有关注（自动翻页）
   */
  async getFollowings(
    userId: number,
    restrict: 'public' | 'private' = 'public'
  ): Promise<UserPreview[]> {
    let nextUrl: string | null = '/v1/user/following';
    const allUsers: UserPreview[] = [];
    while (nextUrl) {
      const params =
        nextUrl === '/v1/user/following'
          ? { user_id: userId, restrict, filter: 'for_android' }
          : undefined;
      const response = await this.auth.axiosInstance.get(nextUrl, { params });
      const userPreviews = response.data.user_previews || [];
      allUsers.push(...userPreviews);
      nextUrl = response.data.next_url || null;
    }
    return allUsers;
  }

  /**
   * 用户 AI 显示设置
   */
  async getUserAISettings(): Promise<UserAISettingsResponse> {
    return this.fetchApi<UserAISettingsResponse>('/v1/user/ai-show-settings', undefined);
  }

  /**
   * 获取用户受限模式设置
   */
  async getUserRestrictedModeSettings(): Promise<UserRestrictedModeResponse> {
    return this.fetchApi<UserRestrictedModeResponse>(
      '/v1/user/restricted-mode-settings',
      undefined
    );
  }

  // ==============================
  // 评论模块
  // ==============================

  /**
   * 插画评论列表
   * 对应 Dart getIllustComments
   */
  async getIllustComments(
    illust_id: number,
    nextUrl?: string
  ): Promise<PixivCommentsResponse> {
    const data = await this.fetchApi<PixivCommentsResponse>(
      '/v3/illust/comments',
      { illust_id },
      nextUrl
    );
    return { comments: data.comments || [], next_url: data.next_url || null };
  }

  /**
   * 插画评论回复
   */
  async getIllustCommentReplies(
    comment_id: number,
    nextUrl?: string
  ): Promise<PixivCommentsResponse> {
    const data = await this.fetchApi<PixivCommentsResponse>(
      '/v2/illust/comment/replies',
      { comment_id },
      nextUrl
    );
    return { comments: data.comments || [], next_url: data.next_url || null };
  }

  // ==============================
  // 其他与发现
  // ==============================

  /**
   * 插画热门标签（旧接口名，保留兼容）
   */
  async getTrendingTags(): Promise<PixivTrendingTag[]> {
    const data = await this.fetchApi<{ trend_tags: PixivTrendingTag[] }>(
      '/v1/trending-tags/illust',
      { filter: 'for_android' }
    );
    return data.trend_tags || [];
  }

  /**
   * 亮点/专题文章
   */
  async getSpotlight(
    category: string = 'all',
    nextUrl?: string
  ): Promise<SpotlightResponse> {
    const params = { category, filter: 'for_android' };
    return this.fetchApi<SpotlightResponse>(
      '/v1/spotlight/articles',
      params,
      nextUrl
    );
  }

}
