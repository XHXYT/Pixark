import { favVM } from "../viewmodel/FavoriteViewModel";
import { PixState } from "../entryability/AppState";
import { LengthMetrics, SegmentButtonV2Items, TabSegmentButtonV2 } from '@kit.ArkUI';
import { WaterFlowView } from "../components/WaterFlowView";
import { UserListView } from "../components/UsersListView";
import { TabBuild } from "../common/entity/IndexEntity";


@ComponentV2
export struct Favorite {

  @Local skeletonOpacity: number = 1;
  @Local scroller: Scroller = new Scroller();

  private intervalId: number = -1;
  private tabsController: TabsController = new TabsController();

  private filterTabItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: $r('app.string.all') },
    { text: $r('app.string.public') },
    { text: $r('app.string.private') },
  ]);

  build() {
    Column() {
      if (favVM.isInitialLoading) {
        this.FavoriteSkeleton()
      } else {
        this.FavoriteContent()
        // this.FavoriteSkeleton()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  FavoriteContent() {
    Tabs({ index: favVM.mainTabIndex, controller: this.tabsController, }) {
      ForEach(this.getTabList(), (item: TabBuild) => {
        TabContent() {
          this.tabContentBuilder(item.name)
        }.tabBar(item.title)
      })
    }
    .width('100%')
    .layoutWeight(1)
    .barBackgroundColor($r('sys.color.background_primary'))
    .onChange((index: number) => {
      favVM.handleMainTabChange(index);
    })
  }

  // 骨架屏
  @Builder
  FavoriteSkeleton() {
    Scroll() {
      Column({ space: 10 }) {
        // 模拟顶部的 Tab 栏
        Row({ space: 20 }) {
          Row()
            .borderRadius(4)
            .width(60).height(20)
            .opacity(this.skeletonOpacity) // 绑定透明度
            .backgroundColor($r('sys.color.comp_divider'))
            .animation({ duration: 800, curve: Curve.EaseInOut })
          Row()
            .borderRadius(4)
            .width(60).height(20)
            .opacity(this.skeletonOpacity) // 绑定透明度
            .backgroundColor($r('sys.color.comp_divider'))
            .animation({ duration: 800, curve: Curve.EaseInOut })
          Row()
            .borderRadius(4)
            .width(60).height(20)
            .opacity(this.skeletonOpacity) // 绑定透明度
            .backgroundColor($r('sys.color.comp_divider'))
            .animation({ duration: 800, curve: Curve.EaseInOut })
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround)
        .padding({ top: 15, bottom: 10 })
        // 模拟筛选器
        Row()
          .height(32)
          .width('100%')
          .borderRadius(16)
          .margin({ bottom: 10 })
          .opacity(this.skeletonOpacity)
          .backgroundColor($r('sys.color.comp_divider'))
          .animation({ duration: 800, curve: Curve.EaseInOut })
        // 模拟内容区 (瀑布流占位)
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, space: { main: LengthMetrics.vp(10), cross: LengthMetrics.vp(10) } }) {
          ForEach([220, 180, 250, 200, 240, 190], (height: number) => {
            Column()
              .width('48%')
              .height(height)
              .borderRadius(12)
              .opacity(this.skeletonOpacity)
              .backgroundColor($r('sys.color.comp_divider'))
              .animation({ duration: 800, curve: Curve.EaseInOut })
          })
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  aboutToAppear(): void {
    favVM.onReady();
    // 骨架屏闪烁动画
    this.intervalId = setInterval(() => {
      this.skeletonOpacity = this.skeletonOpacity === 1 ? 0.4 : 1;
    }, 800);
  }

  aboutToDisappear(): void {
    if (this.intervalId !== -1) clearInterval(this.intervalId);
  }

  getTabList(): TabBuild[] {
    const tabList: TabBuild[] = [
      { name: 'trend', title: $r('app.string.trend') },
      { name: 'collection', title: $r('app.string.collection') },
      { name: 'follow', title: $r('app.string.follow') },
    ]
    return tabList
  }

  @Builder
  tabContentBuilder(name: string) {
    Column({ space: 10 }) {
      // 筛选器区域
      Row() {
        TabSegmentButtonV2({
          items: this.filterTabItems,
          selectedIndex: favVM.filterIndex,
          onItemClicked: (tab) => {
            favVM.handleFilterChange(tab);
          }
        })
      }
      .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
      .width('100%')
      Refresh({ refreshing: favVM.isRefreshing }) {
        if (name == 'trend') {
          // 动态列表
          WaterFlowView({
            contentEndOffset: (PixState.bottomRectHeight === 0 ? PixState.PageMarginValue : PixState.bottomRectHeight) + this.parseBarHeightValue(PixState.TabBarHeight),
            illustList: favVM.currentIllustList,
            onCardClick: (illust) => {
              favVM.handleIllustClick(illust);
            },
            onReachEnd: () => {
              favVM.loadMore();
            }
          })
        } else if (name == 'collection') {
          // 收藏列表
          WaterFlowView({
            contentEndOffset: (PixState.bottomRectHeight === 0 ? PixState.PageMarginValue : PixState.bottomRectHeight)  + this.parseBarHeightValue(PixState.TabBarHeight),
            illustList: favVM.currentIllustList,
            onCardClick: (illust) => {
              favVM.handleIllustClick(illust);
            },
            onReachEnd: () => {
              favVM.loadMore();
            }
          })
        } else {
          // 关注用户列表
          UserListView({
            contentEndOffset: this.parseBarHeightValue(PixState.TabBarHeight),
            userPres: favVM.followList,
            isFollow: true,
            onButtonClick: (result: boolean, err?: string) => {
            },
            onReachEnd: () => {
              favVM.loadMore();
            }
          })
        }
      }
      .onRefreshing(async () => {
        // 下拉刷新当前页数据
        await favVM.loadCurrentTabData()
      })
    }
    .justifyContent(FlexAlign.Start)
  }

  parseBarHeightValue(value: string | number): number {
    if (typeof value == 'number') return value
    if (!value) return 0;
    const trimmed = value.trim();
    // 百分比直接返回 0
    if (trimmed.includes('%')) {
      return 0;
    }
    // 用正则提取数字（支持小数）
    const match = trimmed.match(/(\d+(\.\d+)?)/);
    return match ? parseFloat(match[1]) : 0;
  }

}
