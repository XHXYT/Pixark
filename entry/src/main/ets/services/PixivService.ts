import { PixivAuth } from './PixivAuth';
import { PixivData } from './PixivData';
import { PixivInteraction } from './PixivInteraction';
import {
  AccountContext,
  PixivCommentsResponse,
  PixivIllust,
  PixivListResult,
  PixivUser,
  SearchFilterOptions,
  SearchUserResult,
  SpotlightResponse,
  UserDetailResponse,
  UserPreview
} from './PixivTypes';

/**
 * Pixiv 服务主入口
 * 组合了认证服务、数据服务和交互服务，对外提供统一的调用接口
 */
export class PixivService {
  private auth: PixivAuth;
  private data: PixivData;
  private interaction: PixivInteraction;

  constructor() {
    this.auth = new PixivAuth();
    this.data = new PixivData(this.auth);
    this.interaction = new PixivInteraction(this.auth);
  }

  // --- 认证方法 ---
  /** 检查当前是否已登录且 Token 有效 */
  isLogin(): boolean {
    return this.auth.isLogin();
  }

  /** 使用 Web OAuth 授权码进行登录 */
  async loginWithAuthCode(code: string, codeVerifier: string): Promise<AccountContext> {
    return this.auth.loginWithAuthCode(code, codeVerifier);
  }

  /** 使用 Refresh Token 进行登录刷新会话 */
  async loginWithRefreshToken(refreshToken: string): Promise<AccountContext> {
    return this.auth.loginWithRefreshToken(refreshToken);
  }

  /** 刷新当前激活账号的 Access Token */
  async refreshAuthToken(): Promise<AccountContext> {
    return this.auth.loginWithRefreshToken(this.auth.getCurrentRefreshToken());
  }

  /** 加载并激活指定的 Refresh Token */
  async loadRefreshToken(refreshToken: string): Promise<void> {
    await this.auth.loginWithRefreshToken(refreshToken);
  }

  /** 修改账户信息 (邮箱/密码) */
  async editAccount(currentPassword: string, newMailAddress?: string, newPassword?: string): Promise<boolean> {
    return this.auth.editAccount(currentPassword, newMailAddress, newPassword);
  }

  /** 获取当前保存的 Refresh Token */
  getCurrentRefreshToken(): string {
    return this.auth.getCurrentRefreshToken();
  }

  /** 获取当前登录用户信息 */
  getCurrentUser(): PixivUser {
    return this.auth.getCurrentUser();
  }


  // --- 多账号管理方法 ---
  /** 获取当前所有账号列表 */
  getAllAccounts(): AccountContext[] {
    return this.auth.getAllAccounts();
  }

  /** 更新指定账号的用户信息 */
  updateAccountUser(userId: string, updatedUser: PixivUser) {
    return this.auth.updateAccountUser(userId, updatedUser)
  }

  /** 切换当前激活账号 */
  switchAccount(userId: string) {
    this.auth.switchAccount(userId);
  }

  /** 登出并移除特定账号 */
  removeAccount(userId: string) {
    this.auth.removeAccount(userId);
  }

  /** 初始化账号数据 App启动时调用 */
  initAccounts(accounts: AccountContext[], activeId?: string) {
    this.auth.initAccounts(accounts, activeId);
  }

  /** 获取当前激活的账号上下文 */
  getActiveAccount(): AccountContext | undefined {
    return this.auth.getActiveAccount();
  }


  // --- 数据接口方法 ---

  /** 搜索插画 */
  async searchIllust(word: string, nextUrl?: string, options?: SearchFilterOptions): Promise<PixivListResult> {
    return this.data.searchIllust(word, nextUrl, options);
  }

  /** 获取搜索热门预览 */
  async getPopularPreview(keyword: string): Promise<PixivListResult> {
    return this.data.getPopularPreview(keyword);
  }

  /** 获取排行榜 */
  async getRanking(mode: string = 'day', date?: string, nextUrl?: string): Promise<PixivListResult> {
    return this.data.getRanking(mode, date, nextUrl);
  }

  /** 获取个性化推荐 */
  async getRecommended(includeRanking: boolean = true, url?: string): Promise<PixivListResult> {
    return this.data.getRecommended(includeRanking, url);
  }

  /** 获取漫画推荐 */
  async getMangaRecommended(nextUrl?: string): Promise<PixivListResult> {
    return this.data.getMangaRecommended(nextUrl);
  }

