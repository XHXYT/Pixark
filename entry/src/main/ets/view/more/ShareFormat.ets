import { NaviContainer } from "../../components/NaviContainer"
import { SymbolGlyphModifier } from "@kit.ArkUI"
import { toastUtil } from "../../common/utils/ToastUtils"
import { appSettings } from "../../common/entity/SettingsModel"
import { FunctionConstants } from "../../common/constants/FunctionConstants";
import { SharePlaceholderItem } from "../../common/entity/PlaceholderItem";
import { PixState } from "../../entryability/AppState";

@Builder
export function ShareFormatBuilder() {
  ShareFormat()
}


@ComponentV2
struct ShareFormat {

  private pageStack: NavPathStack = new NavPathStack()

  @Local tempFormat: string = appSettings.share_text || FunctionConstants.DEFAULT_SHARE_FORMAT;

  // 变量说明表数据源
  private placeholderList: SharePlaceholderItem[] = [
    { tag: '{title}', desc: $r('app.string.title_desc'), example: $r('app.string.title_example') },
    { tag: '{illust_id}', desc: $r('app.string.illust_id_desc'), example: '12345678' },
    { tag: '{user_name}', desc: $r('app.string.user_name_desc'), example: $r('app.string.user_name_example') },
    { tag: '{uid}', desc: $r('app.string.uid_desc'), example: '9876543' },
    { tag: '{tags}', desc: $r('app.string.tags_desc'), example: $r('app.string.tags_example') },
    { tag: 'https://www.pixiv.net/artworks/{illust_id}', desc: $r('app.string.illust_link_desc'), example: $r('app.string.click_to_insert'), isFullInsert: true },
    { tag: 'https://www.pixiv.net/users/{uid}', desc: $r('app.string.user_link_desc'), example: $r('app.string.click_to_insert'), isFullInsert: true }
  ];

  build() {
    NaviContainer({
      title: $r('app.string.share_info_format'),
      content: () => {
        this.Content()
      },
      buttons: this.buttons(),
      onReady: (ctx) => {
        this.pageStack = ctx.pathStack
      },
      onBackPressed: () => {
        return false
      },
      onNaviDisAppear: () => { }
    })
  }

  private buttons(): NavigationMenuItem[] {
    const btns: NavigationMenuItem[] = [
      {
        value: '',
        symbolIcon: new SymbolGlyphModifier($r('sys.symbol.arrow_2_circlepath')),
        action: () => {
          // 恢复默认格式
          this.tempFormat = FunctionConstants.DEFAULT_SHARE_FORMAT;
        }
      }
    ];
    btns.push({
      value: '',
      symbolIcon: new SymbolGlyphModifier($r('sys.symbol.save')),
      action: () => {
        // 保存格式到持久化
        appSettings.share_text = this.tempFormat.trim() || FunctionConstants.DEFAULT_SHARE_FORMAT;
        appSettings.save();
        toastUtil.showToast({ message: $r('app.string.success_save') });
      }
    });
    return btns;
  }

  // 实时预览生成器
  private getPreview(): string {
    return this.tempFormat
      .replace(/{title}/g, '阳光沙滩')
      .replace(/{illust_id}/g, '12345678')
      .replace(/{user_name}/g, '小可爱')
      .replace(/{uid}/g, '9876543')
      .replace(/{tags}/g, '插画, 风景');
  }

  @Builder
  Content() {
    Scroll() {
      Column({ space: 16 }) {
        // 格式输入区
        Column({ space: 8 }) {
          Text($r('app.string.share_text_format'))
            .fontSize(14)
            .width('100%')
            .fontColor($r('sys.color.font_secondary'))

          TextArea({ text: $$this.tempFormat, placeholder: $r('app.string.share_format_placeholder') })
            .width('100%')
            .height(120)
            .borderRadius(8)
            .onChange((value: string) => {
              this.tempFormat = value;
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16 })

        // 实时预览区
        Column({ space: 8 }) {
          Text($r('app.string.preview_effect'))
            .fontSize(14)
            .width('100%')
            .fontColor($r('sys.color.font_secondary'))

          Text(this.getPreview())
            .fontSize(15)
            .fontColor($r('sys.color.ohos_id_color_emphasize'))
            .fontWeight(FontWeight.Medium)
            .maxLines(5)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .margin({ left: 16, right: 16 })
        .borderRadius(12)
        .alignItems(HorizontalAlign.Start)

        // 变量说明表
        Column({ space: 12 }) {
          Text($r('app.string.available_variables'))
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .margin({ top: 8 })

          // 表头
          Row() {
            Text($r('app.string.placeholder_template'))
              .fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
              .layoutWeight(1)

            Text($r('app.string.description'))
              .fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
              .width('20%')
              .textAlign(TextAlign.Center)

            Text($r('app.string.action'))
              .fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
              .width('25%')
              .textAlign(TextAlign.End)
          }
          .width('100%')

          Divider().color('#F0F0F0')

          // 列表内容
          ForEach(this.placeholderList, (item: SharePlaceholderItem) => {
            Row() {
              Text(item.tag)
                .fontSize(14)
                .fontColor($r('sys.color.ohos_id_color_emphasize'))
                .fontFamily('monospace')
                .maxLines(3)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)

              Text(item.desc)
                .fontSize(14)
                .fontColor($r('sys.color.font_secondary'))
                .width('20%')
                .textAlign(TextAlign.Center)

              Text(item.isFullInsert ? $r('app.string.insert_template') : $r('app.string.insert'))
                .fontSize(13)
                .fontColor($r('sys.color.ohos_id_color_emphasize'))
                .width('25%')
                .textAlign(TextAlign.End)
            }
            .padding(12)
            .width('100%')
            .borderRadius(8)
            .backgroundColor($r('sys.color.button_background_color_transparent'))
            .onClick(() => {
              // 点击将变量追加到输入框
              this.tempFormat += item.tag;
            })
          }, (item: SharePlaceholderItem) => item.tag)
        }
        .width('100%')
        .padding(16)
        .margin({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .contentEndOffset(PixState.bottomRectHeight)
  }

}
