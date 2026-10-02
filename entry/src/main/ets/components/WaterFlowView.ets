import { PixState, _PixState } from "../entryability/AppState"
import { PixivIllust } from "../services/PixivTypes"
import { WaterFlowColumnsTemplate } from "../common/utils/breakpoint/BreakPoint"
import { CardUtil } from "../common/utils/CardUtil"
import { createLogger } from "../common/utils/Logger"
import { PixivImageComponent } from "./PixivImage"
import { appSettings, UISettings } from "../common/entity/SettingsModel"
import { ConfigurationConstant } from "@kit.AbilityKit"
import { ImageUtils } from '../common/utils/ImageUtils';
import { FunctionConstants } from "../common/constants/FunctionConstants"
import { pixiv } from "../services/PixivService"
import { toastUtil } from "../common/utils/ToastUtils"

const logger = createLogger('WaterFlowView')


/**
 * 瀑布流视图
 */
@ComponentV2
export struct WaterFlowView {

  @Param contentEndOffset: number = 0
  @Param illustList: PixivIllust[] = []
  @Param nestedScroll: NestedScrollOptions | undefined = undefined
  // 嵌套非自滚场景（外层 List 滚动）传 false：关闭瀑布流自身裁剪，阴影才能画进左右留白；
  // 自身滚动的页面（喜欢/排行）必须保持 true，否则滚动内容会溢出到顶部控件上
  @Param clipContent: boolean = true

  @Event onCardClick: (illust: PixivIllust) => void
  @Event onReachEnd: () => void

  build() {
    WaterFlow() {
      ForEach(this.illustList, (illust: PixivIllust) => {
        FlowItem() {
          // 卡片容器：圆角和裁剪统一在外层处理，图片自身不再单独设圆角
          Column() {
            PixivImageComponent({
              showHTips: showHTips(illust),
              showAISign: isAIIllust(illust),
              imageUrl: ImageUtils.getImageUrlByQuality(illust.image_urls, appSettings.image_preview_quality),
              imageObjectFit: ImageFit.Auto,
              imageWidth: '100%',
            })
              .id(CardUtil.getFlowItemIdByIndex(illust.id))
            // 信息行：左侧标题/作者，右侧收藏按钮（可在偏好设置中关闭）
            if (appSettings.show_illust_title) {
              Row({ space: 8 }) {
                Column({ space: 2 }) {
                  Text(illust.title)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('sys.color.font_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                  Text(illust.user?.name || '')
                    .fontSize(11)
                    .fontColor($r('sys.color.font_secondary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                    .width('100%')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)

                CardFavoriteButton({ illust: illust })
              }
              .width('100%')
              .padding({ left: 10, right: 4, top: 8, bottom: 8 })
            }
          }
          .width('100%')
          .borderRadius(16)
          .clip(true)
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          // 卡片阴影（AnimeZ 主页列表同款）
          .shadow({
            radius: 14,
            color: UISettings.color_mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#000000' : '#cccccc',
            offsetX: 6,
            offsetY: 6
          })
          // .visibility(homeViewModel.hiddenIllustId === illust.id ? Visibility.None : Visibility.Visible)
        }
        .onClick(() => {
          this.onCardClick(illust)
        })
      }, (iilust: PixivIllust) => `${iilust.id}${iilust.title}`)
    }
    .rowsGap(10)
    .columnsGap(10)
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .nestedScroll(this.nestedScroll)
    // margin 使组件边界贴住卡片，留白在组件外；配合 clipContent=false 让阴影画到组件边界之外，
    // 由外层滚动容器在屏幕边缘兜底裁剪，右列阴影不再被自身裁断
    .margin({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
    .clip(this.clipContent)
    .contentEndOffset(PixState.bottomRectHeight + this.contentEndOffset)
    .columnsTemplate(WaterFlowColumnsTemplate(PixState.widthBp)) // 瀑布流列数
    .onReachEnd(() => {
      logger.debug('滚动到瀑布流底部，开始加载更多');
      this.onReachEnd()
    })
  }

}

/**
 * 瀑布流卡片收藏按钮（乐观更新，失败回滚）
 */
@ComponentV2
struct CardFavoriteButton {

  @Require @Param illust: PixivIllust
  @Local isFav: boolean = false
  @Local busy: boolean = false

  aboutToAppear(): void {
    this.isFav = this.illust.is_bookmarked
  }

  build() {
    SymbolGlyph(this.isFav ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
      .fontSize(18)
      .fontColor([this.isFav ? PixState.currentThemeColor : $r('sys.color.font_tertiary')])
      .padding(6)
      .onClick(() => {
        this.toggleBookmark()
      })
  }

  private async toggleBookmark(): Promise<void> {
    if (this.busy) {
      return
    }
    this.busy = true
    const target: boolean = !this.isFav
    // 乐观更新 UI 与数据对象（保证跳转详情页时状态一致）
    this.isFav = target
    this.illust.is_bookmarked = target
    try {
      if (target) {
        await pixiv.addBookmark(this.illust.id, appSettings.private_collecting ? 'private' : 'public')
      } else {
        await pixiv.deleteBookmark(this.illust.id)
      }
    } catch (e) {
      // 失败回滚
      this.isFav = !target
      this.illust.is_bookmarked = !target
      toastUtil.showToast({ message: '收藏失败' })
      logger.error(`卡片收藏失败: ${JSON.stringify(e)}`)
    } finally {
      this.busy = false
    }
  }
}

function showHTips(illust: PixivIllust): boolean {
  if (appSettings.show_H) return false
  if (!illust.tags || illust.tags.length === 0) return false;
  const aiTagNames = FunctionConstants.R18_TAG;
  return illust.tags.some(tag => aiTagNames.includes(tag.name))
}

/**
 * 判断插画是否为 AI 作品
 * @param illust 插画对象
 * @returns true 表示是 AI 作品
 */
export function isAIIllust(illust: PixivIllust): boolean {
  const aiType = (illust as PixivIllust).illust_ai_type;
  if (aiType === 2 || aiType === 3) {
    return true;
  }
  if (!illust.tags || illust.tags.length === 0) return false;
  const aiTagNames = FunctionConstants.AI_TAG;
  return illust.tags.some(tag => aiTagNames.includes(tag.name));
}
