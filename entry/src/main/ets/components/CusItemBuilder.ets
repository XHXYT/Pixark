import { CustomContentDialog, LengthMetrics, SymbolGlyphModifier } from "@kit.ArkUI"
import UIConstants from "../common/constants/UIConstants";
import { CustomItemInfo, ItemActionType, MenuOption } from "../common/entity/CusItemInfo";
import { ColorUtils } from "../common/utils/ColorUtils";
import { ButtonOptions } from "@ohos.arkui.advanced.Dialog"
import { Colors, Theme } from "@ohos.arkui.theme"


@ComponentV2
export struct CustomListItem {

  @Require @Param item: CustomItemInfo
  @BuilderParam icon: CustomBuilder
  @BuilderParam dialogContent?: (data: CustomItemInfo) => void

  @Param itemPadding: Padding = { left: 0, right: 0, top: 0, bottom: 0 }

  @Local showMenu: boolean = false
  @Local dialogController: CustomDialogController | undefined

  aboutToAppear(): void {
    if (this.item.type == ItemActionType.DIALOG) {
      const dialogButtons: ButtonOptions[] =
        this.item.dialogConfig?.buttons?.map((btn: ResourceStr, index: number): ButtonOptions => {
          return {
            value: btn,
            buttonStyle: ButtonStyleMode.TEXTUAL,
            action: () => {
              if (this.item.dialogConfig?.onClick) {
                this.item.dialogConfig.onClick(btn, index, this.dialogController)
              } else {
                if (this.item.onChange && !this.item.dialogConfig?.buttons) {
                  this.item.onChange(index == 1)
                }
                this.dialogController?.close()
              }
            }
          }
        }) || [];

      const contentPadding: Padding = { top: 15, bottom: 15, left: 24, right: 24 };
      const dialogThemeColors: Colors = {
        brand: "",
        warning: "",
        alert: "",
        confirm: "",
        fontPrimary: "",
        fontSecondary: "",
        fontTertiary: "",
        fontFourth: "",
        fontEmphasize: "",
        fontOnPrimary: "",
        fontOnSecondary: "",
        fontOnTertiary: "",
        fontOnFourth: "",
        iconPrimary: "",
        iconSecondary: "",
        iconTertiary: "",
        iconFourth: "",
        iconEmphasize: "",
        iconSubEmphasize: "",
        iconOnPrimary: "",
        iconOnSecondary: "",
        iconOnTertiary: "",
        iconOnFourth: "",
        backgroundPrimary: $r('sys.color.background_primary'),
        backgroundSecondary: "",
        backgroundTertiary: "",
        backgroundFourth: "",
        backgroundEmphasize: "",
        compForegroundPrimary: "",
        compBackgroundPrimary: "",
        compBackgroundPrimaryTran: "",
        compBackgroundPrimaryContrary: "",
        compBackgroundGray: "",
        compBackgroundSecondary: "",
        compBackgroundTertiary: "",
        compBackgroundEmphasize: "",
        compBackgroundNeutral: "",
        compEmphasizeSecondary: "",
        compEmphasizeTertiary: "",
        compDivider: "",
        compCommonContrary: "",
        compBackgroundFocus: "",
        compFocusedPrimary: "",
        compFocusedSecondary: "",
        compFocusedTertiary: "",
        interactiveHover: "",
        interactivePressed: "",
        interactiveFocus: "",
        interactiveActive: "",
        interactiveSelect: "",
        interactiveClick: ""
      };
      const dialogTheme: Theme = { colors: dialogThemeColors };

      this.dialogController = new CustomDialogController({
        builder: CustomContentDialog({
          primaryTitle: this.item.label,
          contentBuilder: (): void => {
            if (this.dialogContent) {
              this.dialogContent(this.item)
            }
          },
          buttons: dialogButtons,
          contentAreaPadding: contentPadding,
          theme: dialogTheme
        }),
        autoCancel: true,
        alignment: DialogAlignment.Center,
        cornerRadius: 32,
        backgroundBlurStyle: BlurStyle.NONE,
        onWillAppear: () => {
          if (this.item.dialogConfig?.onWillAppear != null) {
            this.item.dialogConfig?.onWillAppear()
          }
        },
        width: this.item.dialogConfig?.width,
      })
    }
  }

