import { NaviContainer } from "../../components/NaviContainer";
import { PixState } from "../../entryability/AppState";
import { muteFilter } from "../../services/MuteFilter";
import MuteRuleInfo from "../../common/entity/MuteRuleInfo";
import { appSettings } from "../../common/entity/SettingsModel";
import { toastUtil } from "../../common/utils/ToastUtils";
import { SegmentButtonV2Items, TabSegmentButtonV2 } from '@kit.ArkUI';
import { CustomItemInfo, ItemActionType } from "../../common/entity/CusItemInfo";
import { CustomListItem } from "../../components/CusItemBuilder";

/** 屏蔽设定（标签 / 画师 / 作品三类规则管理） */
@Builder
export function MuteSettingsBuilder() {
  MuteSettings()
}

@ComponentV2
struct MuteSettings {

  /** 当前分区：0 标签 1 画师 2 作品 */
  @Local typeIndex: number = 0
  @Local tagRules: MuteRuleInfo[] = []
  @Local userRules: MuteRuleInfo[] = []
  @Local illustRules: MuteRuleInfo[] = []
  /** 添加面板 */
  @Local showAddSheet: boolean = false
  @Local addInput: string = ''

  private tabItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: $r('app.string.mute_tag') },
    { text: $r('app.string.mute_artist') },
    { text: $r('app.string.mute_work') },
  ]);

  /** 屏蔽总开关（与设置页同款行组件） */
  private masterItem: CustomItemInfo = new CustomItemInfo({
    symbol: $r('sys.symbol.eye_slash'),
    title: $r('app.string.mute_enable'),
    subtitle: $r('app.string.mute_enable_sub'),
    type: ItemActionType.TOGGLE,
    id: 'mute_enabled',
    value: appSettings.mute_enabled,
    onChange: (value) => {
      appSettings.mute_enabled = value as boolean
      appSettings.save()
    }
  })

  async aboutToAppear(): Promise<void> {
    await muteFilter.ensureLoaded()
    this.refreshRules()
  }

  build() {
    NaviContainer({
      title: $r('app.string.mute_settings'),
      content: () => {
        this.Content()
      },
      onReady: (ctx: NavDestinationContext) => {
      },
      onBackPressed: () => {
        return false
      }
    })
  }

  /** 从内存索引刷新三类规则 */
  private refreshRules(): void {
    this.tagRules = muteFilter.getTagRules()
    this.userRules = muteFilter.getUserRules()
    this.illustRules = muteFilter.getIllustRules()
  }

  private currentRules(): MuteRuleInfo[] {
    if (this.typeIndex === 1) {
      return this.userRules
    }
    if (this.typeIndex === 2) {
      return this.illustRules
    }
    return this.tagRules
  }

  private currentType(): string {
    if (this.typeIndex === 1) {
      return 'user'
    }
    if (this.typeIndex === 2) {
      return 'illust'
    }
    return 'tag'
  }

  @Builder
  Content() {
    Column() {
      List({ space: 8 }) {
        // 总开关
        ListItem() {
          this.MasterToggle()
        }
        // 分区切换 + 添加按钮
        ListItem() {
          Row() {
            TabSegmentButtonV2({
              items: this.tabItems,
              selectedIndex: this.typeIndex,
              onItemClicked: (index: number) => {
                this.typeIndex = index
              }
            })
            .layoutWeight(1)

            Button() {
              SymbolGlyph($r('sys.symbol.plus'))
                .fontSize(18)
                .fontColor([Color.White])
            }
            .width(32)
            .height(32)
            .borderRadius(16)
            .padding(0)
            .margin({ left: 12 })
            .backgroundColor(PixState.currentThemeColor)
            .onClick(() => {
              this.addInput = ''
              this.showAddSheet = true
            })
          }
          .width('100%')
          .margin({ top: 4, bottom: 4 })
        }

        // 规则列表 / 空态
        if (this.currentRules().length === 0) {
          ListItem() {
            this.EmptyHint()
          }
        } else {
          ForEach(this.currentRules(), (rule: MuteRuleInfo) => {
            ListItem() {
              this.RuleRow(rule)
            }
          }, (rule: MuteRuleInfo) => `${rule.ruleType}_${rule.targetKey}`)
        }
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue, top: 4, bottom: PixState.bottomRectHeight })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
    .bindSheet(this.showAddSheet, this.AddSheet(), {
      height: 310,
      dragBar: true,
      showClose: true,
      onDisappear: () => {
        this.showAddSheet = false
      }
    })
  }

  /** 屏蔽总开关 */
  @Builder
  MasterToggle() {
    Column() {
      CustomListItem({ item: this.masterItem, itemPadding: { left: 16, right: 16, top: 12, bottom: 12 } })
    }
    .width('100%')
    .borderRadius(12)
    .backgroundColor($r('sys.color.comp_background_list_card'))
  }

  /** 空态提示（说明各分区的屏蔽入口） */
  @Builder
  EmptyHint() {
    Column({ space: 8 }) {
      if (this.typeIndex === 1) {
        Text($r('app.string.mute_empty_user'))
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
          .lineHeight(20)
      } else if (this.typeIndex === 2) {
        Text($r('app.string.mute_empty_illust'))
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
          .lineHeight(20)
      } else {
        Text($r('app.string.mute_empty_tag'))
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
          .lineHeight(20)
      }
    }
    .width('100%')
    .padding({ top: 48, left: 24, right: 24 })
    .constraintSize({ minHeight: 200 })
    .justifyContent(FlexAlign.Start)
  }

  /** 单条规则行 */
  @Builder
  RuleRow(rule: MuteRuleInfo) {
    Row({ space: 12 }) {
      Column({ space: 2 }) {
        Row({ space: 6 }) {
          if (rule.ruleType === 'tag' && rule.targetKey.startsWith('re:')) {
            Text($r('app.string.mute_regex_badge'))
              .fontSize(10)
              .fontColor(Color.White)
              .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              .borderRadius(4)
              .backgroundColor($r('sys.color.font_tertiary'))
          }
          Text(rule.name)
            .fontSize(14)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .constraintSize({ maxWidth: '86%' })

        if (rule.targetKey !== rule.name) {
          Text(rule.targetKey)
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.trash'))
        .fontSize(18)
        .fontColor([$r('sys.color.font_tertiary')])
        .padding(6)
        .onClick(() => {
          this.deleteRule(rule)
        })
    }
    .width('100%')
    .padding({ left: 14, right: 8, top: 10, bottom: 10 })
    .borderRadius(12)
    .backgroundColor($r('sys.color.comp_background_list_card'))
  }

  /** 删除规则 */
  private deleteRule(rule: MuteRuleInfo): void {
    muteFilter.removeRule(rule.ruleType, rule.targetKey).then(() => {
      this.refreshRules()
      toastUtil.showToast({ message: $r('app.string.mute_removed_name', rule.name) })
    })
  }

  /** 添加面板（底部弹层） */
  @Builder
  AddSheet() {
    Column({ space: 16 }) {
      if (this.typeIndex === 1) {
        Text($r('app.string.mute_add_user'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
      } else if (this.typeIndex === 2) {
        Text($r('app.string.mute_add_illust'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
      } else {
        Text($r('app.string.mute_add_tag'))
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
      }

      TextInput({ text: this.addInput, placeholder: this.addSheetHint() })
        .fontSize(15)
        .defaultFocus(true)
        .margin({ top: 20 })
        .onChange((value: string) => {
          this.addInput = value
        })
        .width('100%')

      if (this.typeIndex === 1) {
        Text($r('app.string.mute_add_user_tip'))
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
      } else if (this.typeIndex === 2) {
        Text($r('app.string.mute_add_illust_tip'))
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
      } else {
        Text($r('app.string.mute_add_tag_tip'))
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
      }

      Button($r('app.string.mute_add'))
        .width('100%')
        .backgroundColor(PixState.currentThemeColor)
        .onClick(() => {
          this.confirmAdd()
        })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: PixState.bottomRectHeight + 12 })
    .alignItems(HorizontalAlign.Start)
  }

  private addSheetHint(): ResourceStr {
    if (this.typeIndex === 1) {
      return $r('app.string.mute_add_user_hint')
    }
    if (this.typeIndex === 2) {
      return $r('app.string.mute_add_illust_hint')
    }
    return $r('app.string.mute_add_tag_hint')
  }

  /** 解析输入并添加规则：标签直接用原文；画师/作品支持纯 ID 或从链接中提取 ID */
  private confirmAdd(): void {
    const input = this.addInput.trim()
    if (!input) {
      return
    }
    const type = this.currentType()
    let key = ''
    if (type === 'tag') {
      key = input
    } else if (type === 'user') {
      key = this.extractId(input, ['users/(\\d+)', 'member\\.php\\?id=(\\d+)'])
    } else {
      key = this.extractId(input, ['artworks/(\\d+)', 'illust_id=(\\d+)'])
    }
    if (!key) {
      toastUtil.showToast({ message: $r('app.string.mute_invalid_input') })
      return
    }
    muteFilter.addRule(type, key, key).then((ok: boolean) => {
      if (ok) {
        this.addInput = ''
        this.showAddSheet = false
        this.refreshRules()
        toastUtil.showToast({ message: $r('app.string.mute_added') })
      } else {
        toastUtil.showToast({ message: $r('app.string.mute_add_failed') })
      }
    })
  }

  /** 纯数字直接返回，否则依次尝试正则从链接中提取 */
  private extractId(input: string, patterns: string[]): string {
    if (/^\d+$/.test(input)) {
      return input
    }
    for (const p of patterns) {
      const match = input.match(new RegExp(p))
      if (match && match[1]) {
        return match[1]
      }
    }
    return ''
  }
}
