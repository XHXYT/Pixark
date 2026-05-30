import { PixState, _PixState } from "../entryability/AppState"
import { rankVM } from "../viewmodel/RankViewModel"
import { appSettings } from "../common/entity/SettingsModel"
import { WaterFlowView } from "../components/WaterFlowView"
import { FunctionConstants } from "../common/constants/FunctionConstants"
import { RankTab } from "../common/entity/RankModel"


@ComponentV2
export struct Rank {
  @Local showEditPanel: boolean = false
  @Local showDatePicker: boolean = false
  private selectedDate: Date = new Date()

  aboutToAppear(): void {
    // 如果已经有配置，自动加载第一项
    if (!rankVM.isEmptyConfig) {
      rankVM.currentMode = appSettings.rank_modes[0];
      rankVM.fetchRanking();
    }
  }

  build() {
    Column() {
      // 顶部：Tab 栏 + 操作按钮
      this.Header()
      // 内容区域
      if (rankVM.isEmptyConfig) {
        this.EmptyState()
      } else {
        this.RankList()
      }
    }
    .size({ width: '100%', height: '100%' })
    .bindSheet($$this.showEditPanel, this.EditPanelBuilder(), {
      height: '70%',
      dragBar: true,
      onWillAppear: () => rankVM.openEditMode(),
      onWillDisappear: () => {
        // 关闭时自动保存
        rankVM.saveModes()
      }
    })
  }

  // 头部区域
  @Builder Header() {
    Row({ space: 8 }) {
      // Tab 滚动区域
      Scroll() {
        Row({ space: 12 }) {
          ForEach(rankVM.activeTabs, (tab: RankTab) => {
            Text(tab.label)
              .fontSize(16)
              .fontColor(rankVM.currentMode === tab.key ? $r('sys.color.ohos_id_color_emphasize') : $r('sys.color.font_primary'))
              .fontWeight(rankVM.currentMode === tab.key ? FontWeight.Bold : FontWeight.Normal)
              .onClick(() => {
                rankVM.changeMode(tab.key)
              })
          })
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1)

      // 日期按钮
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(24)
      }
      .width(40).height(40)
      .backgroundColor($r('sys.color.button_background_color_transparent'))
      .onClick(() => {
        _PixState.UIContext.showDatePickerDialog({
          start: new Date(2000, 0, 1),
          end: new Date(2100, 11, 31),
          selected: this.selectedDate,
          showTime: false,
          onDateAccept: (value: Date) => {
            this.selectedDate = new Date(value);
            rankVM.changeDate(this.selectedDate)
          },
          onCancel: () => {
            // 重置时间数据为默认
            if (rankVM.currentDate) {
              rankVM.currentDate = ''
              rankVM.fetchRanking()
            }
          },
          onWillAppear: () => {
            console.info("DatePickerDialog:onWillAppear()");
          },
          onWillDisappear: () => {
            console.info("DatePickerDialog:onWillDisappear()");
          }
        })
      })

      // 编辑/配置 Tab 按钮
      Button({ type: ButtonType.Circle }) {
        SymbolGlyph($r('sys.symbol.square_and_pencil'))
          .fontSize(24)
      }
      .width(40).height(40)
      .backgroundColor($r('sys.color.button_background_color_transparent'))
      .onClick(() => this.showEditPanel = true)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
  }

  // 空状态引导
  @Builder EmptyState() {
    Column() {
      SymbolGlyph($r('sys.symbol.square_and_pencil'))
        .fontSize(60)
        .fontColor([$r('sys.color.ohos_id_color_fourth')])
      Text($r('app.string.no_custom_rank'))
        .fontSize(16)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .margin({ top: 16 })
      Button($r('app.string.click_config'))
        .margin({ top: 24 })
        .onClick(() => this.showEditPanel = true)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // 排行榜列表
  @Builder RankList() {
    WaterFlowView({
      illustList: rankVM.rankList,
      onCardClick: (illust) => {
        rankVM.handleIllustClick(illust);
      },
      onReachEnd: () => {
        rankVM.loadMore();
      }
    })
  }

  // 编辑面板：勾选 + 拖拽排序
  @Builder EditPanelBuilder() {
    Column() {
      Text($r('app.string.custom_rank_items'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 8 })
      Text($r('app.string.custom_rank_items_tips'))
        .fontSize(13)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .margin({ bottom: 16 })

      Grid() {
        ForEach(rankVM.editingModes, (key: string, index?: number) => {
          GridItem() {
            Text(FunctionConstants.RANK_MODE_OPTIONS[key])
              .fontSize(14)
              .padding({ left: 12, right: 12, top: 8, bottom: 8 })
              .borderRadius(20)
              .backgroundColor(rankVM.editingSelected.has(key) ? PixState.currentThemeColor : $r('sys.color.button_background_color_transparent'))
              .fontColor(rankVM.editingSelected.has(key) ? Color.White : $r('sys.color.font_primary'))
              .border({ width: 1, color: rankVM.editingSelected.has(key) ? PixState.currentThemeColor : $r('sys.color.ohos_id_color_fourth') })
              .onClick(() => rankVM.toggleModeInEdit(key))
          }
        }, (key: string) => key)
      }
      .columnsTemplate('1fr 1fr 1fr')
      .rowsGap(10)
      .columnsGap(10)
      .width('100%')
      .editMode(true) // 开启编辑模式
      .supportAnimation(true) // 支持拖拽动画
      .onItemDragStart((event: ItemDragInfo, itemIndex: number) => { // 拖拽开始
        console.debug(`[RankUI] onItemDragStart: index=${itemIndex}`);
        return this.DragItemBuilder(rankVM.editingModes[itemIndex]); // 返回拖拽跟手样式
      })
      .onItemDrop((event: ItemDragInfo, itemIndex: number, insertIndex: number, isSuccess: boolean) => { // 拖拽释放
        console.debug(`[RankUI] onItemDrop: itemIndex=${itemIndex}, insertIndex=${insertIndex}, isSuccess=${isSuccess}`);
        if (!isSuccess || insertIndex < 0 || insertIndex >= rankVM.editingModes.length) {
          return;
        }
        rankVM.onDropTo(itemIndex, insertIndex);
      })
    }
    .padding(24)
    .width('100%')
    .height('100%')
  }

  // 拖拽时跟随手指的半透明幽灵组件
  @Builder DragItemBuilder(key: string) {
    Text(FunctionConstants.RANK_MODE_OPTIONS[key])
      .fontSize(14)
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .borderRadius(20)
      .backgroundColor(PixState.currentThemeColor)
      .fontColor(Color.White)
      .opacity(0.7)
      .border({ width: 1, color: PixState.currentThemeColor })
  }

}
