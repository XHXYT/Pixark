import { PixState } from '../entryability/AppState';
import { PixivUser } from '../services/PixivTypes';
import { createLogger } from '../common/utils/Logger';
import { pixiv } from '../services/PixivService';
import { appSettings } from '../common/entity/SettingsModel';
import { EventHub, EventKey } from '../common/utils/EventHub';
import { toastUtil } from '../common/utils/ToastUtils';
import { ResourceUtils } from '../common/utils/ResourceUtil';
import { kvDbUtil } from '../common/utils/KVdbUtil';


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
    // OAuth（auth/token）响应的 user 没有 medium 键（只有 px_170x170 等），
    // 刷新 Token / 快速登录后 currentUser 可能是 OAuth user，此处兜底
    const urls = this.currentUser?.profile_image_urls;
    return urls?.medium || urls?.px_170x170 || '';
  }

  get userID(): string {
    return (this.currentUser?.id || 0).toString();
  }

  switchMode() {
    appSettings.novel_mode = !appSettings.novel_mode
    EventHub.sendEvent(EventKey.FetchData)
    if (appSettings.novel_mode) {
      toastUtil.showToast({ message: ResourceUtils.getString($r('app.string.enter')) + ResourceUtils.getString($r('app.string.novel_mode')) })
    } else {
      toastUtil.showToast({ message: ResourceUtils.getString($r('app.string.enter')) + ResourceUtils.getString($r('app.string.illust_mode')) })
    }
  }

  // 处理登出逻辑（saveAccount：是否保留账号记录，供登录页快速登录）
  async handleLogout(saveAccount: boolean) {
    try {
      logger.info(`User requested logout. keepAccountRecord=${saveAccount}`);
      if (!saveAccount) {
        // 不保留记录：从持久化中移除当前账号
        const account = pixiv.getActiveAccount();
        if (account) {
          pixiv.removeAccount(account.userId);
        }
        await kvDbUtil.putData('pixiv_accounts', JSON.stringify(pixiv.getAllAccounts()));
        const active = pixiv.getActiveAccount();
        await kvDbUtil.putData('active_user_id', active ? active.userId : '');
      }
      // 保留记录时：pixiv_accounts / active_user_id 原样留存
      // 清空内存登录态，关闭自动登录（重启后停在登录页）
      pixiv.clearAccounts();
      await kvDbUtil.putData('auto_login', '0');
      PixState.isLoggedIn = false;
      EventHub.sendEvent(EventKey.FetchData);
      // 不再 pushPage('login')：isLoggedIn=false 时 Index 已切换到 Login(main)，
      // 此时主 Navigation 已卸载，悬空的 login 条目会在下次登录成功、
      // Navigation 重新挂载时盖在主页上（登录后停留在登录页的根因）
    } catch (e) {
      logger.error('Logout failed: ' + e.message);
    }
  }

}

export const moreVM = new MoreViewModel();
