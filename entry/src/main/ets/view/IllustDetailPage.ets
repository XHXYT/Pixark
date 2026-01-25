import { PixivImageComponent } from "../components/PixivImage";
import { PixState } from "../entryability/AppState";
import { GridColumnsTemplate, ListItemMarginValue } from "../utils/breakpoint/BreakPoint";
import { iDV } from "../viewmodel/IllustDetailViewModel";
import { SnapShotUtils } from "../utils/SnapShotUtils"; // 截图工具
import { PixivIllust, PixivImage, PixivTag } from "../services/PixivTypes";
import { LengthMetrics } from "@kit.ArkUI";
import { homeViewModel } from "../viewmodel/HomeViewModel";
import { toastUtil } from "../utils/ToastUtils";
import { TopBuilder } from "../components/TopBuilder";

@Builder
export function IllustDetailBuilder(name: string, param: Object) {
  IllustDetail()
}

@ComponentV2
struct IllustDetail {

  @Local scroller: Scroller = new Scroller();

  build() {
    NavDestination() {
      Stack() {
        // 标题栏
        TopBuilder({
          pageInfos: PixState.pageStack
        })
        Row() {
          // 插画内容 + (信息内容)
          List({ scroller: this.scroller, space: 10 }) {
            // 图片列表
            ForEach(iDV.imageList, (illust: PixivImage, index: number) => {
              ListItem() {
                PixivImageComponent({
                  imageUrl: illust.medium,
                  imageObjectFit: ImageFit.Auto,
                  imageBorderRadius: 0,
                })
                // 给第一张图设置固定的 ID，用于计算动画终点位置
                  .id(index === 0 ? iDV.sharedId : illust.medium)
              }
            })

            if (PixState.widthBp < 2) {
              this.IntroContent()
            }
          }
          .height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .contentStartOffset(56 + PixState.topRectHeight)
          .contentEndOffset(PixState.bottomRectHeight == 0 ?
            ListItemMarginValue(PixState.widthBp, PixState.heightBp) : PixState.bottomRectHeight)
          .padding(({
            left: ListItemMarginValue(PixState.widthBp, PixState.heightBp),
            right: ListItemMarginValue(PixState.widthBp, PixState.heightBp)
          }))
          .width(PixState.widthBp < 2 ? '100%' : PixState.windowWidth / 2)

          // (信息内容)
          if (PixState.widthBp >= 2) {
            List({ space: 10 }) {
              this.IntroContent()
            }
            .height('100%')
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .contentEndOffset(PixState.bottomRectHeight == 0 ?
              ListItemMarginValue(PixState.widthBp, PixState.heightBp) : PixState.bottomRectHeight)
            .contentStartOffset(56 + PixState.topRectHeight)
            .width(PixState.widthBp < 2 ? '100%' : PixState.windowWidth / 2)
            .padding(({
              left: ListItemMarginValue(PixState.widthBp, PixState.heightBp),
              right: ListItemMarginValue(PixState.widthBp, PixState.heightBp)
            }))
            .width(PixState.widthBp < 2 ? '100%' : PixState.windowWidth / 2)
          }

        }
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .alignContent(Alignment.TopStart)
/*      // 核心布局：使用 Stack 实现层叠效果
      // 底层是截图（做动画），上层是真实内容
      Stack({ alignContent: Alignment.TopStart }) {
        // >>>> 层级 1：截图层 (动画过渡层) <<<<
        // 只有当有截图数据时才渲染此层
        // if (SnapShotUtils.pixelMap) {
        //   Image(SnapShotUtils.pixelMap)
        //     .size(iDV.longTakeAnimationProperties.snapShotSize)
        //     .objectFit(ImageFit.Cover)
        //     // 截图的透明度变化：从 1 -> 0
        //     .opacity(iDV.longTakeAnimationProperties.snapShotOpacity)
        //     // 必须同步加载，防止动画第一帧闪烁
        //     .syncLoad(true)
        //     // 截图的位置偏移
        //     .position({
        //       x: iDV.longTakeAnimationProperties.snapShotPositionX,
        //       y: iDV.longTakeAnimationProperties.snapShotPositionY
        //     })
        // }
        // >>>> 层级 2：最终展示层 <<<<
        Column() {

        }
        .width('100%')
        .height('100%')
        // 绑定真实内容的不透明度：从 0 -> 1
        .opacity(iDV.longTakeAnimationProperties.postPageOpacity)
      }
      .width('100%')
      .height('100%')
      // 绑定容器的整体动画属性
      .scale({
        x: iDV.longTakeAnimationProperties.scaleValue,
        y: iDV.longTakeAnimationProperties.scaleValue
      })
      .translate({
        x: iDV.longTakeAnimationProperties.translateX,
        y: iDV.longTakeAnimationProperties.translateY
      })
      .position({
        x: iDV.longTakeAnimationProperties.positionXValue,
        y: iDV.longTakeAnimationProperties.positionYValue
      })
      // 圆角变化：从小卡片的圆角 -> 全屏无圆角
      .borderRadius(iDV.longTakeAnimationProperties.radius)
      .clip(true) // 必须开启裁剪，否则内容会溢出圆角
      .backgroundColor(iDV.longTakeAnimationProperties.navDestinationBgColor)*/
    }
    .hideToolBar(true)
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      // 将初始化逻辑交给 ViewModel 处理
      iDV.onReady(ctx);
    })
    .onDisAppear(() => {
      // 在页面消失时，兜底调用一次恢复，保证回到主页卡片可见
      homeViewModel.restoreIllustVisibility();
      // 页面销毁时清理截图资源，防止内存泄漏
      SnapShotUtils.clear();
    })
  }

  @Builder
  IntroContent() {
    // 详情信息卡片
    ListItem() {
      this.InfoCard()
    }
    // 评论入口
    ListItem() {
      this.Comment()
    }
    // 相关推荐
    ListItem() {
      this.RelatedSection()
    }
  }

  /** 详情信息卡片 */
  @Builder
  InfoCard() {
    Column({ space: 12 }) {
      // 标题
      Text(iDV.detailData!.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#111')
        .width('100%')
      // 统计数据行：观看人数 + 喜欢数 + 时间
      Row({ space: 16 }) {
        Text(`${iDV.detailData!.total_view} 浏览`)
          .fontSize(12)
          .fontColor('#888')
        Text(`${iDV.detailData!.total_bookmarks} 收藏`)
          .fontSize(12)
          .fontColor('#888')
        // 格式化时间
        Text(iDV.formatDate(iDV.detailData!.create_date))
          .fontSize(12)
          .fontColor('#888')
      }
      .width('100%')
      // 元数据行：ID + 分辨率
      Row({ space: 16 }) {
        Text(`插画ID: ${iDV.detailData!.id}`)
          .fontSize(12)
          .fontColor('#AAA')
        Text(`${iDV.detailData!.width} x ${iDV.detailData!.height}`)
          .fontSize(12)
          .fontColor('#AAA')
      }
      .width('100%')
      // 分割线
      Divider()
        .color('#F0F0F0')

      // 作者行：头像 + 名称 + 关注按钮
      Row({ space: 12 }) {
        // 头像
        PixivImageComponent({
          imageUrl: iDV.detailData!.user.profile_image_urls.medium,
          imageWidth: 50, imageHeight: 50,
          imageBorderRadius: 50
        })
        // 名称
        Text(iDV.detailData!.user.name)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        // 关注按钮
        Button(iDV.isFollow ? '取消关注' : '关注')
          .type(ButtonType.Normal)
          .fontSize(12)
          .height(28)
          .padding({ left: 12, right: 12 })
          .borderRadius(14)
          .fontColor(Color.White)
          .onClick(() => {
            iDV.followOrCancel()
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 标签
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
        ForEach(iDV.detailData!.tags, (tag: PixivTag) => {
          Text(`#${tag.name}`)
            .fontSize(13)
            .fontColor('#0096fa')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('#EDF5FF')
            .borderRadius(4)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        })
      }
      .width('100%')
    }
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(12)
  }

  /** 评论入口 */
  @Builder
  Comment() {
    Row() {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.ellipsis_message_1'))
          .fontSize(19)
        Text('查看评论')
          .fontSize(16)
      }
      Blank()
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(19)
    }
    .width('100%')
    .backgroundColor(Color.White)
    .borderRadius(12)
    .onClick(() => {
      // TODO: 跳转到评论页或弹出评论层
      toastUtil.showToast({ message: '开发中-弹出评论区半模态窗口' })
    })
  }

  /** 相关推荐 */
  @Builder
  RelatedSection() {
    Column({ space: 12 }) {
      // 标题
      Text('相关推荐')
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .padding({ left: 4 })
      // 网格布局
      Grid() {
        ForEach(iDV.relatedIllusts, (item: PixivIllust) => {
          GridItem() {
            PixivImageComponent({
              imageUrl: item.image_urls.square_medium,
              imageAspectRatio: 1
            })
          }
        })
      }
      .columnsTemplate(GridColumnsTemplate(PixState.widthBp))
      .columnsGap(3)
      .rowsGap(3)
      .width('100%')
    }
    .width('100%')
    .borderRadius(12)
    .backgroundColor(Color.White)
  }

}
