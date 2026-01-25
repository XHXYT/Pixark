import { PixivImageComponent } from "../components/PixivImage";
import { PixState } from "../entryability/AppState";
import { PixivTrendingTag } from "../services/PixivTypes";
import { GridColumnsTemplate, ListItemMarginValue, TabBarVertical } from "../utils/breakpoint/BreakPoint";
import { createLogger } from "../utils/Logger";
import { toastUtil } from "../utils/ToastUtils";
import { searchVM } from "../viewmodel/SearchViewModel";

const logger = createLogger('SearchPage')

@ComponentV2
export struct SearchPage {

  @Local keyword: string = '';

  build() {
    Column({space: 10}) {
      Search({ placeholder: $r('app.string.search_placeholder_1') })
        .searchButton($r('sys.symbol.picture_star_fill'))
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
                imageBorderRadius: 12
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
      // .nestedScroll(searchVM.nestedScrollOptions)
      .contentEndOffset((TabBarVertical(PixState.widthBp, PixState.heightBp) ? 135 : 156) + PixState.bottomRectHeight)
      .columnsTemplate(GridColumnsTemplate(PixState.widthBp))
      .columnsGap(6)
      .rowsGap(8)
    }
    .alignItems(HorizontalAlign.Start)
    .padding(({
      left: ListItemMarginValue(PixState.widthBp, PixState.heightBp),
      right: ListItemMarginValue(PixState.widthBp, PixState.heightBp)
    }))
  }

  aboutToAppear(): void {
    searchVM.loadTrendingTags()
  }

  async doSearch() {
    logger.info('doSearch start.');
    if (!this.keyword) {
      logger.warn('Search keyword is empty.');
      return;
    }
    PixState.isLoading = true;
    try {
      const res = await PixState.pixiv.searchIllust(this.keyword);
      // this.results = res.illusts;
      // logger.info('Search data loaded. Count: ' + this.results.length);
    } catch (e) {
      logger.error('Search process error: ' + JSON.stringify(e));
    } finally {
      PixState.isLoading = false;
    }
  }

}