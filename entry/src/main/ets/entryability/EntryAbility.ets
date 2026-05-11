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


const logger = createLogger('EntryAbility')
const BREAKPOINT_RATIO_LANDSCAPE = 0.79;
const BREAKPOINT_RATIO_PORTRAIT = 1.2;

export default class EntryAbility extends UIAbility {

  private avoidManager: AvoidanceManager | undefined = undefined;
  private avoidListener: (avoidance: SmartAvoidance) => void = (newAvoidance) => {
    PixState.bottomRectHeight = newAvoidance.bottom
    PixState.topRectHeight = newAvoidance.top
    PixState.leftAvoidWidth = newAvoidance.left
    PixState.rightAvoidWidth = newAvoidance.right
  }

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    try {
      // 初始化首选项
      await preferenceUtil.init(this.context, 'pixark_preference');
      // 初始化KV数据库
      await kvDbUtil.initKVManager(this.context, 'pixark')
      // 加载设置数据
      await appSettings.load()
      // 初始化账号信息
      await this.initAccounts()
      // 注册数据获取事件
      EventHub.on(EventKey.FetchData, () => {
        this.loadData()
      })
      // 加载一次数据
      this.loadData()
      logger.info('Init', 'preferenceUtil and kvDbUtil initialized successfully.');
    } catch (error) {
      logger.error(`'Init, preferenceUtil or kvDbUtil initialization failed, ${error}`)
    }
    try {
      const color_mode = await preferenceUtil.get<ConfigurationConstant.ColorMode>('color_mode', ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
      logger.info('ColorMode', `保存的颜色模式：${color_mode}`);
      this.context.getApplicationContext().setColorMode(color_mode);
    } catch (err) {
      logger.error(`'ColorMode, Failed to set colorMode, ${err}`)
    }
    _PixState.Context = this.context
    // 初始化 ImageKnife 文件缓存
    await ImageKnife.getInstance().initFileCache(this.context, 256, 256 * 1024 * 1024);
    // 全局添加 Pixiv 必需的 Referer
    ImageKnife.getInstance().addHeader('Referer', 'https://www.pixiv.net/') ;
    logger.info('Lifecycle', 'EntryAbility onCreate End');
  }

