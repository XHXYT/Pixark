import { PixivCommentsResponse, PixivIllust, PixivListResult, PixivTrendingTag, SearchFilterOptions, SearchUserResult, SpotlightResponse, UserDetailResponse, UserPreview } from './PixivTypes';
import { PixivAuth } from './PixivAuth';
import { createLogger } from '../common/utils/Logger';

const logger = createLogger('PixivData')

/**
 * 数据服务类
 * 处理各种数据获取接口：搜索、排行、推荐等
 */
export class PixivData {
  constructor(private auth: PixivAuth) {}

  /**
   * 通用 GET 请求封装 (自动处理 nextUrl 和初始参数)
   * 解决了之前每个接口都写一遍 if(nextUrl) 的重复代码
   */
  private async fetchApi<T>(initialUrl: string, initialParams: Record<string, any> | undefined, nextUrl?: string): Promise<T> {
    if (!this.auth.isLogin()) throw new Error('请先登录');
    const url = nextUrl || initialUrl;
    const params = nextUrl ? undefined : initialParams;
    const response = await this.auth.axiosInstance.get<T>(url, { params });
    return response.data;
  }

  // ==============================
  // 插画模块
  // ==============================

  async searchIllust(word: string, nextUrl?: string, options?: SearchFilterOptions): Promise<PixivListResult> {
    const params: Record<string, any> = {
      word, filter: 'for_android', sort: options?.sort || 'date_desc',
      search_target: options?.searchTarget || 'partial_match_for_tags',
    };
    if (options?.startDate) params.start_date = options.startDate;
    if (options?.endDate) params.end_date = options.endDate;
    if (options?.minBookmark && options.minBookmark > 0) params.bookmark_count_min = options.minBookmark;
    if (options?.aiType !== undefined) params.search_ai_type = options.aiType;

    const data = await this.fetchApi<any>('/v1/search/illust', params, nextUrl);
    return { illusts: data.illusts || [], next_url: data.next_url || null };
  }

  async getPopularPreview(keyword: string): Promise<PixivListResult> {
    const params = { word: keyword, filter: 'for_android', include_translated_tag_results: true, merge_plain_keyword_results: true, search_target: 'partial_match_for_tags' };
    const data = await this.fetchApi<any>('/v1/search/popular-preview/illust', params);
    return { illusts: data.illusts || [], next_url: data.next_url || null };
  }

  async getRanking(mode: string = 'day', date?: string, nextUrl?: string): Promise<PixivListResult> {
    const params = { mode, date, filter: 'for_android' };
    const data = await this.fetchApi<any>('/v1/illust/ranking', params, nextUrl);
    return { illusts: data.illusts || [], next_url: data.next_url || null };
  }

  async getRecommended(includeRanking: boolean = true, nextUrl?: string): Promise<PixivListResult> {
    const params = { filter: 'for_android', include_ranking_illusts: String(includeRanking) };
    const data = await this.fetchApi<any>('/v1/illust/recommended', params, nextUrl);
    return { illusts: data.illusts || [], next_url: data.next_url || null };
  }

  async getMangaRecommended(nextUrl?: string): Promise<PixivListResult> {
    const params = { filter: 'for_ios', include_ranking_label: true };
    const data = await this.fetchApi<any>('/v1/manga/recommended', params, nextUrl);
    return { illusts: data.illusts || [], next_url: data.next_url || null };
  }

  async getFollowIllusts(restrict: 'public' | 'private' = 'public', nextUrl?: string): Promise<PixivListResult> {
    const params = { restrict, filter: 'for_android' };
    const data = await this.fetchApi<any>('/v2/illust/follow', params, nextUrl);
    return { illusts: data.illusts || [], next_url: data.next_url || null };
  }

  async getIllustDetail(illust_id: number): Promise<PixivIllust> {
    const data = await this.fetchApi<any>('/v1/illust/detail', { illust_id, filter: 'for_android' });
    return data.illust;
  }

  async getRelatedIllusts(illust_id: number, nextUrl?: string): Promise<PixivListResult> {
    const params = { illust_id, filter: 'for_android' };
    const data = await this.fetchApi<any>('/v2/illust/related', params, nextUrl);
    return { illusts: data.illusts || [], next_url: data.next_url || null };
  }

  async getUgoiraMetadata(illust_id: number): Promise<any> {
    const data = await this.fetchApi<any>('/v1/ugoira/metadata', { illust_id });
    return data.ugoira_metadata;
  }

