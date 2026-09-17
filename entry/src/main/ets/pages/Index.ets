import { PixState, _PixState } from '../entryability/AppState';
import { TabBarAlignItems, TabBarJustifyContent, TabIconFontSize, TabBarPosition,
  TabTitleFontSize,
  TabBarWidth,
  WindowTabBarWidth } from '../common/utils/breakpoint/BreakPoint';
import { curves, LengthMetrics } from '@kit.ArkUI';
import { hdsMaterial, HdsTabs, HdsTabsAttribute, HdsTabsFloatingStyle } from '@kit.UIDesignKit';
import { animation } from '../common/utils/AnimationUtil';
import { TabBuild } from '../common/entity/IndexEntity';
import { Home } from './Home';
import { SearchPage } from './Search';
import { Favorite } from './Favorite';
import { Rank } from './Rank';
import { homeViewModel } from '../viewmodel/HomeViewModel';
import { Login } from './Login';
import UIConstants from '../common/constants/UIConstants';
import { More } from './More';
import { createLogger } from '../common/utils/Logger';
import { appSettings, UISettings } from '../common/entity/SettingsModel';
import { motion } from '@kit.MultimodalAwarenessKit';
import { HoldingHandleUtil } from '../common/utils/HoldingHandleUtil';


const logger = createLogger('Index')

/** 底栏几何（barWidth/barHeight）：仅竖排侧栏模式设置；底部悬浮交给 HDS 自行布局 */
class TabBarLayoutModifier implements AttributeModifier<HdsTabsAttribute> {
  applyNormalAttribute(instance: HdsTabsAttribute): void {
    if (PixState.TabBarVertical) {
      instance.barWidth(PixState.windowMode
        ? WindowTabBarWidth(PixState.widthBp, PixState.heightBp)
        : TabBarWidth(PixState.widthBp, PixState.heightBp));
      instance.barHeight(PixState.TabBarHeight);
    }
  }
}


@Entry
@ComponentV2
struct Index {

  @Local isEnabled: boolean = true

  /** 底栏几何 modifier（按形态条件设置 barWidth/barHeight） */
  private tabBarLayout: TabBarLayoutModifier = new TabBarLayoutModifier();

  // 允许自定义转换的页面的名称 自
  private allowedCustomTransitionFromPageNames: string[] =
    ['illust_detail',
    ];
  // 允许自定义转换的页面的名称 至
  private allowedCustomTransitionToPageNames: string[] =
    ['illust_detail',
    ];

  aboutToAppear() {
    logger.debug('Page aboutToAppear');
    // 启动适人握持
    HoldingHandleUtil.start((status: motion.HoldingHandStatus) => {
      this.handleHoldingStatusChange(status);
    })
  }

  aboutToDisappear(): void {
    // 停止适人握持
    HoldingHandleUtil.stop()
  }

