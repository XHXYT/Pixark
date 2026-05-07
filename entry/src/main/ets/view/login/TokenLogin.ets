
import { EventHub, EventKey } from "../../utils/EventHub";
import { kvDbUtil } from "../../utils/KVdbUtil";
import { createLogger } from "../../utils/Logger";
import { toastUtil } from "../../utils/ToastUtils";
import { PixState } from "../../entryability/AppState";

const logger = createLogger('TokenLogin')

@Builder
export function TokenLoginPage() {
  TokenLoginPageComponent()
}

@ComponentV2
struct TokenLoginPageComponent {

  @Local tokenInput: string = '';

  build() {
    NavDestination() {
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
              await PixState.pixiv.loginWithRefreshToken(this.tokenInput);
              PixState.isLoggedIn = true;
              const currentToken = PixState.pixiv.getCurrentRefreshToken();
              if (currentToken) {
                await kvDbUtil.putData('refresh_token', currentToken);
                EventHub.sendEvent(EventKey.FetchData, currentToken);
                // 返回主界面
                PixState.pageStack.pop(true)
                toastUtil.showToast({ message: '登录成功' });
              }
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
    .padding({ top: PixState.topRectHeight, bottom: PixState.bottomRectHeight })
    .hideToolBar(true)
    .title('Token登录')
  }
}
