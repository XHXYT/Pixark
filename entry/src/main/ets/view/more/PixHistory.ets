import { NaviContainer } from "../../components/NaviContainer"
import { SymbolGlyphModifier } from "@kit.ArkUI"
import { HistoryViewModel, historyVM } from "../../viewmodel/HistoryViewModel"
import { PixState, _PixState } from "../../entryability/AppState"
import { WaterFlowColumnsTemplate } from "../../common/utils/breakpoint/BreakPoint"
import { PixivImageComponent } from "../../components/PixivImage"
import IllustHistoryInfo from "../../common/entity/IllustHistoryInfo"
import NovelHistoryInfo from "../../common/entity/NovelHistoryInfo"
import { DetailPageParams } from "../../common/entity/IllustDetailEntity"
import { toastUtil } from "../../common/utils/ToastUtils"
import { appSettings } from "../../common/entity/SettingsModel"
import { ResourceUtils } from "../../common/utils/ResourceUtil"

@Builder
export function PixHistoryBuilder() {
  PixHistory()
}


@ComponentV2
struct PixHistory {
  @Local dVM: HistoryViewModel = historyVM
  @Local searchText: string = ''
  private pageStack: NavPathStack = new NavPathStack()

  aboutToAppear(): void {
    this.dVM.fetchData();
  }

  build() {
    NaviContainer({
      title: ResourceUtils.getString(appSettings.novel_mode ? $r('app.string.novel') : $r('app.string.illust')) + ResourceUtils.getString($r('app.string.browse_history')),
      buttons: this.buttons(),
      content: () => { this.Content() },
      onReady: (ctx) => { this.pageStack = ctx.pathStack },
      onBackPressed: () => {
        if (this.dVM.isEditMode) {
          toastUtil.animateTo({ duration: 350 }, () => { this.dVM.toggleEditMode() })
          return true
        } else {
          return false
        }
      }
    })
  }

  @Builder Content() {
    Column({ space: 8 }) {
      // 搜索栏
      Row() {
        Search({ value: this.searchText, placeholder: appSettings.novel_mode ? $r('app.string.search_novel_placeholder') : $r('app.string.search_illust_placeholder') })
          .searchButton($r('app.string.search'))
          .textFont({ size: 14 })
          .height(40)
          .onChange((value) => { this.searchText = value; this.dVM.setKeyword(value); })
          .onSubmit(() => { this.dVM.setKeyword(this.searchText); })
      }
      .width('100%')
      .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })

