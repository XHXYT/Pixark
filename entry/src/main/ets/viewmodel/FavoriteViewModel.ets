import { PixState } from '../entryability/AppState';
import { createLogger } from '../utils/Logger'


const logger = createLogger('FavoriteViewModel')

@ObservedV2
class FavoriteViewModel {

  async syncFollowing() {
    if (!PixState.pixiv.isLogin()) {
      logger.warn('未登录，跳过关注状态同步');
      return;
    }
    try {
      logger.info(`[syncFollowing] 当前登录用户ID ${PixState.currentUser?.id}`);
      // 获取关注用户ID
      const pub = await PixState.pixiv.syncFollowingStatus(PixState.currentUser?.id, 'public');
      const priv = await PixState.pixiv.syncFollowingStatus(PixState.currentUser?.id, 'private');

      // logger.info(`[syncFollowing] 关注状态同步完成，共关注 ${PixState.followingUserIds.size} 位作者`);
    } catch (e) {
      logger.error('[syncFollowing] 关注状态同步失败', e);
    }
  }

}