  /** 获取作品详情 */
  async getIllustDetail(illust_id: number): Promise<PixivIllust> {
    return this.data.getIllustDetail(illust_id);
  }

  /** 获取相关推荐作品 */
  async getRelatedIllusts(illust_id: number, nextUrl?: string): Promise<PixivListResult> {
    return this.data.getRelatedIllusts(illust_id, nextUrl);
  }

  /**
   * 获取关注用户的新作品 (即"动态"页)
   */
  async getFollowingIllusts(restrict: 'public' | 'private' = 'public', nextUrl?: string): Promise<PixivListResult> {
    return this.data.getFollowIllusts(restrict, nextUrl);
  }

  /** 获取动图元数据 */
  async getUgoiraMetadata(illust_id: number): Promise<any> {
    return this.data.getUgoiraMetadata(illust_id);
  }

  /** 获取收藏详情含系统推荐标签 */
  async getIllustBookmarkDetail(illust_id: number): Promise<any> {
    return this.data.getIllustBookmarkDetail(illust_id);
  }

  /** 获取新手引导插画 */
  async walkthroughIllusts(): Promise<PixivListResult> {
    return this.data.walkthroughIllusts();
  }


  /** 搜索小说 */
  async searchNovel(word: string, nextUrl?: string, options?: SearchFilterOptions): Promise<PixivListResult> {
    return this.data.searchNovel(word, nextUrl, options);
  }

  /** 获取小说排行榜 */
  async getNovelRanking(mode: string, date?: string, nextUrl?: string): Promise<PixivListResult> {
    return this.data.getNovelRanking(mode, date, nextUrl);
  }

  /** 获取小说推荐 */
  async getNovelRecommended(nextUrl?: string): Promise<PixivListResult> {
    return this.data.getNovelRecommended(nextUrl);
  }

  /** 获取关注用户的小说动态 */
  async getNovelFollow(restrict: string, nextUrl?: string): Promise<PixivListResult> {
    return this.data.getNovelFollow(restrict, nextUrl);
  }

  /** 获取小说详情 */
  async getNovelDetail(novel_id: number): Promise<any> {
    return this.data.getNovelDetail(novel_id);
  }

  /** 获取小说正文 */
  async getNovelText(novel_id: number): Promise<any> {
    return this.data.getNovelText(novel_id);
  }

  /** 获取用户的小说列表 */
  async getUserNovels(userId: number, nextUrl?: string): Promise<PixivListResult> {
    return this.data.getUserNovels(userId, nextUrl);
  }

  /** 获取小说热门标签 */
  async getNovelTrendTags(): Promise<any> {
    return this.data.getNovelTrendTags();
  }

  /** 获取小说评论 */
  async getNovelComments(novel_id: number, nextUrl?: string): Promise<PixivCommentsResponse> {
    return this.data.getNovelComments(novel_id, nextUrl);
  }

  /** 获取小说评论回复 */
  async getNovelCommentsReplies(comment_id: number, nextUrl?: string): Promise<PixivCommentsResponse> {
    return this.data.getNovelCommentsReplies(comment_id, nextUrl);
  }

  /** 获取小说系列 */
  async novelSeries(series_id: number): Promise<any> {
    return this.data.novelSeries(series_id);
  }


  /** 搜索用户 */
  async searchUser(word: string, nextUrl?: string): Promise<SearchUserResult> {
    return this.data.searchUser(word, nextUrl);
  }

  /** 获取推荐用户 */
  async getUserRecommended(nextUrl?: string): Promise<SearchUserResult> {
    return this.data.getUserRecommended(nextUrl);
  }

  /** 获取用户详细信息 */
  async getUserDetail(userId: number): Promise<UserDetailResponse> {
    return this.data.getUserDetail(userId);
  }

  /** 获取用户的作品列表 */
  async getUserIllusts(userId: number, type: 'illust' | 'manga' = 'illust',
    nextUrl?: string): Promise<PixivListResult> {
    return this.data.getUserIllusts(userId, type, nextUrl);
  }

  /** 获取用户的收藏列表 */
  async getUserBookmarks(userId: number, restrict: 'public' | 'private' = 'public', tag?: string,
    maxBookmarkId?: number, nextUrl?: string): Promise<PixivListResult> {
    return this.data.getUserBookmarks(userId, restrict, tag, maxBookmarkId, nextUrl);
  }

