import { BannerView } from "../components/BannerView";
import { PixivImageComponent } from "../components/PixivImage";
import { PixState } from "../entryability/AppState";
import { PixivIllust, PixivUser } from "../services/PixivTypes";
import { ListItemMarginValue} from "../utils/breakpoint/BreakPoint";
import { createLogger } from "../utils/Logger";
import { SnapShotUtils } from "../utils/SnapShotUtils";
import { homeViewModel } from "../viewmodel/HomeViewModel";
import { image } from "@kit.ImageKit";
import { DetailPageParams } from "../entity/IllustDetailEntity";
import { CardUtil } from "../utils/CardUtil";
import { WaterFlowView } from "../components/WaterFlowView";
import { UserDetailParams } from "../entity/UserDetailEntity";

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
            swiperMargin: PixState.widthBp < 2 ? PixState.PageMarginValue - 9 : 0
          })
        }

        // 推荐作者 (横向滚动 List)
        ListItem() {
          Column() {
            this.Title($r('app.string.recommend_author'))
            List({ space: 5 }) {
              ForEach(homeViewModel.recommendedUsers, (user: PixivUser) => {
                ListItem() {
                  Column() {
                    PixivImageComponent({
                      imageUrl: user.profile_image_urls.medium,
                      imageWidth: 50, imageHeight: 50,
                      imageBorder: { radius: 50 }
                    })
                    Text(user.name)
                      .constraintSize({ maxWidth: 65 })
                      .margin({ top: 3 })
                      .fontSize(12)
                      .maxLines(1)
                  }
                }
                .onClick(() => {
                  const params: UserDetailParams = {
                    id: user.id,
                    user: user
                  }
                  // 跳转详情页
                  PixState.pageStack.pushPathByName('user_detail', params, true);
                })
              })
            }
            .padding(({ left: PixState.PageMarginValue, right: PixState.PageMarginValue }))
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
            this.Title($r('app.string.recommend_illust'))
            WaterFlowView({
              contentEndOffset: 52,
              illustList: homeViewModel.recommendedIllusts,
              nestedScroll: homeViewModel.nestedScrollOptions,
              onCardClick: (illust) => {
                this.onCardClick(illust)
              },
              onReachEnd: () => {
                // 只有非测试环境且当前不处于加载中时、存在下一页数据会触发数据更新
                if (!PixState.isTest) {
                  homeViewModel.loadMoreRecommended();
                }
              }
            })
         /*   WaterFlow() {
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

              logger.debug('WaterFlow 滚动到底部，开始加载更多');

            })*/
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Start)
        }
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
      .margin(({ left: PixState.PageMarginValue, right: PixState.PageMarginValue, bottom: 8 }))
  }

  // 点击处理逻辑
  private async onCardClick(illust: PixivIllust) {
    const sourceCardId = CardUtil.getFlowItemIdByIndex(illust.id)
    try {
      // 获取截图
      this.getUIContext().getComponentSnapshot().get(sourceCardId, (err: BusinessError, pixelMap: image.PixelMap) => {
        if (err) {
          logger.error('截图失败，使用普通跳转', JSON.stringify(err));
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
    }
  }

}