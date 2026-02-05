
import { createLogger } from '../utils/Logger';
import { PixState } from '../entryability/AppState';
import { EventHub, EventKey } from '../utils/EventHub';
import { toastUtil } from '../utils/ToastUtils';
import { kvDbUtil } from '../utils/KVdbUtil';
import { TabBarAlignItems, TabBarJustifyContent, TabIconFontSize, TabBarPosition,
  TabTitleFontSize,
  TabBarWidth,
  WindowTabBarWidth,
  TabBarHeight,
  TabBarAvoidHeight,
  Window_BAR_HEIGHT} from '../utils/breakpoint/BreakPoint';
import { LengthMetrics } from '@kit.ArkUI';
import { animation } from '../utils/AnimationUtil';
import { TabBuild } from '../entity/IndexEntity';
import { Home } from './Home';
import { SearchPage } from './Search';
import { Favorite } from './Favorite';
import { Rank } from './Rank';
import { homeViewModel } from '../viewmodel/HomeViewModel';
import { Login } from './Login';
import Constants from '../entity/Constants';
import { AnimateCallback, CustomTransition } from '../utils/customtransition/CustomNavigationUtils';
import { ezCustomTransition } from '@hmanimations/ezcustomtransition';

const logger = createLogger('Index')

@Entry
@ComponentV2
struct Index {

  @Local isEnabled: boolean = true

  // 允许自定义转换的页面的名称 自
  private allowedCustomTransitionFromPageNames: string[] =
    ['illust_detail',
    ];
  // 允许自定义转换的页面的名称 至
  private allowedCustomTransitionToPageNames: string[] =
    ['illust_detail',
    ];

  aboutToAppear() {
    logger.info('Page aboutToAppear');
    // 初始化动画
    animation.init(this.getUIContext())
    EventHub.on(EventKey.FetchData, () => {
      this.loadData()
    })
    // 首次进入刷新数据
    setTimeout(() => {
      this.loadData()
    }, 600)
  }

  build() {
    // 初始化中，显示过渡界面
    if (PixState.isInitializing) {
      // Logo
      this.LogoStartLoading()
    }
    // 已登录显示内容
    else if (PixState.isLoggedIn) {
      Navigation(PixState.pageStack) {
        this.MainContent()
      }
      .hideToolBar(true)
      .hideTitleBar(true)
      // .enabled(this.isEnabled) // 转场过程中不响应手势事件
      .mode(NavigationMode.Stack)
      .transition(TransitionEffect.OPACITY)
      .customNavContentTransition((from: NavContentInfo, to: NavContentInfo, operation: NavigationOperation) => {
        if ((!from || !to) || (!from.name || !to.name) || (!from.navDestinationId || !to.navDestinationId)) {
          return undefined;
        }
        let fromParam: AnimateCallback = CustomTransition.getInstance().getAnimateParam(from.navDestinationId);
        let toParam: AnimateCallback = CustomTransition.getInstance().getAnimateParam(to.navDestinationId);
        CustomTransition.getInstance().operation = operation;
        // Follow the hand interaction transition.
        if (CustomTransition.getInstance().isInteractive) {
          let customAnimation: NavigationAnimatedTransition = {
            onTransitionEnd: () => {
              this.isEnabled = true;
              CustomTransition.getInstance().recoverState();
              CustomTransition.getInstance().proxy = undefined;
            },
            transition: (transitionProxy: NavigationTransitionProxy) => {
              CustomTransition.getInstance().proxy = transitionProxy;
              this.isEnabled = false;
              if (fromParam.onInteractive) {
                fromParam.onInteractive();
              }
              if (toParam.onInteractive) {
                toParam.onInteractive();
              }
            },
            isInteractive: true
          };
          return customAnimation;
        }

        // User-defined transition routes are controlled by the from and to names.
        if (!this.isCustomTransitionEnabled(from.name, to.name)) {
          return undefined;
        }

        // For the scene where button A is clicked to go to the custom transition and button B is clicked to go to the default transition,
        // it is necessary to judge whether the animation is registered to decide whether to go to the custom transition.
        // fromPage and toPage registerNavParam do not pass animation parameters, go to the default transition.
        if (!fromParam.animation && !toParam.animation) {
          return undefined;
        }

        // After all judgments are completed, construct customAnimation to the system side call, execute the custom transition animation.
        let customAnimation: NavigationAnimatedTransition = {
          onTransitionEnd: (isSuccess: boolean) => {
            logger.debug(`current transition result is ${isSuccess}`);
            this.isEnabled = true;
          },
          timeout: 1000,
          transition: (transitionProxy: NavigationTransitionProxy) => {
            this.isEnabled = false;
            if (fromParam.animation) {
              fromParam.animation(transitionProxy);
            }
            if (toParam.animation) {
              toParam.animation(transitionProxy);
            }
          }
        };
        return customAnimation;
      })
    }
    // 未登录显示登录页
    else {
      Navigation(PixState.pageStack) {
        Login()
      }
      .height('100%')
      .width('100%')
      .hideToolBar(true)
      .hideTitleBar(true)
      .mode(NavigationMode.Stack)
    }
  }