  async getIllustBookmarkDetail(illust_id: number): Promise<any> {
    const data = await this.fetchApi<any>('/v2/illust/bookmark/detail', { illust_id });
    return data.bookmark_detail;
  }

  async walkthroughIllusts(): Promise<PixivListResult> {
    const data = await this.fetchApi<any>('/v1/walkthrough/illusts', undefined);
    return { illusts: data.illusts || [], next_url: null };
  }

  // ==============================
  // 小说模块
  // ==============================

  async searchNovel(word: string, nextUrl?: string, options?: SearchFilterOptions): Promise<PixivListResult> {
    const params: Record<string, any> = {
      word, filter: 'for_android', merge_plain_keyword_results: true,
      sort: options?.sort || 'date_desc', search_target: options?.searchTarget || 'partial_match_for_tags',
    };
    if (options?.startDate) params.start_date = options.startDate;
    if (options?.endDate) params.end_date = options.endDate;
    if (options?.minBookmark) params.bookmark_num = options.minBookmark;

    const data = await this.fetchApi<any>('/v1/search/novel', params, nextUrl);
    return { novels: data.novels || [], next_url: data.next_url || null };
  }

  async getNovelRanking(mode: string, date?: string, nextUrl?: string): Promise<PixivListResult> {
    const params = { mode, date, filter: 'for_android' };
    const data = await this.fetchApi<any>('/v1/novel/ranking', params, nextUrl);
    return { novels: data.novels || [], next_url: data.next_url || null };
  }

  async getNovelRecommended(nextUrl?: string): Promise<PixivListResult> {
    const params = { include_privacy_policy: true, filter: 'for_android', include_ranking_novels: true };
    const data = await this.fetchApi<any>('/v1/novel/recommended', params, nextUrl);
    return { novels: data.novels || [], next_url: data.next_url || null };
  }

  async getNovelFollow(restrict: string, nextUrl?: string): Promise<PixivListResult> {
    const data = await this.fetchApi<any>('/v1/novel/follow', { restrict }, nextUrl);
    return { novels: data.novels || [], next_url: data.next_url || null };
  }

  async getNovelDetail(novel_id: number): Promise<any> {
    const data = await this.fetchApi<any>('/v2/novel/detail', { novel_id });
    return data.novel;
  }

  async getNovelText(novel_id: number): Promise<any> {
    const data = await this.fetchApi<any>('/v1/novel/text', { novel_id });
    return data.novel_text;
  }

  async getUserNovels(userId: number, nextUrl?: string): Promise<PixivListResult> {
    const params = { user_id: userId, filter: 'for_android' };
    const data = await this.fetchApi<any>('/v1/user/novels', params, nextUrl);
    return { novels: data.novels || [], next_url: data.next_url || null };
  }

  async getNovelTrendTags(): Promise<PixivTrendingTag[]> {
    const data = await this.fetchApi<any>('/v1/trending-tags/novel', { filter: 'for_android' });
    return data.trend_tags || [];
  }

  async getNovelComments(novel_id: number, nextUrl?: string): Promise<PixivCommentsResponse> {
    const data = await this.fetchApi<any>('/v3/novel/comments', { novel_id }, nextUrl);
    return { comments: data.comments || [], next_url: data.next_url || null };
  }

  async getNovelCommentsReplies(comment_id: number, nextUrl?: string): Promise<PixivCommentsResponse> {
    const data = await this.fetchApi<any>('/v2/novel/comment/replies', { comment_id }, nextUrl);
    return { comments: data.comments || [], next_url: data.next_url || null };
  }

  async novelSeries(series_id: number): Promise<any> {
    return this.fetchApi<any>('/v2/novel/series', { series_id });
  }

  // ==============================
  // 用户模块
  // ==============================

  async searchUser(word: string, nextUrl?: string): Promise<SearchUserResult> {
    const params = { word, filter: 'for_android' };
    const data = await this.fetchApi<any>('/v1/search/user', params, nextUrl);
    return { user_previews: data.user_previews || [], next_url: data.next_url || null };
  }

  async getUserRecommended(nextUrl?: string): Promise<SearchUserResult> {
    const params = { filter: 'for_android' };
    const data = await this.fetchApi<any>('/v1/user/recommended', params, nextUrl);
    return { user_previews: data.user_previews || [], next_url: data.next_url || null };
  }

