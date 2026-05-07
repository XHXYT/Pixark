import { PixivImageComponent } from "../components/PixivImage";
import { PixState } from "../entryability/AppState";
import { PixivTrendingTag } from "../services/PixivTypes";
import { GridColumnsTemplate } from "../utils/breakpoint/BreakPoint";
import { toastUtil } from "../utils/ToastUtils";
import { searchVM } from "../viewmodel/SearchViewModel";
import { curves } from "@kit.ArkUI";
import { DetailPageParams } from "../common/entity/IllustDetailEntity";
import SearchHistoryInfo from "../common/entity/SearchHistoryInfo";


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

        List({ space: 10 }) {
          // 搜索历史
          if (searchVM.searchHistory.length > 0) {
            ListItem() {
              Column({ space: 5 }) {
                this.historyTitle()
                Scroll() {
                  Flex({ alignItems: ItemAlign.Start, justifyContent: FlexAlign.Start, wrap: FlexWrap.Wrap }) {
                    ForEach(searchVM.searchHistory, (item: SearchHistoryInfo) => {
                      Stack() {
                        Text(item.keyword)
                          .backgroundColor($r('sys.color.button_background_color_transparent'))
                          .padding({ top: 4, bottom: 4, left: 8, right: 8 })
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                          .textAlign(TextAlign.Center)
                          .borderRadius(6)
                          .borderRadius(4)
                          .fontWeight(300)
                          .fontSize(14)
                          .maxLines(1)
                          .margin(3)
                          .constraintSize({
                            minWidth: '15%',
                            maxWidth: '50%'
                          })
                        if (searchVM.searchHistoryEdit) {
                          SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
                            .fontSize(12)
                            .fontColor([$r('sys.color.font_tertiary')])
                        }
                      }.align(Alignment.TopEnd)
                      .gesture(
                        LongPressGesture()
                          .onAction((event: GestureEvent) => {
                            if (event) {
                              if (!searchVM.searchHistoryEdit) {
                                // 长按进入编辑模式
                                searchVM.searchHistoryEdit = true
                              }
                            }
                          }))
                      .gesture(
                        TapGesture({ count: 1 })
                          .onAction(async (event: GestureEvent) => {
                            if (event) {
                              if (searchVM.searchHistoryEdit) {
                                // 删除
                                if (item.id) {
                                  await searchVM.deleteSearch(item.id)
                                  toastUtil.showToast({ message: $r('app.string.deleted', item.keyword)})
                                }
                              } else {
                                // 设置搜索关键词
                                searchVM.keyword = item.keyword;
                                // 执行搜索
                                searchVM.doSearch(true);
                                // 使用动画跳转到搜索结果页面
                                toastUtil.animateTo({
                                  curve: curves.interpolatingSpring(0, 1, 342, 38)
                                }, () => {
                                  this.pageInfos.pushPath({ name: 'searching_page' }, false);
                                })
                              }
                            }
                          }))
                    }, (item: SearchHistoryInfo) => `${item.id}_${item.keyword}`)
                  }
                }
                .constraintSize({ maxHeight: 99 })
                .nestedScroll({
                  scrollForward: NestedScrollMode.SELF_FIRST,
                  scrollBackward: NestedScrollMode.SELF_FIRST,
                })
              }
            }
          }
          ListItem() {
            Column({ space: 10 }) {
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
                  .gesture(
                    LongPressGesture()
                      .onAction((event: GestureEvent) => {
                        if (event) {
                          // 长按进入插画详情页
                          const params: DetailPageParams = {
                            id: item.illust.id,
                            illust: item.illust
                          }
                          // 跳转至插画详情页
                          PixState.pageStack.pushPathByName('illust_detail', params, true);
                        }
                      }))
                  .gesture(
                    TapGesture({ count: 1 })
                      .onAction((event: GestureEvent) => {
                        if (event) {
                          // 设置搜索关键词为标签名（优先使用翻译名）
                          searchVM.keyword = item.translated_name || item.tag;
                          // 执行搜索
                          searchVM.doSearch(true);
                          // 使用动画跳转到搜索结果页面
                          toastUtil.animateTo({
                            curve: curves.interpolatingSpring(0, 1, 342, 38)
                          }, () => {
                            this.pageInfos.pushPath({ name: 'searching_page' }, false);
                          })
                        }
                      }))
                })
              }
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
              .nestedScroll(searchVM.nestedScrollOptions)
              .contentEndOffset((PixState.TabBarVertical ? 125 : 160) + PixState.bottomRectHeight)
              .columnsTemplate(GridColumnsTemplate(PixState.widthBp))
              .columnsGap(6)
              .rowsGap(8)
            }
            .justifyContent(FlexAlign.Start)
            .alignItems(HorizontalAlign.Start)
          }
        }
        .scrollBar(BarState.Off)
        // .onReachStart(() => {
        //   if (PixState.currentTab == 3 && PixState.TabBarVertical) {
        //     PixState.tabsController.changeIndex(2)
        //   }
        // })
        // .onReachEnd(() => {
        //   if (PixState.currentTab == 3 && PixState.TabBarVertical) {
        //     PixState.tabsController.changeIndex(4)
        //   }
        // })
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
    searchVM.loadData()
  }

  @Builder
  historyTitle() {
    Row({ space: 10 }) {
      Text($r('app.string.search_history'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
      Blank()
      if (searchVM.searchHistoryEdit) {
        Text($r('app.string.cancel'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
          .onClick(() => {
            searchVM.searchHistoryEdit = false
          })
        SymbolGlyph($r('sys.symbol.ohos_trash_circle'))
          .fontSize(22)
          .fontColor([$r('sys.color.font_tertiary')])
          .onClick(() => {
            searchVM.clearSearchHistory()
          })
      }
    }.width('100%')
    .justifyContent(FlexAlign.Start)
  }

}