  @Builder
  MainContent() {
    Stack() {
      if (PixState.isLoading) {
        LoadingProgress()
          .width(40)
          .height(40)
          .margin({ bottom: 12 });
      }
      this.CustomTab()
    }
    .height('100%')
    .width('100%')
  }

  @Builder
  LogoStartLoading() {
    Column() {
      Image($r('app.media.app_icon_round'))
        .height(106)
        .margin({ bottom: 20 })

      LoadingProgress()
        .width(40)
        .height(40)
        .color($r('sys.color.brand'))

      Text('正在初始化...')
        .fontSize(14)
        .fontColor('#999')
        .margin({ top: 10 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('app.color.start_window_background'))
  }

  @Builder
  TabBarButton(title: ResourceStr, index: number, tabIcon?: Resource, currentTabIcon?: Resource) {
    Flex({
      direction: FlexDirection.Column,
      justifyContent: TabBarJustifyContent(PixState.widthBp, PixState.heightBp),
      alignItems: PixState.windowMode ? ItemAlign.Center : TabBarAlignItems(PixState.widthBp, PixState.heightBp),
      space: { main: LengthMetrics.vp(3) }
    })
    {
      SymbolGlyph(PixState.currentTab === index ? currentTabIcon : tabIcon)
        .fontColor([PixState.currentTab === index ? PixState.CurrentAppThemeColor : $r('sys.color.font_primary')])
        .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY) // 分层颜色
        .fontSize(TabIconFontSize(PixState.widthBp, PixState.heightBp))
        .transition(animation.isTranslate())
        .translate({ y: PixState.currentTab == index ? -3 : 0 })
      Text(title)
        .fontColor(PixState.currentTab === index ? PixState.CurrentAppThemeColor : $r('sys.color.font_primary'))
        .fontWeight(FontWeight.Medium)
        .fontSize(TabTitleFontSize(PixState.widthBp, PixState.heightBp))
        .transition(animation.isTranslate())
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8 })
  }
  @Builder
  CustomTabBarBuilder(title: ResourceStr, index: number, tabIcon?: Resource, currentTabIcon?: Resource) {
    // 绑定双击事件
    Column() {
      this.TabBarButton(title, index, tabIcon, currentTabIcon)
    }
    .gesture(
      TapGesture({ count: 2 })
        .onAction(() => {
          // 双击刷新主页推荐图片数据
          homeViewModel.refreshRecommended()
        })
    );
  }
  @Builder
  CustomTab() {
    Tabs({
      barPosition: TabBarPosition(PixState.widthBp, PixState.heightBp),
      controller: PixState.tabsController
    }) {
      ForEach(this.getTabList(), (item: TabBuild, index: number) => {
        TabContent() {
          this.TabContentBuilder(index)
        }
        .tabBar(this.CustomTabBarBuilder(item.name, index, item.icon, item.icon_fill))
        .gesture(
          // 二级Tabs第一个页签向左拖动时，触发手势事件，当Tab栏竖排时不触发
          PanGesture({
            direction: !PixState.TabBarVertical ? PanDirection.Down : PanDirection.None
          })
            .onActionStart((event?: GestureEvent) => {
              console.info('Pan start')
            })
            // 通过Tab组件的TabsController的实例，改变其index，达到跳转一级Tabs的效果
            .onActionEnd(() => {
              if (PixState.windowHeight > PixState.windowWidth) {
                if (PixState.currentTab == 0) {
                  PixState.tabsController.changeIndex(1)
                  console.debug('Pan end')
                }
              }
            }))
      })
    }
    .zIndex(1)
    .backgroundColor($r('sys.color.background_primary'))
    .barOverlap(!PixState.TabBarVertical)
    .barBackgroundBlurStyle(!PixState.TabBarVertical ? BlurStyle.Thin : undefined)
    .vertical(PixState.TabBarVertical)
    .barWidth(PixState.windowMode ? WindowTabBarWidth(PixState.widthBp, PixState.heightBp) : TabBarWidth(PixState.widthBp, PixState.heightBp))
    .barHeight(this.getBarHeight())
    .onTabBarClick((index: number) => {
      animation.animTo(() => {
        PixState.currentTab = index
      }, Constants.AnimationSpeed_300, 'app', 0)
    })
    .onAnimationStart((index: number, targetIndex: number) => {
      animation.animTo(() => {
        PixState.currentTab = targetIndex;
      }, Constants.AnimationSpeed_300, 'app', 0)
    })
    .onAppear(() => {
      PixState.tabsController.changeIndex(PixState.currentTab)
    })
    .width('100%').height('100%')
    .fadingEdge(true)
    .margin({ top: PixState.windowMode ? 42 : 0 })
    .padding({
      top: PixState.topRectHeight,
      bottom: PixState.bottomRectHeight == 0 ? PixState.bottomRectHeight / 2 : 0
    })
  }
  @Builder
  TabContentBuilder(index: number) {
    if (index == 0) {
      Home()
    } else if (index == 1) {
      Rank()
    } else if (index == 2) {
      Favorite()
    } else if (index == 3) {
      SearchPage()
    } else {
      // More()
    }
  }

