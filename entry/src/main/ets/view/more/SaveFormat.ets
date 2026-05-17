import { NaviContainer } from "../../components/NaviContainer"
import { SymbolGlyphModifier } from "@kit.ArkUI"
import { toastUtil } from "../../common/utils/ToastUtils"
import { appSettings } from "../../common/entity/SettingsModel"
import { FunctionConstants } from "../../common/constants/FunctionConstants";


// 变量说明项数据结构
interface PlaceholderItem {
  tag: string;
  desc: string;
  example: string;
}

@Builder
export function SaveFormatBuilder() {
  SaveFormat()
}

@ComponentV2
struct SaveFormat {
  private pageStack: NavPathStack = new NavPathStack()
  // 使用本地状态暂存编辑中的格式，避免直接修改全局设置导致未点保存就生效
  @Local tempFormat: string = appSettings.file_name || FunctionConstants.DEFAULT_SAVE_FORMAT;

  // 变量说明表数据源
  private placeholderList: PlaceholderItem[] = [
    { tag: '{illust_id}', desc: '作品ID', example: '12345678' },
    { tag: '{part}', desc: '多图序号', example: '0, 1' },
    { tag: '{title}', desc: '作品标题', example: '阳光沙滩' },
    { tag: '{user_name}', desc: '画师名称', example: '小可爱' },
    { tag: '{uid}', desc: '画师UID', example: '9876543' },
    { tag: '_', desc: '下划线', example: '_' },
    { tag: 'p', desc: '图号类型', example: 'p' }
  ];

  build() {
    NaviContainer({
      title: $r('app.string.file_save_format'),
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
          this.tempFormat = FunctionConstants.DEFAULT_SAVE_FORMAT;
        }
      }
    ];
    btns.push({
      value: '',
      symbolIcon: new SymbolGlyphModifier($r('sys.symbol.save')),
      action: () => {
        // 保存格式到持久化
        appSettings.file_name = this.tempFormat.trim() || FunctionConstants.DEFAULT_SAVE_FORMAT;
        appSettings.save();
        toastUtil.showToast({ message: '保存成功' });
      }
    });
    return btns;
  }

  // 实时预览生成器
  private getPreview(): string {
    return this.tempFormat
      .replace(/{illust_id}/g, '12345678')
      .replace(/{part}/g, '0')
      .replace(/{title}/g, '阳光沙滩')
      .replace(/{user_name}/g, '小可爱')
      .replace(/{uid}/g, '9876543') + '.jpg';
  }

  @Builder
  Content() {
    Scroll() {
      Column({ space: 16 }) {
        // 格式输入区
        Column({ space: 8 }) {
          Text('文件名格式')
            .fontSize(14)
            .width('100%')
            .fontColor($r('sys.color.font_secondary'))
          TextInput({ text: $$this.tempFormat, placeholder: '请输入保存格式' })
            .type(InputType.Normal)
            .width('100%')
            .height(48)
            .borderRadius(8)
            .onChange((value: string) => {
              this.tempFormat = value;
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 16 })

        // 实时预览区
        Column({ space: 8 }) {
          Text('预览效果')
            .fontSize(14)
            .width('100%')
            .fontColor($r('sys.color.font_secondary'))
          Text(this.getPreview())
            .fontSize(16)
            .fontColor($r('sys.color.ohos_id_color_emphasize'))
            .fontWeight(FontWeight.Bold)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .width('100%')
        .padding(16)
        .margin({ left: 16, right: 16 })
        .borderRadius(12)
        // .backgroundColor($r('sys.color.comp_container_bg'))

        // 变量说明表
        Column({ space: 12 }) {
          Text('可用变量 (点击插入)')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .margin({ top: 8 })

          // 表头
          Row() {
            Text('占位符')
              .fontColor($r('sys.color.font_secondary'))
              .fontSize(13)
              .width('40%')
            Text('说明')
              .fontSize(13)
              .layoutWeight(1)
              .fontColor($r('sys.color.font_secondary'))
            Text('示例')
              .fontSize(13)
              .width('25%')
              .textAlign(TextAlign.End)
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')

          Divider().color('#F0F0F0')

          // 列表内容
          ForEach(this.placeholderList, (item: PlaceholderItem) => {
            Row() {
              Text(item.tag)
                .fontSize(14)
                .fontColor($r('sys.color.ohos_id_color_emphasize'))
                .fontFamily('monospace')
                .width('40%')
              Text(item.desc)
                .fontSize(14)
                .layoutWeight(1)
                .fontColor($r('sys.color.font_secondary'))
              Text(item.example)
                .fontSize(13)
                .width('25%')
                .textAlign(TextAlign.End)
                .fontColor($r('sys.color.font_tertiary'))
            }
            .width('100%')
            .height(48)
            .borderRadius(8)
            .padding({ left: 12, right: 12 })
            .backgroundColor($r('sys.color.button_background_color_transparent'))
            .onClick(() => {
              // 点击将变量追加到输入框
              this.tempFormat += item.tag;
            })
          }, (item: PlaceholderItem) => item.tag)
        }
        .width('100%')
        .padding(16)
        .margin({ left: 16, right: 16, bottom: 32 })

      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
  }

}
