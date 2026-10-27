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
import { installWebSchemeHandler, setPixivSchemeCallback, clearDirectCookieJar } from "../../services/direct/WebDirect";
import { AccountContext } from "../../services/PixivTypes";

const logger = createLogger('PasswordLogin')

@Builder
export function PasswordLoginPage() {
  PasswordLoginComponent()
}


/**
 * 账号密码登录：原生输入 + 隐藏 WebView 自动填充
 * - WebView 走直连桥（真实浏览器 TLS/JS 指纹，Cloudflare 不拦）
 * - 原生界面输入账号密码，通过 runJavaScript 驱动真实登录表单提交
 * - 验证码/两步验证/自动填充失败时展示 WebView 转手动
 */
@ComponentV2
struct PasswordLoginComponent {
  webviewController: webview.WebviewController = new webview.WebviewController();

  // PKCE（@Local：aboutToAppear 异步构建后驱动 Web src 加载）
  @Local loginUrl: string = ''
  private codeVerifier: string = '';
  private pageStack: NavPathStack = new NavPathStack()

  // 原生输入
  @Local account: string = ''
  @Local password: string = ''

  // 状态
  @Local showWebView: boolean = false   // 是否展示 WebView（验证码/2FA/手动登录）
  @Local isSubmitting: boolean = false  // 已提交自动填充
  @Local isLoadingLogin: boolean = false
  @Local loadMessage: string = ''

  private pageReady: boolean = false    // 登录页加载完成
  private pendingSubmit: boolean = false // 页面就绪前提交的排队标记
  private handled: boolean = false      // 已处理登录回调
  private revealTimerId: number = -1    // 提交后超时展示 WebView 定时器
  private urlLoadTriggered: boolean = false // 显式 loadUrl 幂等标记

  async aboutToAppear(): Promise<void> {
    // 桥内截获 302 Location: pixiv:// 回调（内核 applink 打开会失败白屏）
    setPixivSchemeCallback((url: string) => {
      this.handleCallback(url);
    });
    try {
      this.isLoadingLogin = true;
      this.loadMessage = '正在准备登录...';

      // 生成 PKCE
      this.codeVerifier = this.generateRandomString(64);
      const codeChallenge = await this.generateCodeChallenge(this.codeVerifier);
      this.loginUrl = `https://app-api.pixiv.net/web/v1/login?code_challenge=${codeChallenge}&code_challenge_method=S256&client=pixiv-android&redirect_uri=${encodeURIComponent(AppConstants.REDIRECT_URI)}&state=login`;
      logger.info(`Loading login url: ${this.loginUrl}`);

      // 预填已保存账号的邮箱
      const accountsJson = await kvDbUtil.getData<string>('pixiv_accounts', '[]');
      const savedAccounts = JSON.parse(accountsJson) as AccountContext[];
      if (savedAccounts.length > 0 && savedAccounts[0].user?.mail_address) {
        this.account = savedAccounts[0].user.mail_address;
      }
    } catch (error) {
      logger.error(`初始化失败: `, error);
      toastUtil.showToast({ message: '初始化失败，请重试' });
    } finally {
      this.isLoadingLogin = false;
      // ArkWeb 的 src 参数更新不触发导航，URL 就绪后必须显式 loadUrl
      this.tryLoadLoginUrl();
    }
  }

  aboutToDisappear(): void {
    setPixivSchemeCallback(null);
    this.clearRevealTimer();
  }