  // 加载数据
  async loadData() {
    PixState.isLoading = true;
    // 开始初始化，标记为 true，显示过渡页
    PixState.isInitializing = true;
    try {
      if (!PixState.isTest) {
        // 尝试获取本地 Token
        if (!PixState.refreshToken) {
          logger.info('refresh token not found saved, trying to getData...');
          PixState.refreshToken = await kvDbUtil.getData<string>('refresh_token', '');
        }
        // 存在本地 Token 且当前未登录，尝试登录
        if (PixState.refreshToken && !PixState.pixiv.isLogin()) {
          logger.info('Found saved refresh token, trying to login...');
          try {
            await PixState.pixiv.loadRefreshToken(PixState.refreshToken);
            PixState.isLoggedIn = true;
            logger.info('Auto-login successful!');
            // 保存当前用户信息
            PixState.currentUser = PixState.pixiv.getCurrentUser()
            // 保存新的 RefreshToken
            const newToken = PixState.pixiv.getCurrentRefreshToken();
            if (newToken !== PixState.refreshToken) {
              await kvDbUtil.putData('refresh_token', newToken);
              PixState.refreshToken = newToken;
            }
          } catch (e) {
            logger.warn('Auto-login failed, token may be expired.', e);
            // 登录失败后，不再继续请求数据
            toastUtil.showToast({ message: "登录已过期，请重新登录" })
            return;
          }
        }
        // 登录成功（或者原本就处于登录状态），获取各数据
        // tips: 因为有拦截器存在，即使 Token 快过期了，getRecommended 等也会自动刷新并成功
        if (PixState.pixiv.isLogin()) {
          // 加载主页内容
          homeViewModel.loadHomeData()
        } else {
          logger.warn('User not logged in, cannot load data.');
        }
      } else {
        // 加载主页内容
        await homeViewModel.loadHomeData()
        PixState.isLoggedIn = true
      }
    } catch (e) {
      // 捕获 getRecommended 过程中的其他网络错误
      logger.error('Load data error: ' + e.message);
    } finally {
      // 统一关闭 Loading
      PixState.isLoading = false;
      PixState.isInitializing = false
    }
  }

  getTabList(): TabBuild[] {
    const tabList: TabBuild[] = [
      { name: $r('app.string.home'), icon: $r('sys.symbol.house'), icon_fill: $r('sys.symbol.house_fill') },
      { name: $r('app.string.rank'), icon: $r('sys.symbol.ranking_badge_bolt'), icon_fill: $r('sys.symbol.ranking_badge_bolt') },
      { name: $r('app.string.favorite'), icon: $r('sys.symbol.heart'), icon_fill: $r('sys.symbol.heart_fill') },
      { name: $r('app.string.search'), icon: $r('sys.symbol.curve_magnifyingglass'), icon_fill: $r('sys.symbol.AI_search') },
      { name: $r('app.string.more'), icon: $r('sys.symbol.square_grid_2x2'), icon_fill: $r('sys.symbol.square_fill_grid_2x2') }
    ]
    return tabList
  }

  getBarHeight(): number | string {
    const isVerticalTab = PixState.TabBarVertical;
    // 窗口模式 + 横向 TabBar (TabBar在底部)
    if (PixState.windowMode && !isVerticalTab) {
      return Window_BAR_HEIGHT;
    }
    // 普通窗口，不避让安全区
    if (PixState.bottomRectHeight === 0) {
      return TabBarHeight(PixState.widthBp, PixState.heightBp);
    }
    // 普通窗口，避让安全区域高度 (沉浸式 + 安全区)
    return TabBarAvoidHeight(PixState.widthBp, PixState.heightBp);
  }

  private isCustomTransitionEnabled(fromName: string, toName: string): boolean {
    // Both click and return require custom transitions, so they need to be judged separately.
    if ((this.allowedCustomTransitionFromPageNames.includes(fromName)
      && this.allowedCustomTransitionToPageNames.includes(toName))
      || (this.allowedCustomTransitionFromPageNames.includes(toName)
        && this.allowedCustomTransitionToPageNames.includes(fromName))) {
      return true;
    }
    return false;
  }

}