  build() {
    Row({ space: 50 }) {
      Row({ space: 12 }) {
        if (this.icon) {
          this.icon()
        } else if (this.item.symbol) {
          SymbolGlyph(this.item.symbol)
            .fontColor([this.item.enabled ? this.item.isDanger ? Color.Red : this.item.iconColor : ColorUtils.getUnableColor(this.item.iconColor)])
            .fontSize(24)
        } else if (this.item.icon) {
          Image(this.item.icon)
            .width(21)
            .height(21)
        }

        Column() {
          if (this.item.type === ItemActionType.INPUT) {
            Text(this.item.label)
              .fontColor(this.item.enabled ? this.item.isDanger ? Color.Red : $r('sys.color.font_primary') : ColorUtils.getUnableColor($r('sys.color.font_primary')))
              .fontSize(12)
            TextInput({ text: this.item.value as ResourceStr, placeholder: this.item.subtitle })
              .fontSize(14)
              .enabled(this.item.enabled)
              .onChange((v) => {
              this.item.value = v;
              if (this.item.onChange != null) {
                this.item.onChange(v)
              }
            })
          } else {
            Text(this.item.label)
              .fontColor(this.item.enabled ? this.item.isDanger ? Color.Red : $r('sys.color.font_primary') : ColorUtils.getUnableColor($r('sys.color.font_primary')))
              .fontSize(16)
            if (this.item.subtitle) {
              Text(this.item.subtitle)
                .fontColor(this.item.enabled ? this.item.isDanger ? Color.Red : $r("sys.color.font_secondary") : ColorUtils.getUnableColor($r("sys.color.font_secondary")))
                .fontSize(12)
            }
          }
        }
        .enabled(this.item.enabled)
        .alignItems(HorizontalAlign.Start)
      }.layoutWeight(1)

      ListItemRightAction({
        item: this.item,
        onSliderChange: (v: number) => {
          this.item.value = v;
          if (this.item.onChange) {
            this.item.onChange(v)
          }
        }
      })
    }
    .enabled(this.item.enabled)
    .padding(this.itemPadding)
    .alignItems(VerticalAlign.Center)
    .justifyContent(FlexAlign.SpaceBetween)
    .bindMenu(
      this.showMenu,
      this.item.type == ItemActionType.MENU ? MenuSelectWitch(this.item, (menu) => {
        this.item.value = menu.value
      }) : undefined,
      {
        placement: Placement.BottomRight,
        backgroundBlurStyle: BlurStyle.NONE,
        onDisappear: () => {
          this.showMenu = false
        }
      })
    .width("100%")
    .onClick(() => {
      if (!this.item.enabled) return

      if (this.item.type == ItemActionType.MENU) {
        this.showMenu = true
        return
      }

      if (this.item.type == ItemActionType.TOGGLE) {
        this.item.value = !this.item.value
      }

      if (this.item.type == ItemActionType.RADIO) {
        this.item.value = this.item.radioConfig?.value || ''
      }

      if (this.item.type == ItemActionType.CHECK) {
        this.item.value = !this.item.value
      }

      if (this.item.type == ItemActionType.DIALOG) {
        this.dialogController?.open()
      }

      if (this.item.onChange) this.item.onChange(this.item.value)
    })
  }
}

// 右侧通用操作组件
@ComponentV2
export struct ListItemRightAction {
  @Require @Param item: CustomItemInfo
  @Event onSliderChange: (p: number) => void

  getMenuLabel(): ResourceStr {
    const currentVal = this.item.value;
    const found = this.item.menuOptions?.find(m => m.value === currentVal);
    return found?.label || found?.value || currentVal as ResourceStr;
  }

