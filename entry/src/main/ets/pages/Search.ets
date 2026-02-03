import { PixivImageComponent } from "../components/PixivImage";
import { PixState } from "../entryability/AppState";
import { PixivTrendingTag } from "../services/PixivTypes";
import { GridColumnsTemplate, ListItemMarginValue, TabBarVertical } from "../utils/breakpoint/BreakPoint";
import { createLogger } from "../utils/Logger";
import { toastUtil } from "../utils/ToastUtils";
import { searchVM } from "../viewmodel/SearchViewModel";
import { curves } from "@kit.ArkUI";

const logger = createLogger('SearchPage')

@ComponentV2
export struct SearchPage {

  private pageInfos: NavPathStack = new NavPathStack();
  aboutToAppear(): void {
    setTimeout(() => {
      this.pageInfos.pushPath({ name: 'search_page' }, false)
    }, 300)
  }

  build() {
    Navigation(this.pageInfos) {
    }
    .hideToolBar(true)
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
  }

}

@Builder
export function SearchContentBuilder() {
  SearchContent()
}

@ComponentV2
export struct SearchContent {

  private pageInfos: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Column({space: 10}) {
        Text($r('app.string.search'))
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
        Search({ value: searchVM.keyword!!, placeholder: $r('app.string.search_placeholder_1') })
          .defaultFocus(false)
          .focusOnTouch(false)
          .searchButton($r('sys.symbol.picture_star_fill'))
          .geometryTransition('SEARCH_ID', { follow: true })
          .transition(TransitionEffect.OPACITY.animation({ duration: 350, curve: Curve.Friction }))
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Up) {
              // set search animation
              this.getUIContext().animateTo({
                curve: curves.interpolatingSpring(0, 1, 342, 38)
              }, () => {
                this.pageInfos.pushPath({ name: 'searching_page' }, false);
              })
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
                  imageBorder: { radius: 12 },
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
            .onClick(() => {
              // 设置搜索关键词为标签名（优先使用翻译名）
              searchVM.keyword = item.translated_name || item.tag;
              // 执行搜索
              searchVM.doSearch();
              // 使用动画跳转到搜索结果页面
              this.getUIContext().animateTo({
                curve: curves.interpolatingSpring(0, 1, 342, 38)
              }, () => {
                this.pageInfos.pushPath({ name: 'searching_page' }, false);
              })
            })
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
    .hideToolBar(true)
    .hideTitleBar(true)
    .transition(TransitionEffect.OPACITY)
    .onReady((context: NavDestinationContext) => {
      this.pageInfos = context.pathStack;
    })
    .onBackPressed(() => {
      return true
    })
  }

  aboutToAppear(): void {
    searchVM.loadTrendingTags()
  }

}