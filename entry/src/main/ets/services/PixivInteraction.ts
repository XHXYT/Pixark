import { PixivAuth } from './PixivAuth';
import { createLogger } from '../common/utils/Logger';
import { UrlUtils } from '../common/utils/UrlUtils';

const logger = createLogger('PixivInteraction')

/**
 * 用户交互服务类
 * 处理用户的主动行为：关注、取消关注、收藏、取消收藏、评论等写操作
 */
export class PixivInteraction {
  constructor(private auth: PixivAuth) {}

  /**
   * 通用 POST 表单请求封装
   * 解决了之前每个 POST 都写一遍 headers 和 encodeQuery 的问题
   */
  private async postForm(url: string, params: Record<string, any>): Promise<void> {
    if (!this.auth.isLogin()) throw new Error('请先登录');
    await this.auth.axiosInstance.post(url, UrlUtils.encodeQuery(params), {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    });
  }

  // ==============================
  // 关注模块
  // ==============================

  async followUser(userId: number, restrict: 'public' | 'private' = 'public'): Promise<void> {
    logger.info(`Following user: ${userId}`);
    await this.postForm('/v1/user/follow/add', { user_id: userId, restrict });
  }

  async unfollowUser(userId: number, restrict: 'public' | 'private' = 'public'): Promise<void> {
    logger.info(`Unfollowing user: ${userId}`);
    await this.postForm('/v1/user/follow/delete', { user_id: userId, restrict });
  }

  // ==============================
  // 插画收藏模块
  // ==============================

  async addBookmark(illust_id: number, restrict: 'public' | 'private' = 'public', tags: string[] = []): Promise<void> {
    logger.info(`Adding bookmark: ${illust_id}`);
    const params: Record<string, any> = { illust_id, restrict };
    if (tags.length > 0) params.tags = tags.join(' ');
    await this.postForm('/v2/illust/bookmark/add', params);
  }

  async deleteBookmark(illust_id: number): Promise<void> {
    logger.info(`Deleting bookmark: ${illust_id}`);
    await this.postForm('/v1/illust/bookmark/delete', { illust_id });
  }

  // ==============================
  // 小说收藏模块
  // ==============================

  async addNovelBookmark(novel_id: number, restrict: 'public' | 'private' = 'public'): Promise<void> {
    logger.info(`Adding novel bookmark: ${novel_id}`);
    await this.postForm('/v2/novel/bookmark/add', { novel_id, restrict });
  }

  async deleteNovelBookmark(novel_id: number): Promise<void> {
    logger.info(`Deleting novel bookmark: ${novel_id}`);
    await this.postForm('/v1/novel/bookmark/delete', { novel_id });
  }

  // ==============================
  // 插画评论模块
  // ==============================

  async addIllustComment(illust_id: number, comment: string, parent_comment_id?: number): Promise<void> {
    logger.info(`Adding comment to illust: ${illust_id}`);
    await this.postForm('/v1/illust/comment/add', { illust_id, comment, parent_comment_id });
  }

  async deleteIllustComment(comment_id: number): Promise<void> {
    logger.info(`Deleting illust comment: ${comment_id}`);
    await this.postForm('/v1/illust/comment/delete', { comment_id });
  }

  // ==============================
  // 小说评论模块
  // ==============================

  async addNovelComment(novel_id: number, comment: string, parent_comment_id?: number): Promise<void> {
    logger.info(`Adding comment to novel: ${novel_id}`);
    await this.postForm('/v1/novel/comment/add', { novel_id, comment, parent_comment_id });
  }

  async deleteNovelComment(comment_id: number): Promise<void> {
    logger.info(`Deleting novel comment: ${comment_id}`);
    await this.postForm('/v1/novel/comment/delete', { comment_id });
  }

  // ==============================
  // 用户设置模块
  // ==============================

  async postUserAIShowSettings(show: boolean): Promise<void> {
    logger.info(`Setting AI show: ${show}`);
    await this.postForm('/v1/user/ai-show-settings/edit', { show_ai: show });
  }

  async postUserRestrictedModeSettings(isRestrictedModeEnabled: boolean): Promise<void> {
    logger.info(`Setting restricted mode: ${isRestrictedModeEnabled}`);
    await this.postForm('/v1/user/restricted-mode-settings', { is_restricted_mode_enabled: isRestrictedModeEnabled });
  }

}
