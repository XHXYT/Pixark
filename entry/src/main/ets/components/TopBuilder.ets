import { PixState } from "../entryability/AppState"


@ComponentV2
export struct TopBuilder {

  @Param pageInfos: NavPathStack | undefined = undefined
  @Param topHeight: number | undefined = 56

  build() {
    Row() {
      if (this.pageInfos) {
        // 返回图标
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(28)
        }
        .width(40).height(40)
        .backgroundColor($r('sys.color.button_background_color_transparent'))
        .onClick(() => {
          if (this.pageInfos) {
            this.pageInfos.pop(true)
          }
        })
      }
    }
    .zIndex(10)
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .backgroundColor(Color.Transparent)
    .backgroundBlurStyle(BlurStyle.Thin)
    .height(this.topHeight ? PixState.topRectHeight + this.topHeight : PixState.topRectHeight)
    .padding(({
      top: PixState.topRectHeight,
      left: PixState.PageMarginValue,
      right: PixState.PageMarginValue
    }))
  }

}