      if (appSettings.novel_mode) {
        this.NovelListContent()
      } else {
        this.IllustWaterFlowContent()
      }
      // 编辑底栏
      if (this.dVM.isEditMode) {
        Row() {
          Button($r('app.string.select_all')).fontSize(16).backgroundColor(Color.Transparent).fontColor($r('sys.color.ohos_id_color_primary'))
            .onClick(() => {
              if (this.dVM.getSelectedCount() === this.dVM.displayList.length) this.dVM.deselectAll();
              else this.dVM.selectAllVisible();
            })
          Text($r('app.string.selected_num', this.dVM.getSelectedCount())).layoutWeight(1).textAlign(TextAlign.Center)
          Button($r('app.string.delete')).fontSize(16).backgroundColor(Color.Transparent).fontColor(Color.Red)
            .onClick(() => { this.dVM.editDelete(); })
        }
        .width('100%').height(56)
        .padding({ left: 16, right: 16 })
        .margin({ bottom:  PixState.widthBp == 2 ? 72 : 0 })
        .backgroundColor($r('sys.color.background_primary'))
        .shadow({ radius: 10, color: '#00000010', offsetY: -2 })
      }
    }
    .width('100%').height('100%')
  }

  // 插画瀑布流布局
  @Builder IllustWaterFlowContent() {
    WaterFlow() {
      ForEach(this.dVM.displayList, (item: IllustHistoryInfo) => {
        FlowItem() {
          Stack({ alignContent: Alignment.TopStart }) {
            PixivImageComponent({ showHTips: false, showAISign: false, imageUrl: item.coverUrl, imageObjectFit: ImageFit.Auto, imageBorder: { radius: 16 } })
              .foregroundColor(this.dVM.isEditMode ? this.dVM.isSelected(item.id!!) ? '#33007DFF' : '#22000000' : undefined)
            if (this.dVM.isEditMode) {
              Checkbox().select(this.dVM.isSelected(item.id!!)).shape(CheckBoxShape.CIRCLE).margin({ top: 8, left: 8 }).hitTestBehavior(HitTestMode.None)
            }
          }
        }
        .clip(true)
        .onClick(() => {
          if (this.dVM.isEditMode) { if (item.id !== null) this.dVM.toggleSelect(item.id); }
          else { this.openIllust(item.pid); }
        })
        .gesture(LongPressGesture().onAction(() => {
          if (!this.dVM.isEditMode) { this.dVM.toggleEditMode(); if (item.id !== null) this.dVM.toggleSelect(item.id); }
        }))
      }, (item: IllustHistoryInfo) => `illust_${item.id}${item.pid}`)
    }
    .rowsGap(5).columnsGap(10).layoutWeight(1).scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .contentEndOffset(PixState.bottomRectHeight + (PixState.widthBp == 2 ? 56 : 0) || 16)
    .margin({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
    .columnsTemplate(WaterFlowColumnsTemplate(PixState.widthBp))
  }

  // 小说列表布局
  @Builder NovelListContent() {
    List({ space: 8 }) {
      ForEach(this.dVM.displayList, (item: NovelHistoryInfo) => {
        ListItem() {
          Row({ space: 12 }) {
            // 左侧封面
            PixivImageComponent({
              imageUrl: item.coverUrl,
              imageObjectFit: ImageFit.Cover,
              imageBorder: { radius: 8 }
            }).width(56).height(76) // 小说封面一般是竖版 2:3 比例
            // 右侧信息
            Column({ space: 4 }) {
              Text(item.title)
                .fontSize(15).fontColor($r('sys.color.ohos_id_color_text_primary'))
                .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
              Row({ space: 6 }) {
                Text($r('app.string.num_words', item.textLength))
                  .fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary'))
                if (item.seriesTitle) {
                  Text() {
                    Span($r('app.string.series'))
                    Span('：')
                    Span(item.seriesTitle)
                  }.fontSize(12).fontColor($r('sys.color.ohos_id_color_activated')).maxLines(1).layoutWeight(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              Text(item.userName).fontSize(12).fontColor($r('sys.color.ohos_id_color_text_secondary')).margin({ top: 2 })
            }.layoutWeight(1).alignItems(HorizontalAlign.Start)

            // 编辑模式遮罩与勾选框
            if (this.dVM.isEditMode) {
              Checkbox().select(this.dVM.isSelected(item.id!!)).shape(CheckBoxShape.CIRCLE)
            }
          }
          .padding(12)
          .borderRadius(16)
          .backgroundColor($r('sys.color.comp_background_list_card'))
          .foregroundColor(this.dVM.isEditMode ? this.dVM.isSelected(item.id!!) ? '#33007DFF' : '#22000000' : undefined)
          .onClick(() => {
            if (this.dVM.isEditMode) { if (item.id !== null) this.dVM.toggleSelect(item.id); }
            else { this.openNovel(item.novelId); }
          })
          .gesture(LongPressGesture().onAction(() => {
            if (!this.dVM.isEditMode) { this.dVM.toggleEditMode(); if (item.id !== null) this.dVM.toggleSelect(item.id); }
          }))
        }
      }, (item: NovelHistoryInfo) => `novel_${item.id}${item.novelId}`)
    }
    .layoutWeight(1).scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .contentEndOffset(PixState.bottomRectHeight + (PixState.widthBp == 2 ? 56 : 0) || 16)
    .margin({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
  }

  private buttons(): NavigationMenuItem[] {
    const btns: NavigationMenuItem[] = [
      { value: '', symbolIcon: new SymbolGlyphModifier($r('sys.symbol.square_and_pencil')), action: () => {
        toastUtil.animateTo({ duration: 350 }, () => { this.dVM.toggleEditMode() })
      }}
    ];
    btns.push({ value: '', symbolIcon: new SymbolGlyphModifier($r('sys.symbol.trash')), action: () => {
      if (!this.dVM.isEditMode) this.dVM.clearAllHistory();
      else this.dVM.editDelete();
    }});
    return btns;
  }

  // 跳转插画详情
  private async openIllust(pid: string) {
    const illustID = Number(pid);
    if (isNaN(illustID) || illustID === 0) return;
    const index = this.dVM.displayList.findIndex(i => (i as IllustHistoryInfo).pid === pid);
    const params: DetailPageParams = {
      id: illustID, fromId: pid, swiperProvider: this.dVM,
      swiperIndex: index >= 0 ? index : 0
    }
    this.pageStack.pushPathByName('illust_detail', params, true);
  }

  // 跳转小说详情
  private async openNovel(novelId: number) {
    if (!novelId) return;

    this.pageStack.pushPathByName('novel_detail', null, true);
  }

}
