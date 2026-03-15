import { PixivImageComponent } from "../components/PixivImage";
import { PixState } from "../entryability/AppState";
import { GridColumnsTemplate } from "../utils/breakpoint/BreakPoint";
import { IllustDetailViewModel } from "../viewmodel/IllustDetailViewModel";
import { SnapShotUtils } from "../utils/SnapShotUtils"; // 截图工具
import { PixivIllust, PixivImage, PixivTag } from "../services/PixivTypes";
import { LengthMetrics } from "@kit.ArkUI";
import { homeViewModel } from "../viewmodel/HomeViewModel";
import { toastUtil } from "../utils/ToastUtils";
import { TopBuilder } from "../components/TopBuilder";
import { DetailPageParams } from "../entity/IllustDetailEntity";
import { UserItem } from "../components/UserItem";
import { PixivImageViewer } from "../components/ImageViewer";

@Builder
export function IllustDetailBuilder(name: string, param: Object) {
  IllustDetail()
}

@ComponentV2
struct IllustDetail {

  @Local currentImageIndex: number = 0
  @Local showLargeImage: boolean = false
  @Local scroller: Scroller = new Scroller();
  @Local iDV: IllustDetailViewModel = new IllustDetailViewModel()

  private pageStack: NavPathStack = new NavPathStack()

