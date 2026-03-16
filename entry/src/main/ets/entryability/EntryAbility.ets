import { AbilityConstant, common, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { preferenceUtil } from '../utils/PreferenceUtil';
import { kvDbUtil } from '../utils/KVdbUtil';
import { toastUtil } from '../utils/ToastUtils';
import { BusinessError } from '@kit.BasicServicesKit';
import { AvoidanceManager, SmartAvoidance } from '../utils/AvoidManager';
import { PixState, _PixState } from './AppState';
import { Logger } from '../utils/Logger';
import { ImageKnife } from '@ohos/imageknifepro';
import { ezCustomTransition } from '@hmanimations/ezcustomtransition';


const logger = Logger.getInstance();
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
      logger.info('Init', 'preferenceUtil and kvDbUtil initialized successfully.');
    } catch (error) {
      logger.error('Init', 'preferenceUtil or kvDbUtil initialization failed.', error);
    }
    try {
      const color_mode = await preferenceUtil.get<ConfigurationConstant.ColorMode>('color_mode', ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
      logger.info('ColorMode', `保存的颜色模式：${color_mode}`);
      this.context.getApplicationContext().setColorMode(color_mode);
    } catch (err) {
      logger.error('ColorMode', 'Failed to set colorMode.', err);
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
        logger.error('WindowStage', 'Failed to load the content.', err);
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
        logger.error('WindowStage', 'Failed to get the Main Window.', error);
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
        logger.error('WindowRect', 'Failed to set the window layout to full-screen mode.', err);
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
        logger.error('WindowChange', `#intRectWindow Failed to getWindowProperties.`, error)
      }
    } catch (error) {
      logger.error('WindowChange', `#intRectWindow Failed to getMainWindowSync.`, error)
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
