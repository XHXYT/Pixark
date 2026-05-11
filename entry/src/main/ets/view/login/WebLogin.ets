import { webview } from "@kit.ArkWeb";
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { buffer, util } from '@kit.ArkTS';
import { PixState } from "../../entryability/AppState";
import { createLogger } from "../../common/utils/Logger";
import { toastUtil } from "../../common/utils/ToastUtils";
import { kvDbUtil } from "../../common/utils/KVdbUtil";
import { EventHub, EventKey } from "../../common/utils/EventHub";
import { BusinessError } from "@kit.BasicServicesKit";
import { NaviContainer } from "../../components/NaviContainer";
import { pixiv } from "../../services/PixivService";
import { AppConstants } from "../../common/constants/AppConstants";

const logger = createLogger('WebLogin')

@Builder
export function WebLoginPage() {
  WebLoginPageComponent()
}


@ComponentV2
struct WebLoginPageComponent {
  webviewController: webview.WebviewController = new webview.WebviewController();

  // URL 相关
  private loginUrl: string = ''
  private codeVerifier: string = '';
  private pageStack: NavPathStack = new NavPathStack()

  // 加载状态
  @Local isLoadingPage: boolean = false;        // 网页是否正在加载
  @Local isLoadingLogin: boolean = false;       // 是否正在处理登录（换 token）
  @Local loadProgress: number = 0;              // 加载进度 0-100
  @Local loadMessage: string = '正在准备登录...'; // 加载提示文字

  async aboutToAppear(): Promise<void> {
    try {
      this.isLoadingLogin = true;
      this.loadMessage = '正在生成安全验证...';

      // 生成 Code Verifier
      this.codeVerifier = this.generateRandomString(64);

      // 生成 Code Challenge
      const codeChallenge = await this.generateCodeChallenge(this.codeVerifier);

      // 构造登录 URL
      this.loginUrl = `https://app-api.pixiv.net/web/v1/login?code_challenge=${codeChallenge}&code_challenge_method=S256&client=pixiv-android&redirect_uri=${encodeURIComponent(AppConstants.REDIRECT_URI)}&state=login`;

      logger.info(`Loading Pixiv Login URL: ${this.loginUrl}`);
      this.isLoadingLogin = false;
    } catch (error) {
      logger.error(`初始化失败: `, error);
      this.loadMessage = '初始化失败，请重试';
      toastUtil.showToast({ message: '初始化失败，请重试' });
    }
  }