  build() {
    NavDestination() {
      Stack() {
        // 标题栏
        TopBuilder({
          pageInfos: this.pageStack
        })
        Row() {
          // 插画内容 + (信息内容)
          List({ scroller: this.scroller, space: 10 }) {
            // 图片列表
            ForEach(this.iDV.imageList, (illust: PixivImage, index: number) => {
              ListItem() {
                PixivImageComponent({
                  imageUrl: illust.medium,
                  imageObjectFit: ImageFit.Auto,
                  imageBorder: { radius: 0 },
                })
                // 给第一张图设置固定的 ID，用于计算动画终点位置
                .id(index === 0 ? this.iDV.sharedId : illust.medium)
              }
              .onClick(() => {
                this.currentImageIndex = index
                this.showLargeImage = true
              })
            })

            if (PixState.widthBp < 2 && this.iDV.detailData) {
              this.IntroContent()
            }
          }
          .height('100%')
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
          .contentStartOffset(56 + PixState.topRectHeight)
          .contentEndOffset(PixState.bottomRectHeight == 0 ?
            PixState.PageMarginValue : PixState.bottomRectHeight)
          .padding(({
            left: PixState.PageMarginValue,
            right: PixState.PageMarginValue
          }))
          .width(PixState.widthBp < 2 ? '100%' : PixState.windowWidth / 2)

          // (信息内容)
          if (PixState.widthBp >= 2 && this.iDV.detailData) {
            List({ space: 10 }) {
              this.IntroContent()
            }
            .height('100%')
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .contentEndOffset(PixState.bottomRectHeight == 0 ?
              PixState.PageMarginValue : PixState.bottomRectHeight)
            .contentStartOffset(60 + PixState.topRectHeight)
            .width(PixState.widthBp < 2 ? '100%' : PixState.windowWidth / 2)
            .padding(({
              left: PixState.PageMarginValue,
              right: PixState.PageMarginValue
            }))
            .width(PixState.widthBp < 2 ? '100%' : PixState.windowWidth / 2)
          }

        }
        .justifyContent(FlexAlign.SpaceBetween)

        // 插画查看器
        if (this.showLargeImage) {
          PixivImageViewer({
            imageUrls: this.iDV.imageList, // 图片列表
            startIndex: this.currentImageIndex, // 从哪张开始
            onClose: () => {
              this.showLargeImage = false;
            },
            onDownload: (index) => {
              // 调用下载逻辑
              this.iDV.downloadCurrentImage(index);
            },
            onShare: (url, index) => {
              // TODO 调用系统分享

            }
          })
        }

      }
      .alignContent(Alignment.TopStart)
/*      // 核心布局：使用 Stack 实现层叠效果
      // 底层是截图（做动画），上层是真实内容
      Stack({ alignContent: Alignment.TopStart }) {
        // >>>> 层级 1：截图层 (动画过渡层) <<<<
        // 只有当有截图数据时才渲染此层
        // if (SnapShotUtils.pixelMap) {
        //   Image(SnapShotUtils.pixelMap)
        //     .size(this.iDV.longTakeAnimationProperties.snapShotSize)
        //     .objectFit(ImageFit.Cover)
        //     // 截图的透明度变化：从 1 -> 0
        //     .opacity(this.iDV.longTakeAnimationProperties.snapShotOpacity)
        //     // 必须同步加载，防止动画第一帧闪烁
        //     .syncLoad(true)
        //     // 截图的位置偏移
        //     .position({
        //       x: this.iDV.longTakeAnimationProperties.snapShotPositionX,
        //       y: this.iDV.longTakeAnimationProperties.snapShotPositionY
        //     })
        // }
        // >>>> 层级 2：最终展示层 <<<<
        Column() {

        }
        .width('100%')
        .height('100%')
        // 绑定真实内容的不透明度：从 0 -> 1
        .opacity(this.iDV.longTakeAnimationProperties.postPageOpacity)
      }
      .width('100%')
      .height('100%')
      // 绑定容器的整体动画属性
      .scale({
        x: this.iDV.longTakeAnimationProperties.scaleValue,
        y: this.iDV.longTakeAnimationProperties.scaleValue
      })
      .translate({
        x: this.iDV.longTakeAnimationProperties.translateX,
        y: this.iDV.longTakeAnimationProperties.translateY
      })
      .position({
        x: this.iDV.longTakeAnimationProperties.positionXValue,
        y: this.iDV.longTakeAnimationProperties.positionYValue
      })
      // 圆角变化：从小卡片的圆角 -> 全屏无圆角
      .borderRadius(this.iDV.longTakeAnimationProperties.radius)
      .clip(true) // 必须开启裁剪，否则内容会溢出圆角
      .backgroundColor(this.iDV.longTakeAnimationProperties.navDestinationBgColor)*/
    }
    .hideToolBar(true)
    .hideTitleBar(true)
    .onReady((ctx: NavDestinationContext) => {
      this.pageStack = ctx.pathStack
      this.iDV.onReady(ctx);
    })
    .onDisAppear(() => {
      // 在页面消失时，兜底调用一次恢复，确保回到上一页插画可见
      homeViewModel.restoreIllustVisibility();
      // 页面销毁时清理截图资源，防止内存泄漏
      SnapShotUtils.clear();
    })
    .onBackPressed(() => {
      if (this.showLargeImage) {
        this.showLargeImage = false
        return true
      }
      return false
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
      Text(this.iDV.detailData!.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
      // 统计数据行：观看人数 + 喜欢数 + 时间
      Row({ space: 16 }) {
        Text(`${this.iDV.detailData!.total_view} 浏览`)
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
        Text(`${this.iDV.detailData!.total_bookmarks} 收藏`)
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
        // 格式化时间
        Text(this.iDV.formatDate(this.iDV.detailData!.create_date))
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      // 元数据行：ID + 分辨率
      Row({ space: 16 }) {
        Text(`插画ID: ${this.iDV.detailData!.id}`)
          .fontSize(12)
          .fontColor($r('sys.color.font_fourth'))
        Text(`${this.iDV.detailData!.width} x ${this.iDV.detailData!.height}`)
          .fontSize(12)
          .fontColor($r('sys.color.font_fourth'))
      }
      .width('100%')
      // 分割线
      Divider()
        .color($r('sys.color.ohos_id_color_text_field_sub_bg'))

      // 作者行：头像 + 名称 + 关注按钮
      UserItem({
        user: this.iDV.detailData?.user,
        isFollow: this.iDV.isFollow,
        onButtonClick: (result: boolean, err?: string) => {
          this.iDV.followOrCancel(result, err)
        }
      })

      // 标签
      Flex({ wrap: FlexWrap.Wrap, space: { main: LengthMetrics.vp(8), cross: LengthMetrics.vp(8) } }) {
        ForEach(this.iDV.detailData!.tags, (tag: PixivTag) => {
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
        ForEach(this.iDV.relatedIllusts, (item: PixivIllust) => {
          GridItem() {
            PixivImageComponent({
              imageUrl: item.image_urls.square_medium,
              imageAspectRatio: 1
            })
          }
          .onClick(() => {
            // TODO 只有跳转到第2个路由栈页时，返回无过渡动画
            // 构造详情页参数
            const params: DetailPageParams = {
              id: item.id,
              illust: item
            }
            // 跳转到详情页
            this.pageStack.pushPathByName('illust_detail', params, true);
          })
        })
      }
      .columnsTemplate(GridColumnsTemplate(PixState.widthBp))
      .columnsGap(3)
      .rowsGap(3)
      .width('100%')
    }
    .width('100%')
    .borderRadius(12)
  }

}
