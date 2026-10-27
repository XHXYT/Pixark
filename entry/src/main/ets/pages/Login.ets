import { NaviContainer } from '../components/NaviContainer';
import { PixState } from '../entryability/AppState';
import { pixiv } from '../services/PixivService';
import { AccountContext } from '../services/PixivTypes';
import { kvDbUtil } from '../common/utils/KVdbUtil';
import { EventHub, EventKey } from '../common/utils/EventHub';
import { toastUtil } from '../common/utils/ToastUtils';
import { createLogger } from '../common/utils/Logger';
import { PixivImageComponent } from '../components/PixivImage';
import { BusinessError } from '@kit.BasicServicesKit';


const logger = createLogger('LoginPage');


@Builder
export function LoginBuilder() {
  Login()
}

@ComponentV2
export struct Login {

  @Param mode: 'main' | 'router' = 'router'
  // 退出登录时保留的账号记录，可一键快速登录
  @Local savedAccounts: AccountContext[] = []
  // 正在快速登录的账号 ID（防重复点击）
  @Local quickLoginUserId: string = ''
  private pageStack: NavPathStack = new NavPathStack()

  async aboutToAppear(): Promise<void> {
    try {
      const accountsJson = await kvDbUtil.getData<string>('pixiv_accounts', '[]');
      this.savedAccounts = JSON.parse(accountsJson) as AccountContext[];
    } catch (e) {
      logger.error('Load saved accounts failed: ' + (e as BusinessError).message);
      this.savedAccounts = [];
    }
  }

  // 使用保存的 refresh token 快速登录
  async quickLogin(account: AccountContext) {
    if (this.quickLoginUserId) {
      return;
    }
    this.quickLoginUserId = account.userId;
    PixState.isLoading = true;
    try {
      const acct = await pixiv.loginWithRefreshToken(account.refreshToken);
      PixState.isLoggedIn = true;
      // 多账号持久化 + 恢复自动登录
      await kvDbUtil.putData('pixiv_accounts', JSON.stringify(pixiv.getAllAccounts()));
      await kvDbUtil.putData('active_user_id', acct.userId);
      await kvDbUtil.putData('auto_login', '1');
      EventHub.sendEvent(EventKey.FetchData);
      toastUtil.showToast({ message: $r('app.string.login_successfully') });
      PixState.isAddingAccount = false;
      // 仅 router 模式（login 作为路由页）需弹出自身；
      // main 模式私有栈为空，弹空栈会抛错并误报"登录失败"，主页切换由 isLoggedIn 驱动
      if (this.pageStack.size() > 0) {
        this.pageStack.pop();
      }
    } catch (e) {
      logger.error('Quick login failed: ' + (e as BusinessError).message);
      toastUtil.showToast({ message: '登录失败：' + ((e as BusinessError).message || '请重新登录') });
    } finally {
      PixState.isLoading = false;
      this.quickLoginUserId = '';
    }
  }

  build() {
    if (this.mode === 'main') {
      Navigation(this.pageStack) {
        this.Content()
      }
      .height('100%')
      .width('100%')
      .hideToolBar(true)
      .hideTitleBar(true)
      .mode(NavigationMode.Stack)
    } else {
      NaviContainer({
        hideTitleBar: !PixState.isAddingAccount,
        content: () => {
          this.Content()
        },
        onReady: (ctx) => {
          if (ctx.pathStack) {
            this.pageStack = ctx.pathStack
          }
        }
      })
    }
  }

  @Builder
  Content() {
    Column() {
      // 图标
      Image($r('app.media.app_icon_round'))
        .height(106)
        .margin({ bottom: 40 })

      // 已保存账号快速登录
      if (this.savedAccounts.length > 0) {
        this.SavedAccountList()
      }

      // 登录 (跳转到 Web 登录页)
      Button(PixState.isAddingAccount ? $r('app.string.add_an_account') : $r('app.string.login'))
        .width('80%')
        .height(50)
        .fontSize(18)
        .margin({ bottom: 20 })
        .onClick(() => {
          // 跳转到 Web 登录页
          this.pageStack.pushPathByName('web_login', null);
        })

      // 账号密码登录 (原生输入 + 隐藏 WebView 自动填充)
      Button($r('app.string.password_login'))
        .width('80%')
        .height(50)
        .fontSize(18)
        .margin({ bottom: 20 })
        .onClick(() => {
          this.pageStack.pushPathByName('password_login', null);
        })

      // 注册账号 (跳转到注册页)
      if (!PixState.isAddingAccount) {
        Button($r('app.string.register_account'))
          .width('80%')
          .height(50)
          .fontSize(18)
          .margin({ bottom: 20 })
          .onClick(() => {
            this.pageStack.pushPathByName('register', null);
          })
      }

      // Token 登录 (跳转到 Token 输入页)
      Button($r('app.string.token_login'))
        .width('80%')
        .height(50)
        .fontSize(18)
        .backgroundColor('#F0F0F0')
        .fontColor('#333333')
        .onClick(() => {
          // 跳转到 Token 登录页
          this.pageStack.pushPathByName('token_login', null);
        })
    }
    .padding({ top: PixState.topRectHeight, bottom: PixState.bottomRectHeight })
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
  }

  // 已保存账号列表（一键登录）
  @Builder
  SavedAccountList() {
    Column({ space: 10 }) {
      Text($r('app.string.saved_accounts'))
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))

      ForEach(this.savedAccounts, (acct: AccountContext) => {
        Row({ space: 10 }) {
          PixivImageComponent({
            imageUrl: acct.user.profile_image_urls?.medium || '',
            imageWidth: 36,
            imageHeight: 36,
            imageBorder: { radius: 18 }
          })

          Column({ space: 2 }) {
            Text(acct.user.name)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(`ID: ${acct.userId}`)
              .fontSize(11)
              .fontColor($r('sys.color.font_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          if (this.quickLoginUserId === acct.userId) {
            LoadingProgress()
              .width(20)
              .height(20)
          } else {
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(16)
              .fontColor([$r('sys.color.font_tertiary')])
          }
        }
        .width('100%')
        .padding({ top: 8, bottom: 8, left: 12, right: 12 })
        .borderRadius(12)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .onClick(() => {
          this.quickLogin(acct);
        })
      }, (acct: AccountContext) => acct.userId)
    }
    .width('80%')
    .margin({ bottom: 24 })
  }

}
