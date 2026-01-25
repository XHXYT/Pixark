import { BannerView } from "../components/BannerView";
import { PixivImageComponent } from "../components/PixivImage";
import { PixState } from "../entryability/AppState";
import { PixivIllust, PixivUser } from "../services/PixivTypes";
import { ListItemMarginValue, TabBarVertical,
  TabBarWidth,
  WaterFlowColumnsTemplate,
  WindowTabBarWidth } from "../utils/breakpoint/BreakPoint";
import { createLogger } from "../utils/Logger";
import { SnapShotUtils } from "../utils/SnapShotUtils";
import { homeViewModel } from "../viewmodel/HomeViewModel";
import { image } from "@kit.ImageKit";
import { DetailPageParams } from "../entity/IllustDetailEntity";
import { CardUtil } from "../utils/CardUtil";

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
                    PixivImageComponent({
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
                  PixivImageComponent({
                    imageUrl: illust.image_urls.medium,
                    imageObjectFit: ImageFit.Auto,
                    imageBorderRadius: 16,
                  })
                    .id(CardUtil.getFlowItemIdByIndex(illust.id))
                    // .visibility(homeViewModel.hiddenIllustId === illust.id ? Visibility.None : Visibility.Visible)
                }
                .onClick(() => {
                  this.onCardClick(illust)
                })
              }, (iilust: PixivIllust) => `${iilust.id}${iilust.title}`)
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
      .margin({
        right: PixState.rightAvoidWidth,
        left: PixState.leftAvoidWidth
      })
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

  // 点击处理逻辑
  private async onCardClick(illust: PixivIllust) {
    const sourceCardId = CardUtil.getFlowItemIdByIndex(illust.id)
    try {
      // 获取截图
      this.getUIContext().getComponentSnapshot().get(sourceCardId, (err: BusinessError, pixelMap: image.PixelMap) => {
        if (err) {
          logger.error('截图失败，使用普通跳转', JSON.stringify(err));
          this.normalPush(illust);
          return;
        }
        // 截图成功
        SnapShotUtils.pixelMap = pixelMap;
        // 通知 ViewModel 隐藏卡片
        homeViewModel.hideCard(illust.id);
        const params: DetailPageParams = {
          id: illust.id,
          fromId: sourceCardId,
          illust: illust
        }
        // 跳转详情页，带上 fromId
        PixState.pageStack.pushPathByName('illust_detail', params, true);
      });
    } catch (e) {
      logger.error('点击处理异常', JSON.stringify(e));
      this.normalPush(illust);
    }
  }

  // 兜底的普通跳转
  private normalPush(illust: PixivIllust) {
    homeViewModel.pushTo('illust', illust);
  }

}