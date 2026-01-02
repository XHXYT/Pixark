import { PixivAuth } from './PixivAuth';
import { PixivData } from './PixivData';
import { PixivInteraction } from './PixivInteraction';
import { PixivAuthResponse, PixivIllust, PixivSearchResult } from './PixivTypes';

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

  async loginWithPassword(username: string, password: string): Promise<PixivAuthResponse> {
    return this.auth.loginWithPassword(username, password);
  }

  async loginWithRefreshToken(refreshToken: string): Promise<PixivAuthResponse> {
    return this.auth.loginWithRefreshToken(refreshToken);
  }

  async refreshAuthToken(): Promise<PixivAuthResponse> {
    const token = this.auth.getCurrentRefreshToken();
    return this.auth.loginWithRefreshToken(token);
  }

  getCurrentRefreshToken(): string {
    return this.auth.getCurrentRefreshToken();
  }

  async loadRefreshToken(refreshToken: string): Promise<void> {
    await this.auth.loginWithRefreshToken(refreshToken);
  }


  // --- 数据接口方法 ---

  async searchIllust(word: string, page: number = 1, pageSize: number = 30): Promise<PixivSearchResult> {
    return this.data.searchIllust(word, page, pageSize);
  }

  async getRanking(mode: string = 'day', date?: string): Promise<PixivSearchResult> {
    return this.data.getRanking(mode, date);
  }

  async getRecommended(includeRanking: boolean = true): Promise<PixivSearchResult> {
    return this.data.getRecommended(includeRanking);
  }

  async getIllustDetail(illustId: number): Promise<PixivIllust> {
    return this.data.getIllustDetail(illustId);
  }

  async getUserIllusts(userId: number, type: 'illust' | 'manga' = 'illust'): Promise<PixivSearchResult> {
    return this.data.getUserIllusts(userId, type);
  }

  /**
   * 获取指定用户的收藏列表
   * @param userId 目标用户的 ID
   * @param restrict 收藏的类型
   * @param tag 用于过滤收藏的标签
   * @param maxBookmarkId 分页参数
   */
  async getUserBookmarks(userId: number, restrict: 'public' | 'private' = 'public', tag?: string, maxBookmarkId?: number) {
    return this.data.getUserBookmarks(userId, restrict, tag, maxBookmarkId);
  }

  /**
   * 使用 next_url 加载下一页（通用）
   */
  async loadNextPage(nextUrl: string): Promise<PixivSearchResult> {
    return this.data.loadNextPage(nextUrl);
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
  async addBookmark(illustId: number, restrict: 'public' | 'private' = 'public', tags: string[] = []) {
    return this.interaction.addBookmark(illustId, restrict, tags);
  }

  /**
   * 取消收藏插画
   */
  async deleteBookmark(illustId: number) {
    return this.interaction.deleteBookmark(illustId);
  }

}

