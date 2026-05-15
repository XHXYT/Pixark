import { AbilityConstant, common, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { kvDbUtil } from '../common/utils/KVdbUtil';
import { toastUtil } from '../common/utils/ToastUtils';
import { BusinessError } from '@kit.BasicServicesKit';
import { AvoidanceManager, SmartAvoidance } from '../common/utils/AvoidManager';
import { PixState, _PixState } from './AppState';
import { ImageKnife } from '@ohos/imageknifepro';
import { ezCustomTransition } from '@hmanimations/ezcustomtransition';
import { preferenceUtil } from '../common/utils/persistence/PreferenceUtil';
import { appSettings } from '../common/entity/SettingsModel';
import { AccountContext } from '../services/PixivTypes';
import { homeViewModel } from '../viewmodel/HomeViewModel';
import { createLogger } from '../common/utils/Logger';
import { EventHub, EventKey } from '../common/utils/EventHub';
import { pixiv } from '../services/PixivService';
import { ColorUtils } from '../common/utils/ColorUtils';
import { favVM } from '../viewmodel/FavoriteViewModel';
import { animation } from '../common/utils/AnimationUtil';

const logger = createLogger('EntryAbility')
const BREAKPOINT_RATIO_LANDSCAPE = 0.79;
const BREAKPOINT_RATIO_PORTRAIT = 1.2;

export default class EntryAbility extends UIAbility {
  private isFirstStart: boolean = true
  private avoidManager: AvoidanceManager | undefined = undefined;
  private avoidListener: (avoidance: SmartAvoidance) => void = (newAvoidance) => {
    PixState.bottomRectHeight = newAvoidance.bottom
    PixState.topRectHeight = newAvoidance.top
    PixState.leftAvoidWidth = newAvoidance.left
    PixState.rightAvoidWidth = newAvoidance.right
  }

  // --- 生命周期 ---
  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    try {
      await this.initAppEnvironment();
      await this.initAppStateAndAuth();
      logger.info('Init', 'App environment and state initialized successfully.');
    } catch (error) {
      logger.error(`Init`, `Initialization failed, ${error}`);
    }
  }

  onDestroy(): void {
    logger.info('Lifecycle', 'EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    logger.info('Lifecycle', 'EntryAbility onWindowStageCreate');
    ezCustomTransition.init(windowStage)
    windowStage.loadContent('pages/Index', async (err) => {
      if (err.code) {
        logger.error(`WindowStage`, `Failed to load the content., ${err}`)
        return;
      }
      try {
        const data = await windowStage.getMainWindow()
        // 初始化通知工具
        toastUtil.initContext(data.getUIContext(), data.getUIContext().getHostContext() as common.UIAbilityContext)
        // 初始化UI上下文
        _PixState.UIContext = data.getUIContext()
        // 初始化动画工具
        animation.init(_PixState.UIContext)
        // 初始化窗口相关
        this.intRectWindow(windowStage, data.getUIContext())
      } catch (error) {
        logger.error(`WindowStage`, `Failed to get the Main Window, ${error}`)
      }
      logger.info('WindowStage', 'Succeeded in loading the content.');
    });
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    ezCustomTransition.onConfigurationChanged()
  }

  onWindowStageWillDestroy(windowStage: window.WindowStage): void {
    // 销毁避让管理器并移除监听
    if (this.avoidManager) {
      this.avoidManager.offChangeListener(this.avoidListener);
      this.avoidManager.destroy();
      this.avoidManager = undefined;
    }
    logger.info('Lifecycle', 'EntryAbility onWindowStageWillDestroy');
  }

  onWindowStageDestroy(): void {
    logger.info('Lifecycle', 'EntryAbility onWindowStageDestroy');
  }

  onForeground(): void {
    logger.info('Lifecycle', 'EntryAbility onForeground');
  }

  onBackground(): void {
    logger.info('Lifecycle', 'EntryAbility onBackground');
  }

  // --- 核心初始化 ---
  /**
   * 初始化应用基础环境 (偏好设置、数据库、颜色、图片缓存等)
   */
  private async initAppEnvironment() {
    // 初始化首选项
    await preferenceUtil.init(this.context, 'pixark_preference');
    // 初始化KV数据库
    await kvDbUtil.initKVManager(this.context, 'pixark')
    // 加载设置数据
    await appSettings.load()

    // 初始化颜色工具
    ColorUtils.init(this.context)

    // 设置深浅色模式
    try {
      const color_mode = await preferenceUtil.get<ConfigurationConstant.ColorMode>('color_mode', ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
      logger.info('ColorMode', `保存的颜色模式：${color_mode}`);
      this.context.getApplicationContext().setColorMode(color_mode);
    } catch (err) {
      logger.error(`ColorMode`, `Failed to set colorMode, ${err}`)
    }

    _PixState.Context = this.context

    // 初始化 ImageKnife 文件缓存
    await ImageKnife.getInstance().initFileCache(this.context, 256, 256 * 1024 * 1024);
    // 全局添加 Pixiv 必需的 Referer
    ImageKnife.getInstance().addHeader('Referer', 'https://www.pixiv.net/');
  }

  /**
   * 初始化账号状态与授权逻辑 (决定进入主页还是登录页)
   */
  private async initAppStateAndAuth() {
    // 标记进入初始化阶段
    PixState.isLoading = true;
    PixState.isInitializing = true;

    // 初始化账号信息 (仅读取本地，速度极快)
    await this.initAccounts()

    // 只要本地有账号，立即关闭 Loading，优先渲染出主界面
    if (pixiv.isLogin()) {
      PixState.isLoggedIn = true;
      const currentUser = pixiv.getCurrentUser();
      if (currentUser) {
        PixState.currentUser = currentUser;
      }
      // 立即关闭初始化状态，UI 渲染主界面
      PixState.isLoading = false;
      PixState.isInitializing = false;

      // 在后台静默同步 Token 和加载数据 (不阻塞 UI)
      this.backgroundSyncData();
    } else {
      // 没有账号，也要关闭 Loading，让 UI 跳转到登录页
      PixState.isLoggedIn = false;
      PixState.isLoading = false;
      PixState.isInitializing = false;
    }

    // 注册数据获取事件
    EventHub.on(EventKey.FetchData, () => {
      this.handleFetchDataEvent();
    });
  }

  /**
   * 纯本地账号初始化(不包含网络请求)
   */
  private async initAccounts() {
    let savedAccounts: AccountContext[] = [];
    let lastActiveUserId = '';
    let retryCount = 3;

    while (retryCount > 0) {
      try {
        const accountsJson = await kvDbUtil.getData<string>('pixiv_accounts', '[]');
        savedAccounts = JSON.parse(accountsJson) as AccountContext[];
        lastActiveUserId = await kvDbUtil.getData<string>('active_user_id', '');
        break;
      } catch (dbError) {
        retryCount--;
        if (retryCount > 0) {
          logger.warn('InitAccounts', `KVStore not ready, waiting 100ms... (${3 - retryCount}/3)`);
          await new Promise<void>((resolve: (value: void) => void) => { setTimeout(() => resolve(), 100); });
        } else {
          logger.error('InitAccounts', `KVStore failed after 3 retries: ${dbError?.message}`);
          return;
        }
      }
    }

    try {
      // 兼容老版本：单 token 迁移 (仅老用户首次升级触发，可接受短暂等待)
      if (savedAccounts.length === 0) {
        const oldRefreshToken = await kvDbUtil.getData<string>('refresh_token', '');
        if (oldRefreshToken) {
          logger.info('InitAccounts', 'Migrating old single token to multi-account system...');
          try {
            const newAccount = await pixiv.loginWithRefreshToken(oldRefreshToken);
            savedAccounts.push(newAccount);
            await kvDbUtil.putData('pixiv_accounts', JSON.stringify(savedAccounts));
            await kvDbUtil.putData('active_user_id', newAccount.userId);
            pixiv.initAccounts(savedAccounts, newAccount.userId);
            logger.info('InitAccounts', 'Old token migrated successfully.');
            return;
          } catch (migrateError) {
            logger.error('InitAccounts', `Old token migration failed: ${JSON.stringify(migrateError)}`);
            await kvDbUtil.putData('refresh_token', '');
            return;
          }
        }
      } else {
        // 🌟 正常的多账号初始化 (纯内存操作，极快)
        pixiv.initAccounts(savedAccounts, lastActiveUserId);
        logger.info('InitAccounts', `Multi-account initialized. Count: ${savedAccounts.length}`);
      }
    } catch (e) {
      logger.error('InitAccounts', `Account logic error: ${e?.message || JSON.stringify(e)}`);
    }
  }

  // --- 数据同步与事件 ---
  /**
   * 全局数据刷新事件处理 (核心调度中心)
   */
  private async handleFetchDataEvent() {
    logger.info('FetchDataEvent', 'Received FetchData event, reloading all data...');

    if (!pixiv.isLogin()) {
      PixState.isLoggedIn = false;
      return;
    }

    // 更新全局基础状态
    PixState.isLoggedIn = true;
    const currentUser = pixiv.getCurrentUser();
    if (currentUser) {
      PixState.currentUser = currentUser;
      PixState.currentUserDetail = null;
    }

    // 通知所有 ViewModel 重置并重新加载
    homeViewModel.resetAndLoad();
    favVM.resetAndLoad();
    // 以后有新的 ViewModel 往这里加
  }

  /**
   * 后台静默同步数据 (Token刷新、用户详情、首页数据)
   * 不阻塞 UI 渲染，已经加载主界面
   */
  private async backgroundSyncData() {
    try {
      // 后台静默刷新当前激活账号的 Token
      const activeAccount = pixiv.getActiveAccount();
      if (activeAccount?.refreshToken) {
        try {
          logger.info('BackgroundSync', 'Silently refreshing active token in background...');
          const updatedAccount = await pixiv.loginWithRefreshToken(activeAccount.refreshToken);
          const allAccounts = pixiv.getAllAccounts();
          const index = allAccounts.findIndex((a: AccountContext) => a.userId === updatedAccount.userId);
          if (index !== -1) allAccounts[index] = updatedAccount;
          await kvDbUtil.putData('pixiv_accounts', JSON.stringify(allAccounts));
          logger.info('BackgroundSync', 'Silent refresh successful.');
        } catch (refreshError) {
          logger.warn('BackgroundSync', `Silent refresh failed: ${JSON.stringify(refreshError)}`);
        }
      }

      // 补全用户详细信息
      const currentUser = PixState.currentUser;
      if (currentUser && !currentUser.profile_image_urls?.medium) {
        logger.warn('BackgroundSync', 'Fetching missing user detail...');
        const full = await pixiv.getUserDetail(currentUser.id);
        PixState.currentUserDetail = full;
        const email = PixState.currentUser?.mail_address;
        PixState.currentUser = full.user;
        if (email) PixState.currentUser.mail_address = email;
        pixiv.updateAccountUser(currentUser.id.toString(), PixState.currentUser);
        const allAccounts = pixiv.getAllAccounts();
        await kvDbUtil.putData('pixiv_accounts', JSON.stringify(allAccounts));
      }

      // 加载主页内容 (展示骨架屏)
      if (!PixState.isTest) {
        homeViewModel.loadHomeData();
      } else {
        await homeViewModel.loadHomeData();
      }
    } catch (e) {
      logger.error('BackgroundSync', `Error: ${e?.message || JSON.stringify(e)}`);
    }
  }

  // --- 窗口与UI管理 ---
  /**
   * 初始化窗口
   */
  async intRectWindow(windowStage: window.WindowStage, UIContext: UIContext) {
    // 设置自动记忆最后关闭的窗口大小(仅2in1设备生效)
    try {
      await windowStage.setWindowRectAutoSave(true);
      logger.info("WindowAutoSave", 'Succeeded in setting window rect auto-save')
    } catch (exception) {
      logger.error("WindowAutoSave", `Failed to set window rect auto-save. Cause code: ${exception.code} smessage: ${exception.message}`)
    }

    // 获取应用主窗口
    try {
      const windowClass: window.Window = windowStage.getMainWindowSync();

      // 设置窗口全屏
      windowClass.setWindowLayoutFullScreen(true).then(() => {
        logger.info('WindowRect', 'Succeeded in setting the window layout to full-screen mode.');
      }).catch((err: BusinessError) => {
        logger.error(`WindowRect`, `Failed to set the window layout to full-screen mode., ${err}`)
      });

      // 获取布局避让遮挡的区域
      this.avoidManager = new AvoidanceManager(windowClass, UIContext);
      await this.avoidManager.init();
      // 注册监听器，当避让值变化时，更新UI状态
      this.avoidManager.onChangeListener(this.avoidListener);
      logger.info('WindowRect', 'Manager initialized and listener registered.');

      // 初始化窗口尺寸与断点
      this.initWindowDimensions(windowClass, UIContext);

      // 注册窗口状态监听器
      this.registerWindowListeners(windowClass, UIContext);

    } catch (error) {
      logger.error(`WindowChange`, `#intRectWindow Failed to getMainWindowSync., ${error}`)
    }
  }

  /**
   * 初始化窗口尺寸与断点计算
   */
  private initWindowDimensions(windowClass: window.Window, UIContext: UIContext) {
    try {
      let properties = windowClass.getWindowProperties()
      let rect = properties.windowRect
      let WindowHeight = UIContext.px2vp(rect.height)
      let WindowWidth = UIContext.px2vp(rect.width)
      const widthBp: WidthBreakpoint = UIContext.getWindowWidthBreakpoint()

      _PixState.window = windowClass;
      _PixState.windowWidth_px = rect.width;
      _PixState.windowHeight_px = rect.height;
      PixState.widthBp = widthBp
      PixState.windowHeight = WindowHeight
      PixState.windowWidth = WindowWidth
      logger.info('WindowRect', `窗口高度：${rect.height} px 宽度：${rect.width} px`)

      // 初始化设备窗口模式
      this.onWindowModeChange(windowClass)
    } catch (error) {
      logger.error(`WindowDimensions`, `Failed to getWindowProperties., ${error}`)
    }
  }

  /**
   * 注册窗口大小与模式变化监听
   */
  private registerWindowListeners(windowClass: window.Window, UIContext: UIContext) {
    // 监听窗口大小变化
    windowClass.on('windowSizeChange', async (data) => {
      logger.info('WindowChange', 'Succeeded in enabling the listener for window size changes. Data: ' + JSON.stringify(data))
      let WindowWidth = UIContext.px2vp(data.width)!
      let WindowHeight = UIContext.px2vp(data.height)!

      PixState.windowHeight = WindowHeight
      PixState.windowWidth = WindowWidth
      _PixState.windowWidth_px = data.width;
      _PixState.windowHeight_px = data.height;

      this.onWidthBpChange(UIContext)
      this.onHeightBpChange(WindowHeight, WindowWidth)
    });

    // 窗口模式状态监听
    try {
      windowClass.on('freeWindowModeChange', (data) => {
        PixState.windowMode = data
        this.onWindowModeChange(windowClass)
        console.debug(`WindowMode 当前窗口状态：${PixState.windowMode}`)
      });
    } catch (exception) {
      console.error(`Failed to enable the listener for free window mode changes. Cause code: ${exception.code}, message: ${exception.message}`);
    }
  }

  onWidthBpChange(UIContext: UIContext) {
    const widthBp: WidthBreakpoint = UIContext.getWindowWidthBreakpoint();
    PixState.widthBp = widthBp
  }

  onHeightBpChange(WindowHeight: number, WindowWidth: number) {
    let heightBp = 0
    const WindowAspectRatio = WindowHeight / WindowWidth
    // 重写高度断点
    if (WindowAspectRatio < BREAKPOINT_RATIO_LANDSCAPE) {
      heightBp = 0
      logger.debug('Layout', `断点测试 heightBp: ${heightBp} 高宽比：${WindowAspectRatio}`)
    } else if (WindowAspectRatio >= BREAKPOINT_RATIO_LANDSCAPE && WindowAspectRatio < BREAKPOINT_RATIO_PORTRAIT) {
      heightBp = 1
      logger.debug('Layout', `断点测试 heightBp: ${heightBp} 高宽比：${WindowAspectRatio}`)
    } else if (WindowAspectRatio >= BREAKPOINT_RATIO_PORTRAIT) {
      heightBp = 2
      logger.debug('Layout', `断点测试 heightBp: ${heightBp} 高宽比：${WindowAspectRatio}`)
    }
    PixState.heightBp = heightBp
  }

  async onWindowModeChange(windowClass: window.Window) {
    try {
      // 设置默认标题栏是否显示
      windowClass.setWindowDecorVisible(false)
      // 设置默认标题栏功能按钮是否显示
      windowClass.setWindowTitleButtonVisible(true, true, true)
      // 全屏时鼠标移动至顶部不显示标题栏和dock栏，平板自由多窗则是无法唤起状态栏
      await windowClass.setTitleAndDockHoverShown(false, false)
      try {
        if (this.isFirstStart) {
          PixState.windowMode = windowClass.isInFreeWindowMode()
          this.isFirstStart = false
        }
      } catch (exception) {
        console.error(`WindowMode Failed to change the window limits. Cause code: ${exception.code}, message: ${exception.message}`);
      }
      logger.info("WindowMode", `当前为PC窗口模式 bottom: ${PixState.bottomRectHeight} mode: ${PixState.windowMode}`)
    } catch (exception) {
      logger.error("WindowMode", `#onWindowModeChange error: ${JSON.stringify(exception)}`)
      logger.info("WindowMode", `当前为普通窗口模式 bottom: ${PixState.bottomRectHeight} mode: ${PixState.windowMode}`)
    }
  }

}
