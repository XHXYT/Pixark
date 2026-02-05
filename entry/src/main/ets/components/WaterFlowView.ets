import { PixState } from "../entryability/AppState"
import { PixivIllust } from "../services/PixivTypes"
import { WaterFlowColumnsTemplate } from "../utils/breakpoint/BreakPoint"
import { CardUtil } from "../utils/CardUtil"
import { createLogger } from "../utils/Logger"
import { PixivImageComponent } from "./PixivImage"

const logger = createLogger('WaterFlowView')

/**
 * 瀑布流视图
 */
@ComponentV2
export struct WaterFlowView {

  @Param contentEndOffset: number = 0
  @Param illustList: PixivIllust[] = []
  @Param nestedScroll: NestedScrollOptions | undefined = undefined

  @Event onCardClick: (illust: PixivIllust) => void
  @Event onReachEnd: () => void

  build() {
    WaterFlow() {
      ForEach(this.illustList, (illust: PixivIllust) => {
        FlowItem() {
          PixivImageComponent({
            imageUrl: illust.image_urls.medium,
            imageObjectFit: ImageFit.Auto,
            imageBorder: { radius: 16 },
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
    .nestedScroll(this.nestedScroll)
    .margin({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
    .contentEndOffset(PixState.bottomRectHeight + this.contentEndOffset)
    .columnsTemplate(WaterFlowColumnsTemplate(PixState.widthBp)) // 瀑布流列数
    .onReachEnd(() => {
      logger.debug('滚动到瀑布流底部，开始加载更多');
      this.onReachEnd()
    })
  }

}