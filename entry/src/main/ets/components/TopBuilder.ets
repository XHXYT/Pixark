import { PixState } from "../entryability/AppState"
import { photoAccessHelper } from "@kit.MediaLibraryKit"
import { fileIo, fileUri } from "@kit.CoreFileKit"
import { toastUtil } from "../common/utils/ToastUtils"
import { request } from "@kit.BasicServicesKit"
import { PixivImage } from "../services/PixivTypes"
import { ButtonItem } from "../common/entity/ButtonItemModel"

@ComponentV2
export struct TopBuilder {

  @Param pageInfos: NavPathStack | undefined = undefined
  @Param topHeight: number | undefined = 56
  @Param buttons: ButtonItem[] = []

  build() {
    Row({ space: 6 }) {
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

      if (this.buttons.length > 0) {
        ForEach(this.buttons, (item: ButtonItem) => {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            SymbolGlyph(item.symbol)
              .fontSize(28)
          }
          .width(40).height(40)
          .backgroundColor($r('sys.color.button_background_color_transparent'))
          .onClick((event: ClickEvent) => {
            item.action()
          })
        }, (item: ButtonItem) => item.id)
      }

    }
    .justifyContent(FlexAlign.SpaceBetween)
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