  async getUserDetail(userId: number): Promise<UserDetailResponse> {
    return this.fetchApi<UserDetailResponse>('/v1/user/detail', { user_id: userId, filter: 'for_android' });
  }

  async getUserIllusts(userId: number, type: 'illust' | 'manga' = 'illust', nextUrl?: string): Promise<PixivListResult> {
    const params = { user_id: userId, type, filter: 'for_android' };
    const data = await this.fetchApi<any>('/v1/user/illusts', params, nextUrl);
    return { illusts: data.illusts || [], next_url: data.next_url || null };
  }

  async getUserBookmarks(userId: number, restrict: 'public' | 'private' = 'public', tag?: string, maxBookmarkId?: number, nextUrl?: string): Promise<PixivListResult> {
    const params: Record<string, any> = { user_id: userId, restrict, tag, max_bookmark_id: maxBookmarkId, filter: 'for_android' };
    const data = await this.fetchApi<any>('/v1/user/bookmarks/illust', params, nextUrl);
    return { illusts: data.illusts || [], next_url: data.next_url || null };
  }

  async getUserBookmarkNovel(userId: number, restrict: string, nextUrl?: string): Promise<PixivListResult> {
    const params = { user_id: userId, restrict, filter: 'for_android' };
    const data = await this.fetchApi<any>('/v1/user/bookmarks/novel', params, nextUrl);
    return { illusts: data.novels || [], next_url: data.next_url || null };
  }

  async getUserBookmarkTagsIllust(userId: number, restrict: string = 'public'): Promise<any> {
    const data = await this.fetchApi<any>('/v1/user/bookmark-tags/illust', { user_id: userId, restrict });
    return data.bookmark_tags || [];
  }

  async getUserFollowing(userId: number, restrict: 'public' | 'private' = 'public', nextUrl?: string): Promise<SearchUserResult> {
    const params = { user_id: userId, restrict, filter: 'for_android' };
    const data = await this.fetchApi<any>('/v1/user/following', params, nextUrl);
    return { user_previews: data.user_previews || [], next_url: data.next_url || null };
  }

  async getFollowUser(userId: number, restrict: 'public' | 'private' = 'public', nextUrl?: string): Promise<SearchUserResult> {
    const params = { user_id: userId, restrict, filter: 'for_android' };
    const data = await this.fetchApi<any>('/v1/user/follower', params, nextUrl);
    return { user_previews: data.user_previews || [], next_url: data.next_url || null };
  }

  async getUserFollowDetail(userId: number): Promise<any> {
    const data = await this.fetchApi<any>('/v1/user/follow/detail', { user_id: userId });
    return data.follow_detail;
  }

  async getFollowings(userId: number, restrict: 'public' | 'private' = 'public'): Promise<UserPreview[]> {
    let nextUrl: string | null = '/v1/user/following';
    const allUsers: UserPreview[] = [];
    while (nextUrl) {
      const params = nextUrl === '/v1/user/following' ? { user_id: userId, restrict, filter: 'for_android' } : undefined;
      const response = await this.auth.axiosInstance.get(nextUrl, { params });
      const userPreviews = response.data.user_previews || [];
      allUsers.push(...userPreviews);
      nextUrl = response.data.next_url || null;
    }
    return allUsers;
  }

  // ==============================
  // 评论模块
  // ==============================

  async getIllustComments(illust_id: number, nextUrl?: string): Promise<PixivCommentsResponse> {
    const data = await this.fetchApi<any>('/v3/illust/comments', { illust_id }, nextUrl);
    return { comments: data.comments || [], next_url: data.next_url || null };
  }

  async getIllustCommentReplies(comment_id: number, nextUrl?: string): Promise<PixivCommentsResponse> {
    const data = await this.fetchApi<any>('/v2/illust/comment/replies', { comment_id }, nextUrl);
    return { comments: data.comments || [], next_url: data.next_url || null };
  }

  // ==============================
  // 其他与发现
  // ==============================

  async getTrendingTags(): Promise<PixivTrendingTag[]> {
    const data = await this.fetchApi<any>('/v1/trending-tags/illust', { filter: 'for_android' });
    return data.trend_tags || [];
  }

  async getSpotlight(category: string = 'all', nextUrl?: string): Promise<SpotlightResponse> {
    const params = { category, filter: 'for_android' };
    return this.fetchApi<SpotlightResponse>('/v1/spotlight/articles', params, nextUrl);
  }

}
