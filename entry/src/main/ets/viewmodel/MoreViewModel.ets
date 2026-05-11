import { PixState } from '../entryability/AppState';
import { PixivUser } from '../services/PixivTypes';
import { createLogger } from '../common/utils/Logger';
import { pixiv } from '../services/PixivService';


const logger = createLogger('MoreViewModel');

@ObservedV2
export class MoreViewModel {

  @Trace emailPrivacy: boolean = true

  // 获取当前登录用户信息
  get currentUser(): PixivUser | null {
    return PixState.currentUser
  }

  get isLogin(): boolean {
    return pixiv.isLogin();
  }

  // 获取显示名称：优先 nickname，其次 name
  get displayName(): ResourceStr {
    if (this.currentUser) {
      return this.currentUser.name || this.currentUser.account || '未知用户';
    }
    return $r('app.string.not_logged_in');
  }

  // 获取邮箱显示
  get email(): string {
    return this.currentUser?.mail_address || '';
  }

  get avatarUrl(): string {
    return this.currentUser?.profile_image_urls?.medium || '';
  }

  get userID(): string {
    return (this.currentUser?.id || 0).toString();
  }

  // 处理登出逻辑
  async handleLogout() {
    try {
      // TODO 确认弹窗及登出操作
      logger.info('User requested logout.');
      // 执行登出清理
      // await pixiv.logout()
      // 跳转回登录页

    } catch (e) {
      logger.error('Logout failed: ' + e.message);
    }
  }
}

export const moreVM = new MoreViewModel();
