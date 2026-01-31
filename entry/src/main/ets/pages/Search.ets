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

  @Local keyword: string = ''
  @Local alphaValue: number = 1;
  @Local isSearchShow: boolean = false

  build() {
    Column({space: 10}) {
      Text($r('app.string.search'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Search({ placeholder: $r('app.string.search_placeholder_1') })
        .searchButton($r('sys.symbol.picture_star_fill'))
        .onClick(()=>{
          this.onAvatarClicked()
          focusControl.requestFocus('search')//主动获取全屏拟态搜索框的焦点呼出软键盘
        })
        .geometryTransition('search', {follow: true})
        .transition(TransitionEffect.OPACITY.animation({ duration: 350, curve: Curve.Friction }))
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
    .bindContentCover(this.isSearchShow,
      this.SearchPageBuilder(), {
      modalTransition: ModalTransition.NONE,
        onWillDismiss: () => {
          this.onSearchPageBack();
        }})
    .opacity(this.alphaValue)
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

  //全屏拟态页面**搜索
  @Builder
  SearchPageBuilder(){
    Column(){
      Row({space: 5}){
        Row(){
          Text('返')
        }.size({width: 40, height: 40})
        .borderRadius(100)
        .justifyContent(FlexAlign.Center)
        .backgroundColor($r('sys.color.icon_fourth'))
        .onClick(() => {
          this.onSearchPageBack();
        })
        .transition(TransitionEffect.asymmetric(TransitionEffect.SLIDE, TransitionEffect.SLIDE_SWITCH))

        Search({ placeholder: $r('app.string.search_placeholder_1') })
          .searchButton($r('sys.symbol.picture_star_fill'))
          .onSubmit(() => {
            // TODO 拉起图片选择以图搜图
            toastUtil.showToast({ message: '开发中-以图搜图' })
          })
          .layoutWeight(1)
          .geometryTransition('search')
          .id('search')
      }.width('100%')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Start)
    .padding(({
      top: PixState.topRectHeight,
      left: ListItemMarginValue(PixState.widthBp, PixState.heightBp),
      right: ListItemMarginValue(PixState.widthBp, PixState.heightBp)
    }))
    .transition(TransitionEffect.asymmetric(
      TransitionEffect.opacity(0.99),
      TransitionEffect.OPACITY
    ))
    .backgroundColor($r('app.color.start_window_background'))
  }

  //共享搜索出现动画
  private onAvatarClicked(): void {
    this.getUIContext()?.animateTo({
      duration: 350,
      curve: Curve.Friction
    }, () => {
      this.isSearchShow = !this.isSearchShow;
      this.alphaValue = 0;
    });
  }

  //全屏拟态关闭动画
  private onSearchPageBack(): void {
    this.getUIContext()?.animateTo({
      duration: 350,
      curve: Curve.Friction
    }, () => {
      this.isSearchShow = !this.isSearchShow;
      this.alphaValue = 1;
    });
  }
}