import { BannerView } from "../components/BannerView";
import { PixivImage } from "../components/PixivImage";
import { PixState } from "../entryability/AppState";
import { PixivIllust, PixivUser } from "../services/PixivTypes";
import { ListItemMarginValue, WaterFlowColumnsTemplate } from "../utils/breakpoint/BreakPoint";
import { homeViewModel } from "../viewmodel/HomeViewModel";

@ComponentV2
export struct Home {

  build() {
    List({ scroller: homeViewModel.listScroller }) {
      // 顶部亮点 (全部分类)
      ListItem() {
        BannerView({ bannerList: homeViewModel.spotlightList })
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
                    .fontSize(12)
                    .margin({ top: 3 })
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

      ListItem() {
        Column() {
          // 推荐插画
          this.Title('推荐插画')
          WaterFlow() {
            ForEach(homeViewModel.recommendedIllusts, (illust: PixivIllust) => {
              FlowItem() {
                PixivImage({ imageUrl: illust.image_urls.medium })
                  .borderRadius(12)
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
        }
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Start)
      }
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .padding({ left: ListItemMarginValue(PixState.widthBp, PixState.heightBp), right: ListItemMarginValue(PixState.widthBp, PixState.heightBp)})

  }

  @Builder
  Title(title: ResourceStr) {
    Text(title)
      .fontSize(18)
      .fontWeight(FontWeight.Bold)
      .margin({ bottom: 8})
  }

}