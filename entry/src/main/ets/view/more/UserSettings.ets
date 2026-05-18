import { FunctionConstants } from "../../common/constants/FunctionConstants"
import { CustomItemInfo, ItemActionType,
  ItemGroupData,
  makeItemGroups,
  MenuOption } from "../../common/entity/CusItemInfo"
import { appSettings } from "../../common/entity/SettingsModel"
import { SettingsUtils } from "../../common/utils/SettingsUtils"
import { toastUtil } from "../../common/utils/ToastUtils"
import { CustomListItem } from "../../components/CusItemBuilder"
import { NaviContainer } from "../../components/NaviContainer"
import { PixState } from "../../entryability/AppState"


@Builder
export function UserSettingsBuilder() {
  UserSettings()
}

@ComponentV2
struct UserSettings {
  private pageStack: NavPathStack = new NavPathStack()

  private get itemList(): CustomItemInfo[] {
    return [
      // 通用设置
      new CustomItemInfo({ id: 'general', title: $r('app.string.general_settings'), type: ItemActionType.GROUP }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.paintpalette_fill'),
        title: $r('app.string.color_mode'),
        type: ItemActionType.MENU,
        id: 'color_mode',
        value: appSettings.color_mode.toString(), // 默认跟随系统
        menuOptions: [
          new MenuOption('1', $r('app.string.light_mode')),
          new MenuOption('0', $r('app.string.dark_mode')),
          new MenuOption('-1', $r('app.string.follow_system'))
        ],
        onChange: (value) => {
          appSettings.color_mode = Number(value)
          SettingsUtils.setColorMode()
          appSettings.save()
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.Language_arrow_2_circlepath'),
        title: $r('app.string.language'),
        type: ItemActionType.MENU,
        id: 'language',
        value: appSettings.language,
        menuOptions: [
          new MenuOption('zh-CN', $r('app.string.zh_cn')),
          new MenuOption('en', 'English')
        ],
        onChange: (value) => {
          appSettings.language = value as string
          SettingsUtils.setLanguage()
          appSettings.save()
        }
      }),
      // 浏览与展示
      new CustomItemInfo({ id: 'display', title: $r('app.string.browse_and_show'), type: ItemActionType.GROUP }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.doc_plaintext_fill'),
        title: $r('app.string.image_preview_quality'),
        type: ItemActionType.MENU,
        id: 'image_preview_quality',
        value:  appSettings.image_preview_quality,
        menuOptions: FunctionConstants.IMAGE_QUALITY_MENU,
        onChange: (value) => {
          appSettings.image_preview_quality = value as string
          appSettings.save()
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.picture_fill'),
        title: $r('app.string.image_detail_quality'),
        type: ItemActionType.MENU,
        id: 'image_detail_quality',
        value: appSettings.image_detail_quality,
        menuOptions: FunctionConstants.IMAGE_QUALITY_MENU,
        onChange: (value) => {
          appSettings.image_detail_quality = value as string
          appSettings.save()
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.fullscreen'),
        title: $r('app.string.image_view_quality'),
        type: ItemActionType.MENU,
        id: 'image_view_quality',
        value: appSettings.image_view_quality,
        menuOptions: FunctionConstants.IMAGE_QUALITY_MENU,
        onChange: (value) => {
          appSettings.image_view_quality = value as string
          appSettings.save()
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.heart_house_fill'),
        title: $r('app.string.main_show'),
        type: ItemActionType.MENU,
        id: 'main_show',
        value: appSettings.main_show,
        menuOptions: [
          new MenuOption('0', $r('app.string.home'), $r('sys.symbol.house')),
          new MenuOption('1', $r('app.string.rank'), $r('sys.symbol.ranking_badge_bolt')),
          new MenuOption('2', $r('app.string.favorite'), $r('sys.symbol.heart')),
          new MenuOption('3', $r('app.string.search'), $r('sys.symbol.curve_magnifyingglass')),
          new MenuOption('4', $r('app.string.more'), $r('sys.symbol.square_grid_2x2'))
        ],
        onChange: (value) => {
          appSettings.main_show = value as string
          appSettings.save()
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.camera_macro_slash_circle'),
        title: '不可以瑟瑟',
        type: ItemActionType.TOGGLE,
        id: 'no_H',
        value: !appSettings.show_H,
        onChange: (value) => {
          if (value) {
            toastUtil.showToast({ message: '不可以瑟瑟哦' })
          } else {
            toastUtil.showToast({ message: '可以瑟瑟' })
          };
          appSettings.show_H = !value as boolean
          appSettings.save()
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.ai_edit'),
        title: $r('app.string.display_ai_tag'),
        type: ItemActionType.TOGGLE,
        id: 'sign_ai',
        value: appSettings.show_ai_sign,
        onChange: (value) => {
          appSettings.show_ai_sign = value as boolean
          appSettings.save()
        }
      }),
      // 个人偏好
      new CustomItemInfo({ id: 'download', title: $r('app.string.personal_preference'), type: ItemActionType.GROUP }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.arrow_down_layer'),
        title: $r('app.string.the_number_of_downloads'),
        type: ItemActionType.MENU,
        id: 'max_download_count',
        value: appSettings.max_download_count,
        menuOptions: [
          new MenuOption('3', '3'),
          new MenuOption('5', '5'),
          new MenuOption('10', '10')
        ],
        onChange: (value) => {
          appSettings.max_download_count = value.toString()
          appSettings.save()
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.AI_typeset'),
        title: $r('app.string.share_format'),
        type: ItemActionType.ROUTER,
        id: 'share_format',
        onChange: () => {
          this.pushTo('share_format')
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.doc_text'),
        title: $r('app.string.file_save_format'),
        subtitle: appSettings.file_name,
        type: ItemActionType.ROUTER,
        id: 'file_save_format',
        onChange: () => {
          this.pushTo('file_save_format')
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.person_badge_heart_fill'),
        title: $r('app.string.follow_after_collecting'),
        type: ItemActionType.TOGGLE,
        id: 'follow_after_collecting',
        value: appSettings.follow_after_collecting,
        onChange: (value) => {
          appSettings.follow_after_collecting = value as boolean
          appSettings.save()
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.heart_square_stack_fill'),
        title: $r('app.string.private_collecting'),
        type: ItemActionType.TOGGLE,
        id: 'private_collecting',
        value: appSettings.private_collecting,
        onChange: (value) => {
          appSettings.private_collecting = value as boolean
          appSettings.save()
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.download_fill'),
        title: $r('app.string.download_after_collecting'),
        type: ItemActionType.TOGGLE,
        id: '',
        value: appSettings.download_after_collecting,
        onChange: (value) => {
          appSettings.download_after_collecting = value as boolean
          appSettings.save()
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.globe_badge_heart'),
        title: $r('app.string.collecting_when_download'),
        type: ItemActionType.TOGGLE,
        id: 'collecting_when_download',
        value: appSettings.collecting_when_download,
        onChange: (value) => {
          appSettings.collecting_when_download = value as boolean
          appSettings.save()
        }
      }),
    ]
  }

  build() {
    NaviContainer({
      title: $r('app.string.preference'),
      content: () => {
        this.Content()
      },
      onReady: (ctx) => {
        this.pageStack = ctx.pathStack
      },
      onBackPressed: () => {
        return false
      },
      onNaviDisAppear: () => {}
    })
  }

  @Builder
  Content() {
    Column() {
      List({ space: 16 }) {
        ForEach(makeItemGroups(this.itemList), (group: ItemGroupData) => {
          ListItemGroup({
            header: group.group?.title ? this.GroupHeader(group.group.title) : undefined
          }) {
            ForEach(group.items, (item: CustomItemInfo) => {
              ListItem() {
                CustomListItem({ item: item, itemPadding: { left: 16, right: 16, top: 12, bottom: 12 } })
              }
            })
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .contentEndOffset(PixState.bottomRectHeight || 28)
    }
    .width('100%')
    .height('100%')
    .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue})
  }

  /**
   * 分组标题
   */
  @Builder
  GroupHeader(title: ResourceStr) {
    Text(title)
      .fontSize(14)
      .width('100%')
      .padding({ left: 4, top: 8, bottom: 4 })
      .fontColor($r('sys.color.font_secondary'))
  }

  /**
   * 路由跳转辅助函数
   */
  pushTo(name: string, params?: Object) {
    if (PixState.widthBp > 1) {
      this.pageStack.pushPathByName(name, params, true);
    } else {
      PixState.pageStack.pushPathByName(name, params, true);
    }
  }

}