  onDestroy(): void {
    logger.info('Lifecycle', 'EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    logger.info('Lifecycle', 'EntryAbility onWindowStageCreate');
    ezCustomTransition.init(windowStage)
    windowStage.loadContent('pages/Index', async (err) => {
      if (err.code) {
        logger.error(`'WindowStage, Failed to load the content., ${err}`)
        return;
      }
      try {
        const data = await windowStage.getMainWindow()
        // 初始化通知工具
        toastUtil.initContext(data.getUIContext(), data.getUIContext().getHostContext() as common.UIAbilityContext)
        // 初始化 window
        this.intRectWindow(windowStage, data.getUIContext())
        // 初始化UI上下文
        _PixState.UIContext = data.getUIContext()
      } catch (error) {
        logger.error(`'WindowStage, Failed to get the Main Window, ${error}`)
      }
      logger.info('WindowStage', 'Succeeded in loading the content.');
    });
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    ezCustomTransition.onConfigurationChanged()
  }

  onWindowStageWillDestroy(windowStage: window.WindowStage): void {
    // Main window will destroy, release UI related resources
    // 销毁避让管理器并移除监听
    if (this.avoidManager) {
      this.avoidManager.offChangeListener(this.avoidListener);
      this.avoidManager.destroy();
      this.avoidManager = undefined;
    }
    logger.info('Lifecycle', 'EntryAbility onWindowStageWillDestroy');
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    logger.info('Lifecycle', 'EntryAbility onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    logger.info('Lifecycle', 'EntryAbility onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    logger.info('Lifecycle', 'EntryAbility onBackground');
  }

  async initAccounts() {
    let savedAccounts: AccountContext[] = [];
    let lastActiveUserId = '';

    // 增加防时序重试机制，解决 KVStore 底层初始化的微秒级延迟
    let retryCount = 3;
    while (retryCount > 0) {
      try {
        const accountsJson = await kvDbUtil.getData<string>('pixiv_accounts', '[]');
        savedAccounts = JSON.parse(accountsJson) as AccountContext[];
        lastActiveUserId = await kvDbUtil.getData<string>('active_user_id', '');
        break; // 读取成功，跳出循环
      } catch (dbError) {
        retryCount--;
        if (retryCount > 0) {
          logger.warn('InitAccounts', `KVStore not ready, waiting 100ms... (${3 - retryCount}/3)`);
          // 延迟重试
          await new Promise<void>((resolve: (value: void) => void) => {
            setTimeout(() => resolve(), 100);
          });
        } else {
          // 3次都失败，说明真的有问题，只能放弃本次初始化
          logger.error('InitAccounts', `KVStore failed after 3 retries: ${dbError?.message}`);
          return;
        }
      }
    }

    try {
      // 兼容老版本：如果找不到多账号数据，尝试读取旧的单 token
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
        // 正常的多账号初始化
        pixiv.initAccounts(savedAccounts, lastActiveUserId);
        logger.info('InitAccounts', `Multi-account initialized. Count: ${savedAccounts.length}`);

        // 后台静默刷新当前激活账号的 Token
        const activeAccount = pixiv.getActiveAccount();
        if (activeAccount?.refreshToken) {
          try {
            logger.info('InitAccounts', 'Silently refreshing active token in background...');
            const updatedAccount = await pixiv.loginWithRefreshToken(activeAccount.refreshToken);
            const index = savedAccounts.findIndex((a: AccountContext) => a.userId === updatedAccount.userId);
            if (index !== -1) savedAccounts[index] = updatedAccount;
            await kvDbUtil.putData('pixiv_accounts', JSON.stringify(savedAccounts));
            logger.info('InitAccounts', 'Silent refresh successful.');
          } catch (refreshError) {
            logger.warn('InitAccounts', `Silent refresh failed: ${JSON.stringify(refreshError)}`);
          }
        }
      }
    } catch (e) {
      logger.error('InitAccounts', `Account logic error: ${e?.message || JSON.stringify(e)}`);
    }
  }

  // 加载数据
  async loadData() {
    PixState.isLoading = true;
    // 开始初始化，标记为 true，显示过渡页
    PixState.isInitializing = true;
    try {
      if (!PixState.isTest) {
        // 直接检查是否登录即可 (Token 已在 onCreate 加载完成)
        if (pixiv.isLogin()) {
          PixState.isLoggedIn = true;

          // 获取当前用户信息 (直接从内存拿，速度极快)
          const currentUser = pixiv.getCurrentUser();
          if (currentUser) {
            PixState.currentUser = currentUser;

            // 补全详细信息的逻辑保留
            const email = currentUser.mail_address;
            if (!currentUser.profile_image_urls?.medium) {
              logger.warn('User 没有用户头像链接，重新获取详细信息');
              const full = await pixiv.getUserDetail(currentUser.id);
              PixState.currentUserDetail = full;
              PixState.currentUser = full.user;
              PixState.currentUser.mail_address = email;
              // 同步更新 PixivAuth 内部状态
              pixiv.updateAccountUser(currentUser.id.toString(), PixState.currentUser);
              // 持久化到本地数据库
              const allAccounts = pixiv.getAllAccounts();
              await kvDbUtil.putData('pixiv_accounts', JSON.stringify(allAccounts));
            }

          }
          // 加载主页内容 (因为拦截器存在，不用操心 Token 过期问题)
          homeViewModel.loadHomeData();
        } else {
          // 没登录就是没登录，不用再尝试 token 登录了
          logger.warn('User not logged in, redirecting to login.');
          PixState.isLoggedIn = false
        }
      } else {
        // 测试模式
        await homeViewModel.loadHomeData()
        PixState.isLoggedIn = true
      }
    } catch (e) {
      logger.error('Load data error: ' + e.message);
    } finally {
      // 统一关闭 Loading
      PixState.isLoading = false;
      PixState.isInitializing = false
    }
  }

  // 初始化窗口
  async intRectWindow(windowStage: window.WindowStage, UIContext: UIContext) {
    // 设置自动记忆最后关闭的窗口大小(仅2in1设备生效)
    try {
      await windowStage.setWindowRectAutoSave(true);
      logger.info("WindowAutoSave", 'Succeeded in setting window rect auto-save')
    } catch (exception) {
      logger.error("WindowAutoSave", `Failed to set window rect auto-save. Cause code: ${exception.code} smessage: ${exception.message}` )
    }
    // 获取应用主窗口
    try {
      const windowClass: window.Window = windowStage.getMainWindowSync();
      // 设置窗口全屏
      windowClass.setWindowLayoutFullScreen(true).then(() => {
        logger.info('WindowRect', 'Succeeded in setting the window layout to full-screen mode.');
      }).catch((err: BusinessError) => {
        logger.error(`'WindowRect, Failed to set the window layout to full-screen mode., ${err}`)
      });

      // 获取布局避让遮挡的区域
      this.avoidManager = new AvoidanceManager(windowClass, UIContext);
      await this.avoidManager.init();
      // 注册监听器，当避让值变化时，更新UI状态
      this.avoidManager.onChangeListener(this.avoidListener);
      logger.info('WindowRect', 'Manager initialized and listener registered.');

      // 应用窗口初始高度和宽度
      try {
        let properties = windowClass.getWindowProperties()
        let rect = properties.windowRect
        let WindowHeight = UIContext.px2vp(rect.height)
        let WindowWidth = UIContext.px2vp(rect.width)
        const widthBp: WidthBreakpoint = UIContext.getWindowWidthBreakpoint()
        // 获取窗口宽度和高度
        _PixState.window = windowStage.getMainWindowSync();
        _PixState.windowWidth_px = rect.width;
        _PixState.windowHeight_px = rect.height;
        PixState.widthBp = widthBp
        PixState.windowHeight = WindowHeight
        PixState.windowWidth = WindowWidth
        logger.info('WindowRect', `窗口高度：${rect.height} px 宽度：${rect.width} px`)
        // 初始化设备窗口模式
        // this.onWindowModeChange(windowStage, windowClass)
        // 监听窗口大小变化
        windowClass.on('windowSizeChange', async (data) => {
          // 动态监听设备窗口模式
          this.onWindowModeChange(windowStage, windowClass)
          logger.info('WindowChange', 'Succeeded in enabling the listener for window size changes. Data: ' + JSON.stringify(data))
          WindowWidth = UIContext.px2vp(data.width)!
          WindowHeight = UIContext.px2vp(data.height)!
          // 980px 约等于 512vp
          PixState.windowHeight = WindowHeight
          PixState.windowWidth = WindowWidth
          _PixState.windowWidth_px = data.width;
          _PixState.windowHeight_px = data.height;
          // 动态监听断点
          this.onWidthBpChange(UIContext)
          this.onHeightBpChange(WindowHeight, WindowWidth)
        })
      } catch (error) {
        logger.error(`'WindowChange, #intRectWindow Failed to getWindowProperties., ${error}`)
      }
    } catch (error) {
      logger.error(`'WindowChange, #intRectWindow Failed to getMainWindowSync., ${error}`)
    }
  }

  onWidthBpChange(UIContext: UIContext) {
    const widthBp: WidthBreakpoint = UIContext.getWindowWidthBreakpoint();
    PixState.widthBp = widthBp
  }

  onHeightBpChange(WindowHeight: number, WindowWidth: number) {
    let heightBp = 0
    const WindowAspectRatio = WindowHeight / WindowWidth // 重写高度断点
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

  async onWindowModeChange(windowStage: window.WindowStage, windowClass: window.Window) {
    try {
      // 设置默认标题栏是否显示
      windowClass.setWindowDecorVisible(false)
      // 设置默认标题栏功能按钮是否显示
      windowClass.setWindowTitleButtonVisible(true, true, true)
      // 全屏时鼠标移动至顶部不显示标题栏和dock栏，平板自由多窗则是无法唤起状态栏
      await windowClass.setTitleAndDockHoverShown(false, false)
      /*      try {
              if (this.isFirstStart) {
                const systemLimits = windowClass.getWindowLimits()
                this.windowLimits.maxWidth = systemLimits.maxWidth
                this.windowLimits.maxHeight = systemLimits.maxHeight
                this.isFirstStart = false
              }
              console.info(`WindowMode  the window limits. FirstLimits: ${JSON.stringify(this.windowLimits)}`);
              let promise = windowClass.setWindowLimits(this.windowLimits, true);
              promise.then((data) => {
                console.info(`WindowMode Succeeded in changing the window limits. limits: ${JSON.stringify(data)}`);
              }).catch((err: BusinessError) => {
                console.error(`WindowMode Failed to change the window limits. Cause code: ${err.code}, message: ${err.message}`);
              });
            } catch (exception) {
              console.error(`WindowMode Failed to change the window limits. Cause code: ${exception.code}, message: ${exception.message}`);
            }*/
      // 设置标题栏高度
      PixState.windowMode = true
      logger.info("WindowMode", `当前为PC窗口模式 bottom: ${PixState.bottomRectHeight} mode: ${PixState.windowMode}`)
    } catch (exception) {
      logger.error("WindowMode", `#onWindowModeChange error: ${JSON.stringify(exception)}`)
      PixState.windowMode = false
      logger.info("WindowMode", `当前为普通窗口模式 bottom: ${PixState.bottomRectHeight} mode: ${PixState.windowMode}`)
    }
  }

}
