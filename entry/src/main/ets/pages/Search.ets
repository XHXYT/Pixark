import { PixivImageComponent } from "../components/PixivImage";
import { PixState } from "../entryability/AppState";
import { PixivTrendingTag } from "../services/PixivTypes";
import { GridColumnsTemplate } from "../utils/breakpoint/BreakPoint";
import { createLogger } from "../utils/Logger";
import { toastUtil } from "../utils/ToastUtils";
import { searchVM } from "../viewmodel/SearchViewModel";
import { curves } from "@kit.ArkUI";

const logger = createLogger('SearchPage')

@ComponentV2
export struct SearchPage {

  build() {
    Column({space: 10}) {
      Text($r('app.string.search'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Search({ placeholder: $r('app.string.search_placeholder_1') })
        .geometryTransition('SEARCH_TRANSITION_ID', { follow: true })
        .searchButton($r('sys.symbol.picture_star_fill'))
        .defaultFocus(false)
        .focusOnTouch(false)
        .focusable(false)
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Up) {
            this.showSearchPage();
          }
        })
        .onSubmit(() => {
          // TODO 拉起图片选择以图搜图
          toastUtil.showToast({ message: '开发中-以图搜图' })
        })
      // 推荐标签
      Text($r('app.string.recommend_tag'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
      Grid() {
        ForEach(searchVM.trendingTags, (item: PixivTrendingTag) => {
          GridItem() {
            Stack() {
              // 封面图
              PixivImageComponent({
                imageUrl: item.illust.image_urls.square_medium,
                imageAspectRatio: 1,
                imageBorderRadius: 12,
                needMask: true
              })
              // 标签名
              Text() {
                Span('#')
                Span(item.translated_name || item.tag)
              }
              .fontSize(14)
              .maxLines(1)
              .fontColor($r('sys.color.font_on_primary'))
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignContent(Alignment.Bottom)
          }
        })
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      // .nestedScroll(searchVM.nestedScrollOptions)
      .contentEndOffset((PixState.TabBarVertical ? 125 : 185) + PixState.bottomRectHeight)
      .columnsTemplate(GridColumnsTemplate(PixState.widthBp))
      .columnsGap(6)
      .rowsGap(8)
      .onReachStart(() => {
        if (PixState.currentTab == 3 && PixState.TabBarVertical) {
          PixState.tabsController.changeIndex(2)
        }
      })
      .onReachEnd(() => {
        if (PixState.currentTab == 3 && PixState.TabBarVertical) {
          PixState.tabsController.changeIndex(4)
        }
      })
    }
    .alignItems(HorizontalAlign.Start)
    .padding(({
      left: PixState.PageMarginValue,
      right: PixState.PageMarginValue
    }))
  }

  aboutToAppear(): void {
    searchVM.loadTrendingTags()
  }

  private showSearchPage(): void {
    PixState.transitionEffect = TransitionEffect.OPACITY;
    toastUtil.animateTo({
      curve: curves.interpolatingSpring(0, 1, 342, 38)
    }, () => {
      PixState.pageStack.pushPath({ name: 'searching_page' }, false);
    })
  }

}