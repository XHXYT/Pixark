import { NaviContainer } from "../../components/NaviContainer"
import { SymbolGlyphModifier } from "@kit.ArkUI"
import { IllustHistoryViewModel, IllustHistoryVM } from "../../viewmodel/IllustHistoryViewModel"
import { PixState, _PixState } from "../../entryability/AppState"
import { WaterFlowColumnsTemplate } from "../../common/utils/breakpoint/BreakPoint"
import { PixivImageComponent } from "../../components/PixivImage"
import IllustHistoryInfo from "../../common/entity/IllustHistoryInfo"
import { DetailPageParams } from "../../common/entity/IllustDetailEntity"
import { toastUtil } from "../../common/utils/ToastUtils"

@Builder
export function IllustHistoryBuilder() {
  IllustHistory()
}

@ComponentV2
struct IllustHistory {
  @Local dVM: IllustHistoryViewModel = IllustHistoryVM
  @Local searchText: string = ''
  private pageStack: NavPathStack = new NavPathStack()

  aboutToAppear(): void {
    this.dVM.fetchData();
  }

  build() {
    NaviContainer({
      title: $r('app.string.browse_history'),
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

  @Builder
  Content() {
    Column({ space: 8 }) {
      // 搜索栏
      Row() {
        Search({ value: this.searchText, placeholder: '搜索标题或PID' })
          .searchButton('搜索')
          .textFont({ size: 14 })
          .height(40)
          .onChange((value) => {
            this.searchText = value;
            this.dVM.setKeyword(value);
          })
          .onSubmit(() => {
            this.dVM.setKeyword(this.searchText);
          })
      }
      .width('100%')
      .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })

      // 瀑布流列表
      WaterFlow() {
        ForEach(this.dVM.displayList, (item: IllustHistoryInfo) => {
          FlowItem() {
            Stack({ alignContent: Alignment.TopStart }) {
              // 底层：图片
              PixivImageComponent({
                showHTips: false,
                showAISign: false,
                imageUrl: item.coverUrl,
                imageObjectFit: ImageFit.Auto,
                imageBorder: { radius: 16 },
              })
                .foregroundColor(this.dVM.isEditMode ? this.dVM.isSelected(item.id!!) ? '#33007DFF' : '#22000000' : undefined)
              // 编辑模式下的遮罩与勾选框
              if (this.dVM.isEditMode) {
                // 状态指示勾选框
                Checkbox()
                  .select(this.dVM.isSelected(item.id!!))
                  .shape(CheckBoxShape.CIRCLE)
                  .margin({ top: 8, left: 8 })
                  .hitTestBehavior(HitTestMode.None)
              }
            }
          }
          .clip(true)
          .onClick(() => {
            if (this.dVM.isEditMode) {
              if (item.id !== null) this.dVM.toggleSelect(item.id);
            } else {
              this.openIllust(item.pid);
            }
          })
          .gesture(
            LongPressGesture()
              .onAction(() => {
                if (!this.dVM.isEditMode) {
                  this.dVM.toggleEditMode();
                  if (item.id !== null) this.dVM.toggleSelect(item.id);
                }
              })
          )
        }, (item: IllustHistoryInfo) => `${item.id}${item.pid}`)
      }
      .rowsGap(5)
      .columnsGap(10)
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .contentEndOffset(PixState.bottomRectHeight || 16)
      .margin({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
      .columnsTemplate(WaterFlowColumnsTemplate(PixState.widthBp))

      // 编辑底栏
      if (this.dVM.isEditMode) {
        Row() {
          Button("全选")
            .fontSize(16)
            .backgroundColor(Color.Transparent)
            .fontColor($r('sys.color.ohos_id_color_primary'))
            .onClick(() => {
              if (this.dVM.getSelectedCount() === this.dVM.displayList.length) {
                this.dVM.deselectAll();
              } else {
                this.dVM.selectAllVisible();
              }
            })

          Text(`已选择 ${this.dVM.getSelectedCount()} 项`)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Button("删除")
            .fontSize(16)
            .backgroundColor(Color.Transparent)
            .fontColor(Color.Red)
            .onClick(() => {
              this.dVM.editDelete();
            })
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('sys.color.background_primary'))
        .shadow({ radius: 10, color: '#00000010', offsetY: -2 })
      }
    }
    .width('100%')
    .height('100%')
  }

  private buttons(): NavigationMenuItem[] {
    const btns: NavigationMenuItem[] = [
      {
        value: '',
        symbolIcon: new SymbolGlyphModifier($r('sys.symbol.square_and_pencil')),
        action: () => {
          toastUtil.animateTo({ duration: 350 }, () => { this.dVM.toggleEditMode() })
        }
      }
    ];
    btns.push({
      value: '',
      symbolIcon: new SymbolGlyphModifier($r('sys.symbol.trash')),
      action: () => {
        if (!this.dVM.isEditMode) {
          this.dVM.clearAllHistory();
        } else {
          this.dVM.editDelete();
        }
      }
    });
    return btns;
  }

  // 跳转插画详情
  private async openIllust(pid: string) {
    const illustID = Number(pid);
    if (isNaN(illustID) || illustID === 0) return;
    const params: DetailPageParams = { id: illustID, fromId: pid }
    this.pageStack.pushPathByName('illust_detail', params, true);
  }
}
