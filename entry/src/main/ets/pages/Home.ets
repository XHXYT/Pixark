import { BannerView } from "../components/BannerView";
import { PixivImage } from "../components/PixivImage";
import { PixState } from "../entryability/AppState";
import { PixivIllust, PixivUser } from "../services/PixivTypes";
import { ListItemMarginValue, WaterFlowColumnsTemplate } from "../utils/breakpoint/BreakPoint";
import { createLogger } from "../utils/Logger";
import { homeViewModel } from "../viewmodel/HomeViewModel";

const logger = createLogger('Home')

@ComponentV2
export struct Home {

  build() {
    Refresh({ refreshing: homeViewModel.isRefreshing }) {
      List({ scroller: homeViewModel.listScroller }) {
        // 顶部亮点 (全部分类)
        ListItem() {
          BannerView({
            bannerList: homeViewModel.spotlightList,
            swiperMargin: PixState.widthBp < 2 ? ListItemMarginValue(PixState.widthBp, PixState.heightBp) - 9 : 0
          })
        }

        // 推荐作者 (横向滚动 List)
        ListItem() {
          Column() {
            this.Title('推荐作者')
            List({ space: 5 }) {
              ForEach(homeViewModel.recommendedUsers, (user: PixivUser) => {
                ListItem() {
                  Column() {
                    PixivImage({
                      imageUrl: user.profile_image_urls.medium,
                      imageWidth: 50, imageHeight: 50,
                      imageBorderRadius: 50
                    })
                    Text(user.name)
                      .constraintSize({ maxWidth: 65 })
                      .margin({ top: 3 })
                      .fontSize(12)
                      .maxLines(1)
                  }
                }
              })
            }
            .listDirection(Axis.Horizontal) // 横向
            .scrollBar(BarState.Off)
            .margin({ bottom: 5 })
            .width('100%')
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Start)
        }
        .margin(({ left: ListItemMarginValue(PixState.widthBp, PixState.heightBp), right: ListItemMarginValue(PixState.widthBp, PixState.heightBp)}))

        ListItem() {
          Column() {
            // 推荐插画
            this.Title('推荐插画')
            WaterFlow() {
              ForEach(homeViewModel.recommendedIllusts, (illust: PixivIllust) => {
                FlowItem() {
                  PixivImage({
                    imageUrl: illust.image_urls.medium,
                    imageObjectFit: ImageFit.Auto,
                    imageBorderRadius: 16
                  })
                }
              })
            }
            .rowsGap(5)
            .columnsGap(10)
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .nestedScroll(homeViewModel.nestedScrollOptions)
            .columnsTemplate(WaterFlowColumnsTemplate(PixState.widthBp)) // 瀑布流列数
            .onReachEnd(() => {
              // 只有不在加载中、且有下一页数据时才会触发数据更新
              logger.debug('WaterFlow 滚动到底部，开始加载更多');
              homeViewModel.loadMoreRecommended();
            })
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Start)
        }
        .margin({ left: ListItemMarginValue(PixState.widthBp, PixState.heightBp), right: ListItemMarginValue(PixState.widthBp, PixState.heightBp)})
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
    }
    .onRefreshing(async () => {
      // 下拉刷新所有主页数据
      await homeViewModel.loadHomeData()
    })

  }

  @Builder
  Title(title: ResourceStr) {
    Text(title)
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
      .margin({ bottom: 8})
  }

}