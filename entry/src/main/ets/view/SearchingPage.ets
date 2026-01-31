import { curves, LengthMetrics, SegmentButtonV2Items, TabSegmentButtonV2 } from '@kit.ArkUI';
import { WaterFlowView } from '../components/WaterFlowView';
import { DetailPageParams } from '../entity/IllustDetailEntity';
import { PixState } from '../entryability/AppState';
import { toastUtil } from '../utils/ToastUtils';
import { searchVM } from '../viewmodel/SearchViewModel';

@Builder
export function SearchingPageBuilder() {
  SearchingPage()
}

@ComponentV2
export default struct SearchingPage {

  @Local searchTypeItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: $r('app.string.illust') },
    { text: $r('app.string.user_author') },
  ]);
  @Local searchTypeSelectedIndex: number = 0;
  private pageInfos: NavPathStack = new NavPathStack();

  build() {
    NavDestination() {
      Column() {
        // 搜索栏
        Flex({ direction: FlexDirection.Row, space: { main: LengthMetrics.vp(8) }, alignItems: ItemAlign.Center }) {
          // 返回图标
          Button({ type: ButtonType.Circle, stateEffect: false }) {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(28)
          }.width(40).height(40)
          .backgroundColor($r('sys.color.button_background_color_transparent'))
          .onClick(() => {
            this.onArrowClicked();
          })
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.OPACITY
              .animation({ duration: 200, delay: 150, curve: curves.cubicBezierCurve(0.33, 0, 0.67, 1) }),
            TransitionEffect.OPACITY
              .animation({ duration: 200, curve: curves.cubicBezierCurve(0.33, 0, 0.67, 1) })
          ))
          Search({ value: searchVM.keyword!!, placeholder: $r('app.string.search_placeholder_1') })
            .placeholderColor($r('sys.color.mask_secondary'))
            .geometryTransition('SEARCH_TRANSITION_ID')
            .transition(TransitionEffect.opacity(0.99))
            .backgroundColor('#0D000000').height(40)
            .defaultFocus(true)
            .focusOnTouch(true)
            .onSubmit(() => {
              searchVM.doSearch()
            })
        }
        .width('100%')
        .height(50)

        // 结果栏
        TabSegmentButtonV2({
          items: this.searchTypeItems,
          selectedIndex: this.searchTypeSelectedIndex!!,
        })
        // 筛选栏(仅插画)
        WaterFlowView({
          illustList: searchVM.resultIllusts,
          onCardClick: (illust) => {
            const params: DetailPageParams = {
              id: illust.id,
              illust: illust
            }
            // 跳转详情页
            PixState.pageStack.pushPathByName('illust_detail', params, true);
          },
          onReachEnd: () => {
            // 只有非测试环境且当前不处于加载中时、存在下一页数据会触发数据更新
            if (!PixState.isTest) {
              searchVM.loadMoreSearchResult()
            }
          }
        })
      }
      .margin({ top: PixState.topRectHeight })
      .size({ width: '100%', height: '100%' })
      .padding(({
        left: PixState.PageMarginValue,
        right: PixState.PageMarginValue
      }))
    }
    .transition(TransitionEffect.OPACITY)
    .hideToolBar(true)
    .hideTitleBar(true)
    .onReady((context: NavDestinationContext) => {
      this.pageInfos = context.pathStack;
    })
    .onBackPressed(() => {
      toastUtil.animateTo({
        curve: curves.interpolatingSpring(0, 1, 342, 38),
      }, () => {
        this.pageInfos.pop(false);
      })
      return true;
    })
  }

  private onArrowClicked(): void {
    toastUtil.animateTo({
      curve: curves.interpolatingSpring(0, 1, 342, 38)
    }, () => {
      this.pageInfos.pop(false);
    })
  }

}