  /** 获取用户收藏的小说 */
  async getUserBookmarkNovel(userId: number, restrict: string, nextUrl?: string): Promise<PixivListResult> {
    return this.data.getUserBookmarkNovel(userId, restrict, nextUrl);
  }

  /** 获取用户插画收藏标签 */
  async getUserBookmarkTagsIllust(userId: number, restrict: string = 'public'): Promise<any> {
    return this.data.getUserBookmarkTagsIllust(userId, restrict);
  }

  /** 获取关注的用户列表 */
  async getUserFollowing(userId: number, restrict: 'public' | 'private' = 'public',
    nextUrl?: string): Promise<SearchUserResult> {
    return this.data.getUserFollowing(userId, restrict, nextUrl);
  }

  /** 获取粉丝列表 */
  async getFollowUser(userId: number, restrict: 'public' | 'private' = 'public',
    nextUrl?: string): Promise<SearchUserResult> {
    return this.data.getFollowUser(userId, restrict, nextUrl);
  }

  /** 获取与指定用户的关系详情 */
  async getUserFollowDetail(userId: number): Promise<any> {
    return this.data.getUserFollowDetail(userId);
  }

  /** 同步获取当前用户关注的所有用户 */
  async syncFollowingStatus(userId: number, restrict: 'public' | 'private' = 'public'): Promise<UserPreview[]> {
    return this.data.getFollowings(userId, restrict);
  }


  /** 获取插画评论 */
  async getIllustComments(illust_id: number, nextUrl?: string): Promise<PixivCommentsResponse> {
    return this.data.getIllustComments(illust_id, nextUrl);
  }

  /** 获取插画评论回复 */
  async getIllustCommentReplies(comment_id: number, nextUrl?: string): Promise<PixivCommentsResponse> {
    return this.data.getIllustCommentReplies(comment_id, nextUrl);
  }

  /** 获取热门标签 */
  async getTrendingTags() {
    return this.data.getTrendingTags()
  }

  /** 获取 Pixiv 亮点或专题文章列表 */
  async getSpotlight(category: string = 'all'): Promise<SpotlightResponse> {
    return this.data.getSpotlight(category)
  }


  // --- 用户交互方法 ---
  /** 关注用户 */
  async followUser(userId: number, restrict: 'public' | 'private' = 'public') {
    return this.interaction.followUser(userId, restrict);
  }

  /** 取消关注用户 */
  async unfollowUser(userId: number, restrict: 'public' | 'private' = 'public') {
    return this.interaction.unfollowUser(userId, restrict);
  }

  /** 收藏插画 */
  async addBookmark(illust_id: number, restrict: 'public' | 'private' = 'public', tags: string[] = []) {
    return this.interaction.addBookmark(illust_id, restrict, tags);
  }

  /** 取消收藏插画 */
  async deleteBookmark(illust_id: number) {
    return this.interaction.deleteBookmark(illust_id);
  }

  /** 收藏小说 */
  async addNovelBookmark(novel_id: number, restrict: 'public' | 'private' = 'public') {
    return this.interaction.addNovelBookmark(novel_id, restrict);
  }

  /** 取消收藏小说 */
  async deleteNovelBookmark(novel_id: number) {
    return this.interaction.deleteNovelBookmark(novel_id);
  }

  /** 发表插画评论 */
  async addIllustComment(illust_id: number, comment: string, parent_comment_id?: number) {
    return this.interaction.addIllustComment(illust_id, comment, parent_comment_id);
  }

  /** 删除插画评论 */
  async deleteIllustComment(comment_id: number) {
    return this.interaction.deleteIllustComment(comment_id);
  }

  /** 发表小说评论 */
  async addNovelComment(novel_id: number, comment: string, parent_comment_id?: number) {
    return this.interaction.addNovelComment(novel_id, comment, parent_comment_id);
  }

  /** 删除小说评论 */
  async deleteNovelComment(comment_id: number) {
    return this.interaction.deleteNovelComment(comment_id);
  }

  /** 设置 AI 作品显示偏好 */
  async postUserAIShowSettings(show: boolean) {
    return this.interaction.postUserAIShowSettings(show);
  }

  /** 设置受限模式 */
  async postUserRestrictedModeSettings(isRestrictedModeEnabled: boolean) {
    return this.interaction.postUserRestrictedModeSettings(isRestrictedModeEnabled);
  }

}

export const pixiv: PixivService = new PixivService()
