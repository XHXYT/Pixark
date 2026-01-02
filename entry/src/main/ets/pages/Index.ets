
import { createLogger } from '../utils/Logger';
import { PixState } from '../entryability/AppState';
import { EventHub, EventKey } from '../utils/EventHub';
import { toastUtil } from '../utils/ToastUtils';
import { Login } from './login';
import { kvDbUtil } from '../utils/KVdbUtil';
import { TabBarAlignItems, TabBarJustifyContent, TabIconFontSize, TabBarPosition,
  TabTitleFontSize,
  TabBarVertical,
  TabBarWidth,
  WindowTabBarWidth,
  TabBarHeight,
  TabBarAvoidHeight} from '../utils/breakpoint/BreakPoint';
import { LengthMetrics } from '@kit.ArkUI';
import { animation } from '../utils/AnimationUtil';
import { TabBuild } from '../entity/IndexEntity';
import { AnimationSpeed_300 } from '../entity/Constants';
import { Home } from './Home';
import { SearchPage } from './Search';
import { Favorite } from './Favorite';
import { Rank } from './Rank';

const logger = createLogger('Index')

@Entry
@ComponentV2
struct Index {

  @Local currentTab: number = 0
  @Local isInitializing: boolean = true;

  private tabsController: TabsController = new TabsController()

  aboutToAppear() {
    logger.info('Page aboutToAppear');
    // 初始化动画
    animation.init(this.getUIContext())
    EventHub.on(EventKey.FetchData, () => {
      this.loadData()
    })
    // 页面加载时立即开始检查
    this.loadData();
  }

  build() {
    // 初始化中，显示过渡界面
    if (this.isInitializing) {
      // Logo
      this.LogoStartLoading()
    }
    // 未登录显示登录页
    else if (!PixState.isLoggedIn) {
      Login()
    }
    // 已登录显示内容
    else {
      this.MainContent()
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
  CustomTabBarBuilder(title: ResourceStr, index: number, TabIcon: Resource) {
    Flex({
      direction: FlexDirection.Column,
      justifyContent: TabBarJustifyContent(PixState.widthBp, PixState.heightBp),
      alignItems: PixState.windowMode ? ItemAlign.Center : TabBarAlignItems(PixState.widthBp, PixState.heightBp),
      space: { main: LengthMetrics.vp(3) }
    })
    {
      SymbolGlyph(TabIcon)
        .fontColor([this.currentTab === index ? PixState.CurrentAppThemeColor : $r('sys.color.font_primary')])
        .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY) // 分层颜色
        .fontSize(TabIconFontSize(PixState.widthBp, PixState.heightBp))
        .transition(animation.isTranslate())
        .translate({ y: this.currentTab == index ? -3 : 0 })
      Text(title)
        .fontColor(this.currentTab === index ? PixState.CurrentAppThemeColor : $r('sys.color.font_primary'))
        .fontWeight(FontWeight.Medium)
        .fontSize(TabTitleFontSize(PixState.widthBp, PixState.heightBp))
        .transition(animation.isTranslate())
    }
    .width('100%')
    .height('100%')
    .padding({ top: 8 })
  }
  @Builder
  CustomTab() {
    Tabs({
      barPosition: TabBarPosition(PixState.widthBp, PixState.heightBp),
      controller: this.tabsController
    }) {
      ForEach(this.getTabList(), (item: TabBuild, index: number) => {
        TabContent() {
          this.TabContentBuilder(index)
        }
        .tabBar(this.CustomTabBarBuilder(item.name, index, item.icon))
        .gesture(
          // 二级Tabs第一个页签向左拖动时，触发手势事件，当Tab栏竖排时不触发
          PanGesture({
            direction: !TabBarVertical(PixState.widthBp, PixState.heightBp) ? PanDirection.Down : PanDirection.None
          })
            .onActionStart((event?: GestureEvent) => {
              console.info('Pan start')
            })
            // 通过Tab组件的TabsController的实例，改变其index，达到跳转一级Tabs的效果
            .onActionEnd(() => {
              if (PixState.windowHeight > PixState.windowWidth) {
                if (this.currentTab == 0) {
                  this.tabsController.changeIndex(1)
                  console.info('Pan end')
                }
              }
            }))
      })
    }
    .zIndex(1)
    .backgroundColor($r('sys.color.background_primary'))
    .barOverlap(false)
    // .scrollable(!this.isSecondary)
    .vertical(TabBarVertical(PixState.widthBp, PixState.heightBp))
    .barWidth(PixState.windowMode ? WindowTabBarWidth(PixState.widthBp, PixState.heightBp) :
      TabBarWidth(PixState.widthBp, PixState.heightBp))
    .barHeight((PixState.widthBp <= 2 && !PixState.windowMode) ? TabBarHeight(PixState.widthBp, PixState.heightBp) : TabBarAvoidHeight(PixState.widthBp, PixState.heightBp))
    .onTabBarClick((index: number) => {
      animation.animTo(() => {
        this.currentTab = index
      },AnimationSpeed_300, 'app', 0)
    })
    .onChange((index) => {
      animation.animTo(() => {
        this.currentTab = index
      },AnimationSpeed_300, 'app', 0)
    })
    .onAnimationStart((index: number, targetIndex: number) => {
      animation.animTo(() => {
        this.currentTab = targetIndex;
      },AnimationSpeed_300, 'app', 0)
    })
    .onAppear(() => {
      this.tabsController.changeIndex(this.currentTab)
    })
    .width('100%').height('100%')
    .fadingEdge(true)
    .padding({ top: PixState.topRectHeight, bottom: PixState.bottomRectHeight == 0 ? PixState.bottomRectHeight / 2 : 0 })
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
    this.isInitializing = true;
    try {
      // 尝试获取本地 Token
      if (!PixState.refreshToken) {
        PixState.refreshToken = await kvDbUtil.getData<string>('refresh_token', '');
      }
      // 存在本地 Token 且当前未登录，尝试登录
      if (PixState.refreshToken && !PixState.pixiv.isLogin()) {
        logger.info('Found saved refresh token, trying to login...');
        try {
          await PixState.pixiv.loadRefreshToken(PixState.refreshToken);
          PixState.isLoggedIn = true;
          logger.info('Auto-login successful!');
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
      // 登录成功（或者原本就处于登录状态），获取推荐数据
      // tips: 因为有拦截器存在，即使 Token 快过期了，getRecommended 也会自动刷新并成功
      if (PixState.pixiv.isLogin()) {
        const rec = await PixState.pixiv.getRecommended(true);
        PixState.illustRecommends = rec.illusts;
      } else {
        logger.warn('User not logged in, cannot load data.');
      }
    } catch (e) {
      // 捕获 getRecommended 过程中的其他网络错误
      logger.error('Load data error: ' + e.message);
    } finally {
      // 统一关闭 Loading
      PixState.isLoading = false;
      this.isInitializing = false
    }
  }

  getTabList(): TabBuild[] {
    const tabList: TabBuild[] = [
      { name: $r('app.string.home'), icon: $r('sys.symbol.house_fill') },
      { name: $r('app.string.rank'), icon: $r('sys.symbol.ranking_badge_bolt') },
      { name: $r('app.string.favorite'), icon: $r('sys.symbol.folder_fill') },
      { name: $r('app.string.search'), icon: $r('sys.symbol.AI_search') },
      { name: $r('app.string.more'), icon: $r('sys.symbol.square_fill_grid_2x2') }
    ]
    return tabList
  }

}
