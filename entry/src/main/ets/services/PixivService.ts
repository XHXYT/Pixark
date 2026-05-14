import { PixivAuth } from './PixivAuth';
import { PixivData } from './PixivData';
import { PixivInteraction } from './PixivInteraction';
import {
  AccountContext,
  PixivIllust, PixivListResult,
  PixivUser,
  SearchFilterOptions,
  SearchUserResult, SpotlightResponse,
  UserDetailResponse,
  UserPreview } from './PixivTypes';

/**
 * Pixiv 服务主入口
 * 组合了认证服务 和 数据服务
 * 对外提供统一的调用接口
 */
export class PixivService {
  private auth: PixivAuth; // 登录认证
  private data: PixivData; // 数据读取
  private interaction: PixivInteraction; // 用户交互

  constructor() {
    // 初始化 Auth、 Data、 interaction
    this.auth = new PixivAuth();
    this.data = new PixivData(this.auth);
    this.interaction = new PixivInteraction(this.auth);
  }

  // --- 认证方法 ---
  isLogin(): boolean {
    return this.auth.isLogin();
  }

  async loginWithAuthCode(code: string, codeVerifier: string): Promise<AccountContext> {
    return this.auth.loginWithAuthCode(code, codeVerifier);
  }

  async loginWithRefreshToken(refreshToken: string): Promise<AccountContext> {
    return this.auth.loginWithRefreshToken(refreshToken);
  }

  async refreshAuthToken(): Promise<AccountContext> {
    const token = this.auth.getCurrentRefreshToken();
    return this.auth.loginWithRefreshToken(token);
  }

  async loadRefreshToken(refreshToken: string): Promise<void> {
    await this.auth.loginWithRefreshToken(refreshToken);
  }

  async editAccount(currentPassword: string, newMailAddress?: string, newPassword?: string): Promise<boolean> {
    return this.auth.editAccount(currentPassword, newMailAddress, newPassword);
  }

  getCurrentRefreshToken(): string {
    return this.auth.getCurrentRefreshToken();
  }

  getCurrentUser(): PixivUser {
    return this.auth.getCurrentUser();
  }


  // --- 多账号管理方法 ---
  getAllAccounts(): AccountContext[] {
    return this.auth.getAllAccounts();
  }

  updateAccountUser(userId: string, updatedUser: PixivUser) {
    return this.auth.updateAccountUser(userId, updatedUser)
  }

  switchAccount(userId: string) {
    this.auth.switchAccount(userId);
  }

  removeAccount(userId: string) {
    this.auth.removeAccount(userId);
  }

  initAccounts(accounts: AccountContext[], activeId?: string) {
    this.auth.initAccounts(accounts, activeId);
  }

  getActiveAccount(): AccountContext | undefined {
    return this.auth.getActiveAccount();
  }

  // --- 数据接口方法 ---
  /**
   * 搜索插画
   * @param word 搜索关键词
   * @param nextUrl 可选，用于翻页
   * @param options 搜索配置
   * @returns 返回搜索结果列表
   */
  async searchIllust(word: string, nextUrl?: string, options?: SearchFilterOptions): Promise<PixivListResult> {
    return this.data.searchIllust(word, nextUrl, options);
  }

  /**
   * 搜索用户（画师）
   * @param word 搜索词（作者名 / 账号名）
   * @param nextUrl 可选，用于翻页
   */
  async searchUser(word: string, nextUrl?: string): Promise<SearchUserResult> {
    return this.data.searchUser(word, nextUrl);
  }

  /**
   * 获取当前用户关注的所有用户 ID
   * @param restrict 'public' | 'private'，默认 'public'
   * @returns 返回 用户预览 的数组集合
   */
  async syncFollowingStatus(userId: number, restrict: 'public' | 'private' = 'public'): Promise<UserPreview[]> {
    try {
      const users = await this.data.getFollowings(userId, restrict);
      return users;
    } catch (e) {
      console.error('Get following users failed', e);
      throw e;
    }
  }

  /**
   * 获取热门标签（用于搜索页推荐）
   * @returns 返回热门标签列表
   */
  async getTrendingTags() {
    return this.data.getTrendingTags()
  }

  async getRanking(mode: string = 'day', date?: string): Promise<PixivListResult> {
    return this.data.getRanking(mode, date);
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
    return this.data.getSpotlight(category)
  }

  async getRecommended(includeRanking: boolean = true, url?: string): Promise<PixivListResult> {
    return this.data.getRecommended(includeRanking, url);
  }

  async getIllustDetail(illust_id: number): Promise<PixivIllust> {
    return this.data.getIllustDetail(illust_id);
  }

  async getRelatedIllusts(illust_id: number): Promise<PixivListResult> {
    return this.data.getRelatedIllusts(illust_id);
  }

  /**
   * 获取用户详细信息
   * @param userId 用户 ID
   * @returns 返回用户详细数据（含头像、背景、简介、统计等）
   */
  async getUserDetail(userId: number): Promise<UserDetailResponse> {
    return this.data.getUserDetail(userId);
  }

  async getUserIllusts(userId: number, type: 'illust' | 'manga' = 'illust', nextUrl?: string): Promise<PixivListResult> {
    return this.data.getUserIllusts(userId, type, nextUrl);
  }

  /**
   * 获取指定用户的收藏列表
   * @param userId 目标用户的 ID
   * @param restrict 收藏的类型
   * @param tag 用于过滤收藏的标签
   * @param maxBookmarkId 分页参数
   * @param nextUrl 下一页链接(可选)
   */
  async getUserBookmarks(
    userId: number,
    restrict: 'public' | 'private' = 'public',
    tag?: string,
    maxBookmarkId?: number,
    nextUrl?: string
  ) {
    return this.data.getUserBookmarks(userId, restrict, tag, maxBookmarkId, nextUrl);
  }

  /**
   * 获取关注用户的新作品 (即"动态"页)
   * @param restrict 'public' | 'private'，默认 'public' (通常仅公开作品会进入动态流)
   * @param nextUrl 翻页参数
   */
  async getFollowingIllusts(restrict: 'public' | 'private' = 'public', nextUrl?: string): Promise<PixivListResult> {
    return this.data.getFollowIllusts(restrict, nextUrl);
  }

  /**
   * 获取关注的用户列表 (支持分页)
   * @param userId 用户 ID
   * @param restrict 'public' | 'private'，默认 'public'
   * @param nextUrl 翻页参数
   */
  async getUserFollowing(userId: number, restrict: 'public' | 'private' = 'public', nextUrl?: string): Promise<SearchUserResult> {
    return this.data.getUserFollowing(userId, restrict, nextUrl);
  }


  // --- 用户交互方法  ---
  /**
   * 关注用户
   */
  async followUser(userId: number, restrict: 'public' | 'private' = 'public') {
    return this.interaction.followUser(userId, restrict);
  }

  /**
   * 取消关注用户
   */
  async unfollowUser(userId: number, restrict: 'public' | 'private' = 'public') {
    return this.interaction.unfollowUser(userId, restrict);
  }

  /**
   * 收藏插画
   */
  async addBookmark(illust_id: number, restrict: 'public' | 'private' = 'public', tags: string[] = []) {
    return this.interaction.addBookmark(illust_id, restrict, tags);
  }

  /**
   * 取消收藏插画
   */
  async deleteBookmark(illust_id: number) {
    return this.interaction.deleteBookmark(illust_id);
  }

}

export const pixiv: PixivService = new PixivService()