  build() {
    Row() {
      if (this.item.type == ItemActionType.MENU) {
        Row({ space: 8 }) {
          Text(this.getMenuLabel()).menuText()
            .fontColor(this.item.enabled ? $r('sys.color.font_primary') : ColorUtils.getUnableColor($r('sys.color.font_primary')))
          SymbolGlyph($r("sys.symbol.arrowtriangle_down_fill")).menuSymbolGlyph(14, this.item.enabled)
        }
      } else if (this.item.type == ItemActionType.TOGGLE) {
        Toggle({ type: ToggleType.Switch, isOn: this.item.value as boolean })
          .selectedColor(this.item.iconColor)
          .enabled(this.item.enabled)
          .hitTestBehavior(HitTestMode.None)
      } else if (this.item.type == ItemActionType.ROUTER) {
        SymbolGlyph($r("sys.symbol.chevron_right")).menuSymbolGlyph(24)
          .hitTestBehavior(HitTestMode.None)
      } else if (this.item.type == ItemActionType.TEXT) {
        Row({ space: 8 }) {
          Text(this.item.value as ResourceStr)
            .fontSize(15)
          SymbolGlyph($r("sys.symbol.chevron_right")).menuSymbolGlyph(24)
            .hitTestBehavior(HitTestMode.None)
        }
      } else if (this.item.type == ItemActionType.RADIO) {
        Radio({ value: this.item.radioConfig?.value || '', group: this.item.radioConfig?.group || '' })
          .size({ width: 24, height: 24 })
          .radioStyle({ checkedBackgroundColor: this.item.iconColor })
          .hitTestBehavior(HitTestMode.None)
          .checked(this.item.value == this.item.radioConfig?.value)
      } else if (this.item.type == ItemActionType.CHECK) {
        Checkbox().size({ width: 24, height: 24 }).select(this.item.value as boolean).hitTestBehavior(HitTestMode.None)
      } else if (this.item.type == ItemActionType.DIALOG) {
        Row({ space: 4 }) {
          Text(this.item.value as ResourceStr).menuText()
          SymbolGlyph($r("sys.symbol.chevron_right")).menuSymbolGlyph(24)
        }
      } else if (this.item.type == ItemActionType.SLIDER) {
        Row() {
          Text(`${((this.item.value || 0) as number).toFixed(1)} ${this.item.sliderConfig?.unit || ""}`)
            .menuText()
            .margin({ right: this.item.sliderConfig?.showControl ? 5 : 0 })
          if (this.item.sliderConfig?.showControl) {
            SymbolGlyph($r("sys.symbol.minus_circle_fill"))
              .menuSymbolGlyph(21)
              .onClick(() => {
                const minus = this.item.sliderConfig?.step || 1
                const old = this.item.value as number
                this.onSliderChange(old - minus)
              })
          }
          Slider({
            value: this.item.value as number,
            min: this.item.sliderConfig?.min || 0,
            max: this.item.sliderConfig?.max || 100,
            style: SliderStyle.InSet,
            step: this.item.sliderConfig?.step || 5
          }).showSteps(true)
            .blockColor(Color.White)
            .trackThickness(20)
            .minResponsiveDistance(1)
            .onChange((v: number) => {
              this.onSliderChange(v)
            }).layoutWeight(1)
          if (this.item.sliderConfig?.showControl) {
            SymbolGlyph($r("sys.symbol.plus_circle_fill"))
              .menuSymbolGlyph(21)
              .onClick(() => {
                const plus = this.item.sliderConfig?.step || 1
                const old = this.item.value as number
                this.onSliderChange(old + plus)
              })
          }
        }
      }
    }
    .height(35)
    .layoutWeight(this.item.type == ItemActionType.SLIDER ? 2 : undefined)
    .justifyContent(FlexAlign.End)
  }
}

// 样式扩展
@Extend(Text)
function menuText() {
  .fontSize(14).fontColor($r('sys.color.font_primary'))
}

@Extend(SymbolGlyph)
function menuSymbolGlyph(size: number, enable: boolean = true) {
  .fontSize(size)
  .fontColor([enable ? $r("sys.color.menu_text_normal_color") : ColorUtils.getUnableColor($r("sys.color.menu_text_normal_color"))])
}

// 菜单通用组件
@Builder
export function MenuSelectWitch(item: CustomItemInfo, onSelect: (item: MenuOption) => void) {
  Menu() {
    MenuItem({ content: item.label }).contentFont({ weight: FontWeight.Bold })

    Repeat<MenuOption>(item.menuOptions || [])
      .each((ri: RepeatItem<MenuOption>) => {
        MenuItem({
          content: ri.item.label ?? ri.item.value,
          symbolStartIcon: ri.item.symbolIcon ? defaultIcon(ri) : undefined,
          symbolEndIcon: item.value == ri.item.value ? new SymbolGlyphModifier($r("sys.symbol.checkmark")).fontColor([menuColor(item, ri)]) : undefined,
        })
          .contentFont({ size: 16 })
          .contentFontColor(menuColor(item, ri))
          .onClick(() => {
            if (item.menuDisabled && item.menuDisabled(ri.item, ri.index)) {
              // 禁用状态不处理
            } else {
              onSelect(ri.item)
              if (item.onChange) {
                item.onChange(ri.item.value)
              }
              item.value = ri.item.value
            }
          })
      }).key((menu: MenuOption) => menu.value.toString())
  }
  .menuItemDivider({ color: $r("sys.color.alert_divider_color"), strokeWidth: LengthMetrics.vp(1), startMargin: LengthMetrics.vp(UIConstants.PADDING_VALUE_12), endMargin: LengthMetrics.vp(UIConstants.PADDING_VALUE_12) })
  .backgroundColor($r("app.color.start_window_background"))
  .borderRadius(UIConstants.BORDER_RADIUS_20)
}

function defaultIcon(menu: RepeatItem<MenuOption>) {
  if (menu.item.symbolIcon == null) return new SymbolGlyphModifier($r("sys.symbol.checkmark"))
  return menu.item.symbolIcon
}

function menuColor(item: CustomItemInfo, menu: RepeatItem<MenuOption>): ResourceColor {
  if (item.menuDisabled == null) {
    return $r("sys.color.font_primary");
  }
  return item.menuDisabled(menu.item, menu.index) ? $r("sys.color.font_tertiary") : $r("sys.color.font_primary");
}

// 辅助构建函数
export function makeCustomItems<T>(data: T, callBack: (t: T) => CustomItemInfo[]) {
  return callBack(data);
}
