import { PixState, _PixState } from "../entryability/AppState"
import { PixivIllust } from "../services/PixivTypes"
import { WaterFlowColumnsTemplate } from "../common/utils/breakpoint/BreakPoint"
import { CardUtil } from "../common/utils/CardUtil"
import { createLogger } from "../common/utils/Logger"
import { PixivImageComponent } from "./PixivImage"
import { appSettings } from "../common/entity/SettingsModel"
import { ImageUtils } from '../common/utils/ImageUtils';
import { FunctionConstants } from "../common/constants/FunctionConstants"

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
            showHTips: showHTips(illust),
            showAISign: isAIIllust(illust),
            imageUrl: ImageUtils.getImageUrlByQuality(illust.image_urls, appSettings.image_preview_quality),
            imageObjectFit: ImageFit.Auto,
            imageBorder: { radius: 16 },
          })
            .id(CardUtil.getFlowItemIdByIndex(illust.id))
          // .visibility(homeViewModel.hiddenIllustId === illust.id ? Visibility.None : Visibility.Visible)
        }
        .clip(true)
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
