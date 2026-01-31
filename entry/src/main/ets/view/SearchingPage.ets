import { curves, SegmentButtonV2Items, TabSegmentButtonV2 } from '@kit.ArkUI';
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
        Row({space: 5}) {
          // 返回图标
          Button({ type: ButtonType.Circle, stateEffect: false }) {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(28)
          }
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.OPACITY
              .animation({ duration: 200, delay: 150, curve: curves.cubicBezierCurve(0.33, 0, 0.67, 1) }),
            TransitionEffect.OPACITY
              .animation({ duration: 200, curve: curves.cubicBezierCurve(0.33, 0, 0.67, 1) })
          ))
          .backgroundColor($r('sys.color.button_background_color_transparent'))
          .width(40).height(40)
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Up) {
              this.getUIContext().animateTo({
                curve: curves.interpolatingSpring(0, 1, 342, 38)
              }, () => {
                this.pageInfos.pop(false)
              })
            }
          })
          Search({ value: searchVM.keyword!!, placeholder: $r('app.string.search_placeholder_1') })
            .placeholderColor($r('sys.color.mask_secondary'))
            .transition(TransitionEffect.opacity(0.99))
            .backgroundColor('#0D000000').height(40)
            .geometryTransition('SEARCH_ID')
            .defaultFocus(true)
            .focusOnTouch(true)
            .onSubmit(() => {
              searchVM.doSearch()
            })
            .layoutWeight(1)
            .id('SEARCH_ID')
        }
        .width('100%').height(56)
        // 结果栏
        Row() {
          TabSegmentButtonV2({
            items: this.searchTypeItems,
            selectedIndex: this.searchTypeSelectedIndex!!,
          })
        }
        .margin({ bottom: 10 })
        .transition(TransitionEffect.asymmetric(
          TransitionEffect.OPACITY
            .combine(TransitionEffect.translate({ y: 100 })),
          TransitionEffect.OPACITY.animation({ duration: 0 })
        ))
        // 筛选栏(仅插画)
        WaterFlowView({
          illustList: searchVM.resultIllusts,
          onCardClick: (illust) => {
            // searchVM.onSearchPageBack(false)
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
          .transition(TransitionEffect.asymmetric(
            TransitionEffect.OPACITY
              .combine(TransitionEffect.translate({ y: 100 })),
            TransitionEffect.OPACITY.animation({ duration: 0 })
          ))
      }
      .backgroundColor($r('sys.color.background_primary'))
      .size({ width: '100%', height: '100%' })
      .padding(({
        left: PixState.PageMarginValue,
        right: PixState.PageMarginValue
      }))
    }
    .hideToolBar(true)
    .hideTitleBar(true)
    .transition(TransitionEffect.OPACITY)
    .onBackPressed(() => {
      this.getUIContext().animateTo({
        curve: curves.interpolatingSpring(0, 1, 342, 38),
      }, () => {
        this.pageInfos.pop(false)
      })
      return true;
    })
    .onReady((context: NavDestinationContext) => {
      this.pageInfos = context.pathStack;
    })

  }

}
