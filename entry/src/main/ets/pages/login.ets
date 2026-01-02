import { PixState } from "../entryability/AppState";
import { EventHub, EventKey } from "../utils/EventHub";
import { kvDbUtil } from "../utils/KVdbUtil";
import { createLogger } from "../utils/Logger";
import { toastUtil } from "../utils/ToastUtils";

const logger = createLogger('Login')

@ComponentV2
export struct Login {

  @Local username: string = '';
  @Local password: string = '';

  build() {
    Column() {
      // 登录方式选择
      Row() {
        Radio({ value: 'password', group: 'loginMethod' })
          .checked(PixState.loginMethod === 'password')
          .onChange(() => {
            PixState.loginMethod = 'password';
          })
          .margin({ right: 8 });

        Text('密码登录')
          .fontSize(16)
          .margin({ right: 20 });

        Radio({ value: 'token', group: 'loginMethod' })
          .checked(PixState.loginMethod === 'token')
          .onChange(() => {
            PixState.loginMethod = 'token';
          });

        Text('Token 登录')
          .fontSize(16);
      }
      .margin({ bottom: 16 });

      if (PixState.loginMethod === 'password') {
        // 密码登录表单
        TextInput({ placeholder: 'Pixiv 用户名 / 邮箱' })
          .onChange(v => {
            this.username = v;
            logger.info('Username input: ' + v);
          })
          .margin({ bottom: 8 });

        TextInput({ placeholder: '密码' })
          .type(InputType.Password)
          .onChange(v => {
            this.password = v;
          })
          .margin({ bottom: 8 });

        Button('登录')
          .onClick(() => {
            logger.info('Password login clicked.');
            this.doPasswordLogin();
          })
          .width('100%');
      } else {
        // Token 登录表单
        TextInput({ placeholder: 'Refresh Token' })
          .onChange(v => {
            PixState.refreshToken = v;
            logger.info('Token input: ' + v.substring(0, 20) + '...');
          })
          .margin({ bottom: 8 });

        Button('使用 Token 登录')
          .onClick(() => {
            logger.info('Token login clicked.');
            this.doTokenLogin();
          })
          .width('100%');

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
    }
    .padding({ top: PixState.topRectHeight, bottom: PixState.bottomRectHeight, left: 12, right: 12})
  }

  async doPasswordLogin() {
    let passwordErrMsg = ''
    logger.info('doPasswordLogin start.');
    if (!this.username || !this.password) {
      passwordErrMsg = '请输入用户名和密码'
      toastUtil.showToast({ message: passwordErrMsg })
      logger.warn('Login validation failed.');
      return;
    }
    PixState.isLoading = true;
    try {
      await PixState.pixiv.loginWithPassword(this.username, this.password);
      PixState.isLoggedIn = true;
      // 保存 refresh token
      const currentToken = PixState.pixiv.getCurrentRefreshToken();
      if (currentToken) {
        await this.saveRefreshToken(currentToken);
        logger.info('Password login success, status will be updated soon.');
      }
    } catch (e) {
      logger.error('Login process error: ' + JSON.stringify(e));
      passwordErrMsg = '登录失败：' + (e.response?.data?.errors?.system?.message || e.message);
      toastUtil.showToast({ message: passwordErrMsg })
    } finally {
      PixState.isLoading = false;
    }
  }

  async doTokenLogin() {
    let tokenErrmsg = ''
    logger.info('doTokenLogin start.');
    if (!PixState.refreshToken) {
      tokenErrmsg = '请输入 Refresh Token';
      toastUtil.showToast({ message: tokenErrmsg })
      return;
    }
    PixState.isLoading = true;
    tokenErrmsg = '';
    try {
      await PixState.pixiv.loginWithRefreshToken(PixState.refreshToken);
      PixState.isLoggedIn = true;
      // 保存 refresh token
      const currentToken = PixState.pixiv.getCurrentRefreshToken();
      if (currentToken) {
        this.saveRefreshToken(currentToken)
        logger.info('Token login success, status will be updated soon.');
      }
    } catch (e) {
      logger.error('Token login process error: ' + JSON.stringify(e));
      tokenErrmsg = 'Token 登录失败：' + e.message;
      toastUtil.showToast({ message: tokenErrmsg })
    } finally {
      PixState.isLoading = false;
    }
  }

  // 保存 refresh token
  async saveRefreshToken(token: string) {
    try {
      await kvDbUtil.putData('refresh_token', token)
      logger.info('#saveRefreshToken Refresh token saved');
      // 触发数据获取
      EventHub.sendEvent(EventKey.FetchData, token)
    } catch (e) {
      logger.error('#saveRefreshToken Save token error: ' + e.message);
    }
  }

}