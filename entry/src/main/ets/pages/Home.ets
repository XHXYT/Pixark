import { BannerView } from "../components/BannerView";
import { PixivImageComponent } from "../components/PixivImage";
import { PixState } from "../entryability/AppState";
import { PixivIllust, PixivUser } from "../services/PixivTypes";
import { ListItemMarginValue} from "../common/utils/breakpoint/BreakPoint";
import { createLogger } from "../common/utils/Logger";
import { SnapShotUtils } from "../common/utils/SnapShotUtils";
import { homeViewModel } from "../viewmodel/HomeViewModel";
import { image } from "@kit.ImageKit";
import { DetailPageParams } from "../common/entity/IllustDetailEntity";
import { CardUtil } from "../common/utils/CardUtil";
import { WaterFlowView } from "../components/WaterFlowView";
import { UserDetailParams } from "../common/entity/UserDetailEntity";
import { LengthMetrics } from "@kit.ArkUI";

const logger = createLogger('Home')

@ComponentV2
export struct Home {

  @Local skeletonOpacity: number = 1;
  private intervalId: number = -1;

  build() {
    if (homeViewModel.isInitialLoading) {
      this.HomeSkeleton()
    } else {
      this.HomeContent()
      // this.HomeSkeleton()
    }
  }

  aboutToAppear(): void {
    // 骨架屏闪烁动画
    this.intervalId = setInterval(() => {
      this.skeletonOpacity = this.skeletonOpacity === 1 ? 0.4 : 1;
    }, 800);
  }

  aboutToDisappear(): void {
    if (this.intervalId !== -1) clearInterval(this.intervalId);
  }

  @Builder
  HomeContent() {
    Refresh({ refreshing: homeViewModel.isRefreshing }) {
      List({ scroller: homeViewModel.listScroller }) {
        // 顶部亮点 (全部分类)
        ListItem() {
          BannerView({ bannerList: homeViewModel.spotlightList, swiperMargin: PixState.widthBp < 2 ? PixState.PageMarginValue - 9 : 0 })
        }
        // 推荐作者 (横向滚动 List)
        ListItem() {
          Column() {
            this.Title($r('app.string.recommend_author'))
            List({ space: 5 }) {
              ForEach(homeViewModel.recommendedUsers, (user: PixivUser) => {
                ListItem() {
                  Column() {
                    PixivImageComponent({ imageUrl: user.profile_image_urls.medium, imageWidth: 50, imageHeight: 50, imageBorder: { radius: 50 } })
                    Text(user.name)
                      .constraintSize({ maxWidth: 65 })
                      .margin({ top: 3 })
                      .fontSize(12)
                      .maxLines(1)
                  }
                }
                .onClick(() => {
                  const params: UserDetailParams = { id: user.id, user: user }
                  PixState.pageStack.pushPathByName('user_detail', params, true);
                })
              })
            }
            .padding(({ left: PixState.PageMarginValue, right: PixState.PageMarginValue }))
            .listDirection(Axis.Horizontal)
            .scrollBar(BarState.Off)
            .margin({ bottom: 5 })
            .width('100%')
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Start)
        }
        // 推荐插画
        ListItem() {
          Column() {
            this.Title($r('app.string.recommend_illust'))
            WaterFlowView({
              contentEndOffset: 52,
              illustList: homeViewModel.recommendedIllusts,
              nestedScroll: homeViewModel.nestedScrollOptions,
              onCardClick: (illust) => { this.onCardClick(illust) },
              onReachEnd: () => {
                if (!PixState.isTest) { homeViewModel.loadMoreRecommended(); }
              }
            })
          }
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Start)
        }
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .margin({ right: PixState.rightAvoidWidth, left: PixState.leftAvoidWidth })
    }
    .onRefreshing(async () => {
      await homeViewModel.loadHomeData()
    })
  }

  // 首页骨架屏
  @Builder
  HomeSkeleton() {
    Scroll() {
      Column({ space: 15 }) {
        // 模拟 Banner 区域
        Row()
          .width('100%')
          .height(150)
          .borderRadius(12)
          .backgroundColor($r('sys.color.comp_divider')) // 系统分割线颜色，偏灰
          .margin({ top: 15 })
          .opacity(this.skeletonOpacity) // 绑定透明度
          .animation({ duration: 800, curve: Curve.EaseInOut })
        // 模拟推荐作者区域
        Column({ space: 8 }) {
          Row()
            .borderRadius(6)
            .width(100).height(20)
            .opacity(this.skeletonOpacity) // 绑定透明度
            .backgroundColor($r('sys.color.comp_divider'))
            .animation({ duration: 800, curve: Curve.EaseInOut })
          Row({ space: 15 }) {
            ForEach([1, 2, 3, 4, 5], (item: number) => {
              Column({ space: 4 }) {
                Row()
                  .borderRadius(25)
                  .width(50).height(50)
                  .opacity(this.skeletonOpacity)
                  .backgroundColor($r('sys.color.comp_divider'))
                  .animation({ duration: 800, curve: Curve.EaseInOut })
                Row()
                  .borderRadius(4)
                  .width(40).height(12)
                  .opacity(this.skeletonOpacity)
                  .backgroundColor($r('sys.color.comp_divider'))
                  .animation({ duration: 800, curve: Curve.EaseInOut })
              }
            })
          }
          .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        // 模拟推荐插画瀑布流区域
        Column({ space: 8 }) {
          Row()
            .borderRadius(6)
            .width(100).height(20)
            .opacity(this.skeletonOpacity) // 绑定透明度
            .backgroundColor($r('sys.color.comp_divider'))
            .animation({ duration: 800, curve: Curve.EaseInOut })
          // 简单模拟不同高度的矩形占位
          Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start, space: { main: LengthMetrics.vp(10), cross: LengthMetrics.vp(10) } }) {
            ForEach([200, 240, 200, 260], (height: number) => {
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
        .alignItems(HorizontalAlign.Start)

      }
      .width('100%')
      .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

  @Builder Title(title: ResourceStr) {
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