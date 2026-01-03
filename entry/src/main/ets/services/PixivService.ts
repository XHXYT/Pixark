import { PixivAuth } from './PixivAuth';
import { PixivData } from './PixivData';
import { PixivInteraction } from './PixivInteraction';
import { PixivAuthResponse, PixivIllust, PixivListResult, SpotlightResponse } from './PixivTypes';

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

  // 已废弃
  async loginWithPassword(username: string, password: string): Promise<PixivAuthResponse> {
    return this.auth.loginWithPassword(username, password);
  }

  async loginWithAuthCode(code: string, codeVerifier: string): Promise<PixivAuthResponse> {
		return this.auth.loginWithAuthCode(code, codeVerifier);
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

  async searchIllust(word: string, page: number = 1, pageSize: number = 30): Promise<PixivListResult> {
    return this.data.searchIllust(word, page, pageSize);
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

  async getRecommended(includeRanking: boolean = true): Promise<PixivListResult> {
    return this.data.getRecommended(includeRanking);
  }

  async getIllustDetail(illustId: number): Promise<PixivIllust> {
    return this.data.getIllustDetail(illustId);
  }

  async getUserIllusts(userId: number, type: 'illust' | 'manga' = 'illust'): Promise<PixivListResult> {
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
  async loadNextPage(nextUrl: string): Promise<PixivListResult> {
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