  build() {
    NaviContainer({
      title: $r('app.string.login'),
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
    Stack({ alignContent: Alignment.Top }) {
      // WebView
      Web({ src: this.loginUrl, controller: this.webviewController })
        .domStorageAccess(true)
        .javaScriptAccess(true)
        .cacheMode(CacheMode.Default)
        .mixedMode(MixedMode.All)
        .fileAccess(true)
        .onlineImageAccess(true)
        .onAppear(() => {
          try {
            this.webviewController.loadUrl(this.loginUrl)
          } catch (error) {
            logger.error(`loadUrl ErrorCode: ${(error as BusinessError).code},  Message: ${(error as BusinessError).message}`);
          }
        })
        .onPageBegin((event) => {
          const url = event.url;
          logger.info(`Page Begin Loading: ${url}`);

          // 检测到 Pixiv 回调，开始处理登录
          if (url.startsWith('pixiv://account/login')) {
            logger.info(`Pixiv custom scheme callback detected, url: ${url}`);
            this.isLoadingPage = false; // 停止页面加载提示
            this.handleCallback(url);
            return;
          }

          // 其他页面开始加载
          this.isLoadingPage = true;
          this.loadMessage = '正在加载登录页面...';
        })
        .onPageEnd((event) => {
          logger.info(`Page End Loading: ${event.url}`);
          this.isLoadingPage = false;
          this.loadMessage = '加载完成';
        })
        .onControllerAttached(() => {
          logger.info("onControllerAttached");
          try {
            this.webviewController.setCustomUserAgent('Mozilla/5.0 (Linux; Android 11; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36');
          } catch (error) {
            logger.error(`ErrorCode: ${(error as BusinessError).code},  Message: ${(error as BusinessError).message}`);
          }
        })
        .onProgressChange((event) => {
          this.loadProgress = event.newProgress;
          // 只在有进度变化时更新提示
          if (event.newProgress > 0 && event.newProgress < 100) {
            this.loadMessage = `正在加载... ${event.newProgress}%`;
          }
        })
        .onErrorReceive((event) => {
          const errorInfo = event.error;
          const url = event.request?.getRequestUrl() || '';
          logger.error(`WebView Error - Code: ${errorInfo.getErrorCode()}, Message: ${errorInfo.getErrorInfo()}, URL: ${url}`);

          // 忽略 pixiv:// 协议的错误（这是正常的）
          if (url.startsWith('pixiv://')) {
            return;
          }

          this.isLoadingPage = false;

          // 只有非预期的错误才显示 Toast
          if (this.loginUrl && errorInfo.getErrorCode() !== -302) {
            toastUtil.showToast({ message: `WebView 错误: ${errorInfo.getErrorInfo()}` });
          }
        })
        .onHttpErrorReceive((event) => {
          logger.error(`HTTP Error - Message: ${event.response.getReasonMessage()}, Status:${event.response.getResponseCode()}`);
          this.isLoadingPage = false;
        })
        .width('100%')
        .layoutWeight(1);

      // 加载提示遮罩
      if (this.isLoadingPage || this.isLoadingLogin) {
        this.LoadingOverlay()
      }
    }
    .width('100%')
    .padding({ left: 15, right: 15 })
  }

  // 加载提示遮罩组件
  @Builder
  LoadingOverlay() {
    Column({ space: 16 }) {
      // 加载动画
      LoadingProgress()
        .width(48)
        .height(48)
        .color('#0096FA')

      // 提示文字
      Text(this.loadMessage)
        .fontSize(16)
        .fontWeight(500)
        .fontColor('#333333')

      // 进度条（仅在网页加载时显示）
      if (this.isLoadingPage && this.loadProgress > 0) {
        Column({ space: 8 }) {
          Progress({ value: this.loadProgress, total: 100, type: ProgressType.Linear })
            .width(200)
            .height(4)
            .color('#0096FA')
            .backgroundColor('#E5E5E5')

          Text(`${this.loadProgress}%`)
            .fontSize(12)
            .fontColor('#999999')
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(255, 255, 255, 0.95)')
    .justifyContent(FlexAlign.Center)
    .zIndex(100)
  }

  // 处理回调，提取 code 并登录
  async handleCallback(url: string) {
    logger.info(`Callback URL: ${url}`);
    this.isLoadingLogin = true;
    this.loadMessage = '正在登录...';

    // 解析 URL 中的 code 参数
    const codeMatch = url.match(/[?&]code=([^&]+)/);
    if (!codeMatch) {
      logger.error('No code found in callback URL');
      this.isLoadingLogin = false;
      toastUtil.showToast({ message: '登录失败：未获取到授权码' });
      return;
    }
    const code = decodeURIComponent(codeMatch[1]);

    try {
      // 使用 auth code 登录
      this.loadMessage = '正在验证身份...';
      await pixiv.loginWithAuthCode(code, this.codeVerifier);

      this.loadMessage = '正在保存登录信息...';
      // 登录成功后的标准处理
      PixState.isLoggedIn = true;

      // 多账号持久化：获取所有账号和当前激活账号
      const allAccounts = pixiv.getAllAccounts();
      const activeAccount = pixiv.getActiveAccount();

      await kvDbUtil.putData('pixiv_accounts', JSON.stringify(allAccounts));
      if (activeAccount) {
        await kvDbUtil.putData('active_user_id', activeAccount.userId);
      }

      // 发送获取数据事件
      EventHub.sendEvent(EventKey.FetchData);

      this.loadMessage = '登录成功！';
      setTimeout(() => {
        // 根据模式显示不同提示语
        toastUtil.showToast({ message: PixState.isAddingAccount ? $r('app.string.account_added_successfully') : $r('app.string.login_successfully') });
        // Pop 2 层直接退账号管理页
        this.pageStack.pop(2);
        // 重置添加模式标记
        PixState.isAddingAccount = false;
      }, 500);

    } catch (e) {
      logger.error('Web Login failed: ' + JSON.stringify(e));
      this.isLoadingLogin = false;
      toastUtil.showToast({ message: '登录失败：' + (e.message || '未知错误') });
    }
  }

  // --- 工具函数区域 ---
  private stringToUint8Array(str: string): Uint8Array {
    return new Uint8Array(buffer.from(str, 'utf-8').buffer);
  }

  private generateRandomString(length: number): string {
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    let result = '';
    for (let i = 0; i < length; i++) {
      result += characters.charAt(Math.floor(Math.random() * characters.length));
    }
    return result;
  }

  private async generateCodeChallenge(verifier: string): Promise<string> {
    try {
      const mdAlg = cryptoFramework.createMd('SHA256');
      const data = this.stringToUint8Array(verifier);
      const input: cryptoFramework.DataBlob = { data: data };

      const updatePromise = mdAlg.update(input).catch((e: BusinessError) => {
        logger.error(`#generateCodeChallenge.updatePromise 执行失败 `, e)
      });
      await updatePromise;

      const digest = await mdAlg.digest();
      const base64Helper = new util.Base64Helper();
      const base64Str = base64Helper.encodeToStringSync(digest.data);
      const base64UrlStr = this.base64ToBase64Url(base64Str);

      return base64UrlStr;
    } catch (e) {
      logger.error('Generate Challenge failed: ' + e.message);
      throw new Error(e);
    }
  }

  private base64ToBase64Url(base64: string): string {
    return base64
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
  }

}
