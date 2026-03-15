import { favVM } from "../viewmodel/FavoriteViewModel";
import { PixState } from "../entryability/AppState";
import { SegmentButtonV2Items, TabSegmentButtonV2 } from '@kit.ArkUI';
import { WaterFlowView } from "../components/WaterFlowView";
import { UserListView } from "../components/UsersListView";
import { TabBuild } from "../entity/IndexEntity";


@ComponentV2
export struct Favorite {

  @Local scroller: Scroller = new Scroller();
  // Tabs 控制器
  private tabsController: TabsController = new TabsController();

  // 筛选器 分段按钮 数据
  private filterTabItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: $r('app.string.all') },
    { text: $r('app.string.public') },
    { text: $r('app.string.private') },
  ]);

  build() {
    Column() {
      Tabs({
        index: favVM.mainTabIndex,
        controller: this.tabsController,
      }) {
        ForEach(this.getTabList(), (item: TabBuild) => {
          TabContent() {
            this.tabContentBuilder(item.name)
          }.tabBar(item.title)
        })
      }
      .width('100%')
      .layoutWeight(1) // 占满剩余高度
      .barBackgroundColor($r('sys.color.background_primary'))
      .onChange((index: number) => {
        favVM.handleMainTabChange(index);
      })
    }
    .width('100%')
    .height('100%')
  }

  aboutToAppear(): void {
    favVM.onReady()
  }

  getTabList(): TabBuild[] {
    const tabList: TabBuild[] = [
      { name: 'trend', title: $r('app.string.trend') },
      { name: 'collection', title: $r('app.string.collection') },
      // { name: 'home', title: $r('app.string.search') },
      { name: 'follow', title: $r('app.string.follow') },
    ]
    return tabList
  }

  @Builder
  tabContentBuilder(name: string) {
    Column() {
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
      .margin({ bottom: 10 }).width('100%')
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
