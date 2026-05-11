import { PixivAuth } from './PixivAuth';
import { urlQueryString } from '../common/utils/Url2String';
import { createLogger } from '../common/utils/Logger';

const logger = createLogger('PixivInteraction')

/**
 * 用户交互服务类
 * 处理用户的主动行为：关注、取消关注、收藏、取消收藏等写操作
 */
export class PixivInteraction {
  constructor(private auth: PixivAuth) {}

  // ==============================
  // 关注模块
  // ==============================

  /**
   * 关注用户
   * @param userId 目标用户 ID
   * @param restrict 关注类型：'public' (公开) 或 'private' (私密)
   */
  async followUser(
    userId: number,
    restrict: 'public' | 'private' = 'public'
  ): Promise<void> {
    if (!this.auth.isLogin()) {
      throw new Error('请先登录');
    }
    logger.info(`Following user: ${userId}`);
    try {
      await this.auth.axiosInstance.post(
        '/v1/user/follow/add',
        urlQueryString({
          user_id: userId,
          restrict: restrict,
        }),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        }
      );
    } catch (error: any) {
      logger.error(`Follow failed: ` + JSON.stringify(error));
      throw error;
    }
  }

  /**
   * 取消关注用户
   * @param userId 目标用户 ID
   * @param restrict 类型必须与当初关注时一致
   */
  async unfollowUser(
    userId: number,
    restrict: 'public' | 'private' = 'public'
  ): Promise<void> {
    if (!this.auth.isLogin()) {
      throw new Error('请先登录');
    }
    logger.info(`Unfollowing user: ${userId}`);
    try {
      await this.auth.axiosInstance.post(
        '/v1/user/follow/delete',
        urlQueryString({
          user_id: userId,
          restrict: restrict,
        }),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        }
      );
    } catch (error: any) {
      logger.error(`Unfollow failed: ` + JSON.stringify(error));
      throw error;
    }
  }

  // ==============================
  // 收藏模块
  // ==============================

  /**
   * 收藏插画
   * @param illust_id 作品 ID
   * @param restrict 收藏类型：'public' (公开收藏) 或 'private' (私密收藏)
   * @param tags 可选：自定义标签数组，最多 10 个
   */
  async addBookmark(
    illust_id: number,
    restrict: 'public' | 'private' = 'public',
    tags: string[] = []
  ): Promise<void> {
    if (!this.auth.isLogin()) {
      throw new Error('请先登录');
    }
    logger.info(`[PixivInteraction] Adding bookmark: ${illust_id}`);
    const params: Record<string, string | number> = {
      illust_id: illust_id,
      restrict: restrict,
    };
    // 如果有标签，将数组转换为用空格分隔的字符串
    // Pixiv API 接收格式如: tags=R18 原创标签1 标签2
    if (tags.length > 0) {
      params['tags'] = tags.join(' ');
    }
    try {
      await this.auth.axiosInstance.post(
        '/v2/illust/bookmark/add',
        urlQueryString(params),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        }
      );
      logger.info(`Bookmark added: ${illust_id}`);
    } catch (error: any) {
      logger.error(`Add bookmark failed: ` + JSON.stringify(error));
      throw error;
    }
  }


  /**
   * 取消收藏插画
   * @param illust_id 作品 ID
   */
  async deleteBookmark(illust_id: number): Promise<void> {
    if (!this.auth.isLogin()) {
      throw new Error('请先登录');
    }
    logger.info(`Deleting bookmark: ${illust_id}`);
    try {
      await this.auth.axiosInstance.post(
        '/v1/illust/bookmark/delete',
        urlQueryString({
          illust_id: illust_id,
        }),
        {
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        }
      );
      logger.info(`Bookmark deleted: ${illust_id}`);
    } catch (error: any) {
      logger.error(`Delete bookmark failed: ` + JSON.stringify(error));
      throw error;
    }
  }

}
