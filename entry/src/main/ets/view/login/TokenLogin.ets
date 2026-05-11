
import { EventHub, EventKey } from "../../common/utils/EventHub";
import { kvDbUtil } from "../../common/utils/KVdbUtil";
import { createLogger } from "../../common/utils/Logger";
import { toastUtil } from "../../common/utils/ToastUtils";
import { NaviContainer } from "../../components/NaviContainer";
import { PixState } from "../../entryability/AppState";
import { pixiv } from "../../services/PixivService";

const logger = createLogger('TokenLogin')

@Builder
export function TokenLoginPage() {
  TokenLoginPageComponent()
}

@ComponentV2
struct TokenLoginPageComponent {

  @Local tokenInput: string = '';

  private pageStack: NavPathStack = new NavPathStack()

  build() {
    NaviContainer({
      title: $r('app.string.token_login'),
      content: () => {
        this.Content()
      },
      onReady: (ctx) => {
        this.pageStack = ctx.pathStack
      }
    })
  }

  @Builder
  Content() {
    Column() {
      TextInput({ placeholder: '请输入 Refresh Token' })
        .onChange(v => {
          this.tokenInput = v;
        })
        .margin({ bottom: 20 })
        .type(InputType.Normal)

      Button('使用 Token 登录')
        .width('100%')
        .onClick(async () => {
          if (!this.tokenInput) {
            toastUtil.showToast({ message: '请输入 Token' });
            return;
          }
          PixState.isLoading = true;
          try {
            await pixiv.loginWithRefreshToken(this.tokenInput);
            PixState.isLoggedIn = true;
            // 多账号持久化：获取所有账号和当前激活账号
            const allAccounts = pixiv.getAllAccounts();
            const activeAccount = pixiv.getActiveAccount();

            await kvDbUtil.putData('pixiv_accounts', JSON.stringify(allAccounts));
            if (activeAccount) {
              await kvDbUtil.putData('active_user_id', activeAccount.userId);
            }
            EventHub.sendEvent(EventKey.FetchData);
            // 根据模式显示不同提示语
            toastUtil.showToast({ message: PixState.isAddingAccount ? $r('app.string.account_added_successfully') : $r('app.string.login_successfully') });
            // 直接退回账号管理页
            this.pageStack.pop(2);
            // 重置添加模式标记
            PixState.isAddingAccount = false;
          } catch (e) {
            logger.error('Login failed: ' + JSON.stringify(e));
            toastUtil.showToast({ message: 'Token 无效或已过期' });
          } finally {
            PixState.isLoading = false;
          }
        })

      // 如何获取 token 的说明
      Text('💡 获取 Token 方法：')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16, bottom: 8 });

      Text('1. 在浏览器中登录 Pixiv')
        .fontSize(12)
        .fontColor('#666')
        .margin({ bottom: 4 });

      Text('2. 打开浏览器开发者工具 (F12)')
        .fontSize(12)
        .fontColor('#666')
        .margin({ bottom: 4 });

      Text('3. 访问 https://app-api.pixiv.net/web/v1/users/auth/pixiv/callback')
        .fontSize(12)
        .fontColor('#666')
        .margin({ bottom: 4 });

      Text('4. 在响应中找到 refresh_token')
        .fontSize(12)
        .fontColor('#666');
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 15, right: 15 })
  }

}