  build() {
    // 存在账号信息显示内容
    if (PixState.isLoggedIn) {
      Navigation(PixState.pageStack) {
        this.MainContent()
      }
      .height('100%')
      .width('100%')
      .hideToolBar(true)
      .hideTitleBar(true)
      .mode(NavigationMode.Stack)
      .transition(TransitionEffect.OPACITY)
      // TODO 实现图片流一镜到底转场
/*      .customNavContentTransition((from: NavContentInfo, to: NavContentInfo, operation: NavigationOperation) => {
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
      })*/
    }
    // 未登录显示登录页
    else {
      Login({ mode: 'main' })
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
      // 竖排侧栏沿用原布局；底部悬浮胶囊内图标文字垂直居中
      justifyContent: PixState.TabBarVertical
        ? TabBarJustifyContent(PixState.widthBp, PixState.heightBp)
        : FlexAlign.Center,
      alignItems: PixState.windowMode ? ItemAlign.Center : TabBarAlignItems(PixState.widthBp, PixState.heightBp),
      space: { main: LengthMetrics.vp(3) }
    })
    {
      SymbolGlyph(PixState.currentTab === index ? currentTabIcon : tabIcon)
        .fontColor([PixState.currentTab === index ? PixState.currentThemeColor : $r('sys.color.font_primary')])
        .renderingStrategy(SymbolRenderingStrategy.MULTIPLE_OPACITY) // 分层颜色
        .fontSize(TabIconFontSize(PixState.widthBp, PixState.heightBp))
      Text(title)
        .fontColor(PixState.currentTab === index ? PixState.currentThemeColor : $r('sys.color.font_primary'))
        .fontWeight(FontWeight.Medium)
        .fontSize(TabTitleFontSize(PixState.widthBp, PixState.heightBp))
        .transition(animation.isTranslate())
    }
    .width('100%')
    .height('100%')
    .padding({ top: PixState.TabBarVertical ? 8 : 0 })
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
          if (PixState.currentTab == 0) {
            // 双击刷新主页推荐图片数据
            homeViewModel.refreshRecommended()
          }
        })
    );
  }
  @Builder
  CustomTab() {
    HdsTabs({
      barPosition: TabBarPosition(PixState.widthBp, PixState.heightBp),
      controller: PixState.tabsController
    }) {
      ForEach(this.getTabList(), (item: TabBuild, index: number) => {
        TabContent() {
          this.TabContentBuilder(index)
        }
        .tabBar(this.CustomTabBarBuilder(item.title, index, item.icon, item.icon_fill))
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
    // 底栏几何：仅竖排侧栏设置 barWidth/barHeight；底部悬浮交给 HDS 自行布局（与 NextE 一致）
    .attributeModifier(this.tabBarLayout)
    // 底栏模糊：竖排用原 Thin；底部悬浮由 HDS 系统材质（systemMaterialEffect）接管
    .barBackgroundBlurStyle(PixState.TabBarVertical ? BlurStyle.Thin : BlurStyle.NONE)
    .backgroundColor($r('sys.color.background_primary'))
    .barOverlap(!PixState.TabBarVertical)
    .barMode(BarMode.Fixed)
    .vertical(PixState.TabBarVertical)
    // ── 悬浮胶囊：仅底部模式启用（竖排侧栏保持原贴边样式） ──
    .barFloatingStyle(PixState.FloatBarEnabled
      ? ({
        barBottomMargin: PixState.FloatBarBottomMargin,
        barSideMargin: 16,
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      } as HdsTabsFloatingStyle)
      : undefined)
    .onTabBarClick((index: number) => {
      animation.animTo(() => {
        PixState.currentTab = index
      }, UIConstants.AnimationSpeed_300, 'app', 0)
    })
    .onAnimationStart((index: number, targetIndex: number) => {
      animation.animTo(() => {
        PixState.currentTab = targetIndex;
      }, UIConstants.AnimationSpeed_300, 'app', 0)
    })
    .onAppear(() => {
      PixState.tabsController.changeIndex(Number(UISettings.main_show))
    })
    .width('100%').height('100%')
    .margin({ top: PixState.windowMode ? 42 : 0 })
    .padding({ top: PixState.topRectHeight })
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
      More()
    }
  }

  getTabList(): TabBuild[] {
    const tabList: TabBuild[] = [
      { name: 'home', title: $r('app.string.home'), icon: $r('sys.symbol.house'), icon_fill: $r('sys.symbol.house_fill') },
      { name: 'rank', title: $r('app.string.rank'), icon: $r('sys.symbol.ranking_badge_bolt'), icon_fill: $r('sys.symbol.ranking_badge_bolt') },
      { name: 'favorite', title: $r('app.string.favorite'), icon: $r('sys.symbol.heart'), icon_fill: $r('sys.symbol.heart_fill') },
      { name: 'search', title: $r('app.string.search'), icon: $r('sys.symbol.curve_magnifyingglass'), icon_fill: $r('sys.symbol.AI_search') },
      { name: 'more', title: $r('app.string.more'), icon: $r('sys.symbol.square_grid_2x2'), icon_fill: $r('sys.symbol.square_fill_grid_2x2') }
    ]
    return tabList
  }

  // 处理握持状态变化的业务逻辑
  private handleHoldingStatusChange(status: motion.HoldingHandStatus) {
    let targetIndex = 0; // 默认右手/未握持
    switch (status) {
      case motion.HoldingHandStatus.LEFT_HAND_HELD:
        targetIndex = 2; // 左手 -> 左侧
        break;
      case motion.HoldingHandStatus.BOTH_HANDS_HELD:

        break;
      case motion.HoldingHandStatus.RIGHT_HAND_HELD:
      case motion.HoldingHandStatus.NOT_HELD:
      default:
        targetIndex = 0; // 右手/未握持 -> 右侧
        break;
    }
    // 执行动画和状态更新
    _PixState.UIContext.animateTo({ duration: 350, curve: curves.springMotion() }, () => {
      // 更新持久化配置
      PixState.buttonPosition = targetIndex;
    }
    );
    logger.debug(`握持逻辑触发: ${status}, 按钮位置:${targetIndex}`);
  }

  private isCustomTransitionEnabled(fromName: string, toName: string): boolean {
    // 点击和返回都需要自定义过渡，因此分别判断
    if ((this.allowedCustomTransitionFromPageNames.includes(fromName)
      && this.allowedCustomTransitionToPageNames.includes(toName))
      || (this.allowedCustomTransitionFromPageNames.includes(toName)
        && this.allowedCustomTransitionToPageNames.includes(fromName))) {
      return true;
    }
    return false;
  }

}