  build() {
    NaviContainer({
      title: $r('app.string.password_login'),
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
      // 原生登录面板（覆盖隐藏 WebView）
      if (!this.showWebView) {
        Stack() {
          this.NativeLoginPanel()

          // 加载提示遮罩（仅覆盖原生面板，不遮 Web 的可见像素条）
          if (this.isLoadingLogin) {
            this.LoadingOverlay()
          }
        }
        .layoutWeight(1)
      }

      // WebView：ArkWeb 至少需要 1px 可见才工作
      // 隐藏时保留 1vp 可见条（不被面板/遮罩遮挡），需要时撑满转手动
      Web({ src: this.loginUrl, controller: this.webviewController })
        .domStorageAccess(true)
        .javaScriptAccess(true)
        .cacheMode(CacheMode.Default)
        .mixedMode(MixedMode.All)
        .onControllerAttached(() => {
          logger.info('onControllerAttached');
          try {
            this.webviewController.setCustomUserAgent('Mozilla/5.0 (Linux; Android 11; Pixel 5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36');
            // 直连桥：Pixiv 域名（ECH/COMPAT 模式）接管 WebView 网络层
            installWebSchemeHandler(this.webviewController);
            // 清除 WebView 全局 Cookie：否则缓存的上次登录会话让登录页直接显示
            // "继续使用当前账号"而无密码表单，账密自动填充必然失败
            webview.WebCookieManager.clearAllCookies();
            webview.WebCookieManager.clearSessionCookie();
            // 同步清空桥内域隔离 cookie jar（内核 Cookie 头已被桥重建替代，两处需一致清空）
            clearDirectCookieJar();
          } catch (error) {
            logger.error(`onControllerAttached error: ${(error as BusinessError).message}`);
          }
          // Web 挂载时 URL 可能已就绪（aboutToAppear 中 loadUrl 因未挂载而失败），补一次显式加载
          this.tryLoadLoginUrl();
        })
        .onLoadIntercept((event) => {
          // 拦截 pixiv:// 回调：ArkWeb 默认将其作为 applink 打开（16000019 失败白屏），必须在此截获
          const url = event.data.getRequestUrl();
          if (url.startsWith('pixiv://account/login')) {
            logger.info(`Pixiv scheme intercepted: ${url}`);
            this.handleCallback(url);
            return true;
          }
          return false;
        })
        .onPageBegin((event) => {
          const url = event.url;
          logger.info(`Page Begin Loading: ${url}`);
          // 检测到 Pixiv 回调，开始处理登录
          if (url.startsWith('pixiv://account/login')) {
            logger.info(`Pixiv callback detected: ${url}`);
            this.handleCallback(url);
            return;
          }
        })
        .onPageEnd((event) => {
          logger.info(`Page End Loading: ${event.url}`);
          // 仅真实登录页加载完成才算就绪（排除 about:blank 等）
          if (!event.url.startsWith('https://')) {
            return;
          }
          // auth/start 正常应在桥内被 302 pixiv:// 截获，不会渲染成页面；
          // 走到页面渲染说明服务端直接拒绝了授权启动（404"不正确的请求"），立刻转手动不等 18s
          if (event.url.indexOf('/web/v1/users/auth/pixiv/start') >= 0) {
            logger.error(`auth/start rendered as page, server rejected: ${event.url}`);
            this.revealManual('登录链路异常：授权启动被服务端拒绝');
            return;
          }
          this.pageReady = true;
          if (this.pendingSubmit) {
            this.pendingSubmit = false;
            this.autoFillAndSubmit();
          }
        })
        .onErrorReceive((event) => {
          const errorInfo = event.error;
          const url = event.request?.getRequestUrl() || '';
          logger.error(`WebView Error - Code: ${errorInfo.getErrorCode()}, Message: ${errorInfo.getErrorInfo()}, URL: ${url}`);
          // 忽略 pixiv:// 协议的错误（正常流程）
          if (url.startsWith('pixiv://')) {
            return;
          }
        })
        .width('100%')
        .height(this.showWebView ? '100%' : 1)
    }
    .width('100%')
    .height('100%')
  }

  // 原生账号密码输入面板
  @Builder
  NativeLoginPanel() {
    Column({ space: 16 }) {
      Image($r('app.media.app_icon_round'))
        .height(80)
        .margin({ bottom: 8 })

      TextInput({ placeholder: '邮箱地址 / Pixiv ID', text: this.account })
        .width('100%')
        .height(50)
        .fontSize(15)
        .onChange((v: string) => {
          this.account = v;
        })

      TextInput({ placeholder: '密码', text: this.password })
        .width('100%')
        .height(50)
        .fontSize(15)
        .type(InputType.Password)
        .onChange((v: string) => {
          this.password = v;
        })

      Button($r('app.string.login'))
        .width('100%')
        .height(48)
        .fontSize(17)
        .margin({ top: 8 })
        .onClick(() => {
          this.onSubmit();
        })

      Button('显示网页登录')
        .width('100%')
        .height(44)
        .fontSize(15)
        .backgroundColor('#F0F0F0')
        .fontColor('#333333')
        .onClick(() => {
          this.revealManual('请在网页中完成登录');
        })
    }
    .padding({ left: 32, right: 32 })
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
    .justifyContent(FlexAlign.Center)
  }

  // 加载提示遮罩组件
  @Builder
  LoadingOverlay() {
    Column({ space: 16 }) {
      LoadingProgress()
        .width(48)
        .height(48)
        .color('#0096FA')

      Text(this.loadMessage)
        .fontSize(16)
        .fontWeight(500)
        .fontColor('#333333')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(255, 255, 255, 0.95)')
    .justifyContent(FlexAlign.Center)
    .zIndex(100)
  }

  // --- 交互逻辑 ---

  // 提交：自动填充隐藏 WebView 中的真实登录表单并提交
  private onSubmit(): void {
    if (this.isSubmitting || this.handled) {
      return;
    }
    if (!this.account || !this.password) {
      toastUtil.showToast({ message: '请输入账号和密码' });
      return;
    }
    this.isSubmitting = true;
    if (!this.pageReady) {
      // 登录页尚未就绪：排队，页面加载完自动提交
      this.pendingSubmit = true;
      toastUtil.showToast({ message: '正在准备登录页面，稍候将自动填充' });
      return;
    }
    this.autoFillAndSubmit();
  }

  // 自动填充 + 提交（SPA 渲染需要时间，找不到表单时每秒重试，最多 10 次）
  private async autoFillAndSubmit(): Promise<void> {
    this.loadMessage = '正在自动填充...';
    this.isLoadingLogin = true;
    let filled = false;
    for (let i = 0; i < 10 && !this.handled; i++) {
      const result = await this.tryAutoFill();
      if (result.startsWith('OK')) {
        logger.info(`Auto fill submitted, button: ${result.substring(3)}`);
        filled = true;
        break;
      }
      if (result !== 'FIELDS_NOT_FOUND') {
        logger.error(`Auto fill failed: ${result}`);
        break;
      }
      await this.sleep(1000);
    }
    if (this.handled) {
      return;
    }
    if (filled) {
      // 已提交：验证码/两步验证/密码错误时页面不会跳转；
      // 等待登录链路期间保持加载态（用户反馈中间无任何提示），超时后展示网页转手动
      this.loadMessage = '正在登录...';
      this.clearRevealTimer();
      this.revealTimerId = setTimeout(() => {
        this.revealTimerId = -1;
        if (!this.handled) {
          this.revealManual('请在网页中完成验证（验证码/两步验证），或检查账号密码');
        }
      }, 18000);
    } else {
      this.revealManual('自动填充失败，请手动登录');
    }
  }

  // 在页面上下文中定位登录表单，填充并点击提交
  private async tryAutoFill(): Promise<string> {
    try {
      const script =
        `(function(){` +
        `try{` +
        `var pwd=null,id=null;` +
        `var inputs=document.querySelectorAll('input');` +
        `for(var i=0;i<inputs.length;i++){` +
        `var el=inputs[i];` +
        `var t=(el.getAttribute('type')||'text').toLowerCase();` +
        `if(t==='password'&&el.offsetWidth>0&&!pwd){pwd=el;}` +
        `else if((t==='text'||t==='email'||t==='tel')&&el.offsetWidth>0&&!id){id=el;}` +
        `}` +
        `if(!pwd||!id){return 'FIELDS_NOT_FOUND';}` +
        `function setV(el,v){` +
        `var d=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value');` +
        `if(d&&d.set){d.set.call(el,v);}else{el.value=v;}` +
        `el.dispatchEvent(new Event('input',{bubbles:true}));` +
        `el.dispatchEvent(new Event('change',{bubbles:true}));` +
        `}` +
        `setV(id,${JSON.stringify(this.account)});` +
        `setV(pwd,${JSON.stringify(this.password)});` +
        // 社交登录按钮（Apple/Google 等排在表单前且多为 type=submit），必须排除，否则会误点跳转 Apple 登录页
        `function isSocial(btn){` +
        `var fa=btn.form?(btn.form.getAttribute('action')||''):'';` +
        `var tx=((btn.textContent||'')+' '+(btn.getAttribute('aria-label')||'')+' '+(btn.id||'')+' '+(btn.className||'')+' '+fa).toLowerCase();` +
        `return /apple|google|facebook|twitter|weibo|\\uff51\\uff51/.test(tx);` +
        `}` +
        // 第一优先：密码框所在表单内的提交按钮；其次全文档 type=submit；最后按文案匹配
        `var scopes=[pwd.form||document,document];` +
        `var btn=null;` +
        `for(var s=0;s<scopes.length&&!btn;s++){` +
        `var cands=scopes[s].querySelectorAll('button[type=submit],input[type=submit]');` +
        `for(var k=0;k<cands.length;k++){` +
        `if(!isSocial(cands[k])){btn=cands[k];break;}` +
        `}` +
        `}` +
        `if(!btn){` +
        `var btns=document.querySelectorAll('button');` +
        `for(var j=0;j<btns.length;j++){` +
        `var tx2=(btns[j].textContent||'').trim();` +
        `if(isSocial(btns[j])){continue;}` +
        `if(/^(log ?in|ログイン|登入|登录|sign ?in)$/i.test(tx2)){btn=btns[j];break;}` +
        `}` +
        `}` +
        `if(!btn){return 'BUTTON_NOT_FOUND';}` +
        `btn.click();` +
        `return 'OK:'+(btn.textContent||'').trim().substring(0,20);` +
        `}catch(e){return 'ERROR:'+e.message;}` +
        `})()`;
      const result = await this.webviewController.runJavaScript(script);
      // 结果可能被 JSON 字符串化（带引号），统一去掉
      return (result || '').replace(/^"|"$/g, '');
    } catch (e) {
      return 'ERROR:' + (e as BusinessError).message;
    }
  }

  // 展示 WebView 转手动登录
  private revealManual(message: string): void {
    this.clearRevealTimer();
    this.isSubmitting = false;
    this.pendingSubmit = false;
    this.isLoadingLogin = false;
    if (message) {
      toastUtil.showToast({ message: message });
    }
    this.showWebView = true;
  }

  // 处理登录回调，提取 code 换 token
  private async handleCallback(url: string): Promise<void> {
    if (this.handled) {
      return;
    }
    logger.info(`Callback URL: ${url}`);
    this.handled = true;
    this.clearRevealTimer();
    this.isLoadingLogin = true;
    this.loadMessage = '正在登录...';

    const codeMatch = url.match(/[?&]code=([^&]+)/);
    if (!codeMatch) {
      logger.error('No code found in callback URL');
      this.isLoadingLogin = false;
      toastUtil.showToast({ message: '登录失败：未获取到授权码' });
      return;
    }
    const code = decodeURIComponent(codeMatch[1]);

    try {
      this.loadMessage = '正在验证身份...';
      await pixiv.loginWithAuthCode(code, this.codeVerifier);

      this.loadMessage = '正在保存登录信息...';
      PixState.isLoggedIn = true;

      // 多账号持久化 + 恢复自动登录
      const allAccounts = pixiv.getAllAccounts();
      const activeAccount = pixiv.getActiveAccount();
      await kvDbUtil.putData('pixiv_accounts', JSON.stringify(allAccounts));
      if (activeAccount) {
        await kvDbUtil.putData('active_user_id', activeAccount.userId);
      }
      await kvDbUtil.putData('auto_login', '1');

      EventHub.sendEvent(EventKey.FetchData);

      this.loadMessage = '登录成功！';
      setTimeout(() => {
        toastUtil.showToast({ message: PixState.isAddingAccount ? $r('app.string.account_added_successfully') : $r('app.string.login_successfully') });
        // 弹出自身；下层若是 login 路由页（添加账号/重登流程）一并弹出，回到账号管理页。
        // 注意：NavPathStack 无 pop(index) 重载，原 pop(2) 实为 pop(result) 只弹 1 层
        this.pageStack.pop();
        if (this.pageStack.size() > 0) {
          this.pageStack.pop();
        }
        PixState.isAddingAccount = false;
      }, 500);
    } catch (e) {
      logger.error('Password login failed: ' + JSON.stringify(e));
      this.isLoadingLogin = false;
      toastUtil.showToast({ message: '登录失败：' + ((e as BusinessError).message || '未知错误') });
    }
  }

  // --- 工具函数 ---

  // 显式加载登录 URL（幂等）：ArkWeb 的 src 参数更新不触发导航，必须主动 loadUrl
  private tryLoadLoginUrl(): void {
    if (this.urlLoadTriggered || !this.loginUrl) {
      return;
    }
    try {
      this.webviewController.loadUrl(this.loginUrl);
      this.urlLoadTriggered = true;
      logger.info('Explicit loadUrl triggered.');
    } catch (e) {
      // 17100001: controller 未 attach，等 onControllerAttached 回调重试
      logger.info(`Controller not ready yet: ${(e as BusinessError).message}`);
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: (value: void) => void) => {
      setTimeout(() => resolve(), ms);
    });
  }

  private clearRevealTimer(): void {
    if (this.revealTimerId !== -1) {
      clearTimeout(this.revealTimerId);
      this.revealTimerId = -1;
    }
  }

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
      return this.base64ToBase64Url(base64Str);
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
