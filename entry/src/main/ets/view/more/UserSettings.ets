import { CustomItemInfo, ItemActionType,
  ItemGroupData,
  makeItemGroups,
  MenuOption } from "../../common/entity/CusItemInfo"
import { appSettings } from "../../common/entity/SettingsModel"
import { EventHub, EventKey } from "../../common/utils/EventHub"
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
      new CustomItemInfo({ id: 'general', title: '通用设置', type: ItemActionType.GROUP }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.paintpalette_fill'),
        title: '颜色模式',
        type: ItemActionType.MENU,
        id: 'theme_mode',
        value: appSettings.color_mode.toString(), // 默认跟随系统
        menuOptions: [
          new MenuOption('1', '浅色模式'),
          new MenuOption('0', '深色模式'),
          new MenuOption('-1', '跟随系统')
        ],
        onChange: (value) => {
          appSettings.color_mode = Number(value)
          SettingsUtils.setColorMode()
          appSettings.save()
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.Language_arrow_2_circlepath'),
        title: '语言',
        type: ItemActionType.MENU,
        id: 'language',
        value: appSettings.language,
        menuOptions: [
          new MenuOption('zh-CN', '简体中文'),
          new MenuOption('en', 'English')
        ],
        onChange: (value) => {
          appSettings.language = value as string
          SettingsUtils.setLanguage()
          appSettings.save()
        }
      }),
      // 浏览与展示
      new CustomItemInfo({ id: 'display', title: '浏览与展示', type: ItemActionType.GROUP }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.doc_plaintext_fill'),
        title: '列表预览质量',
        type: ItemActionType.MENU,
        id: 'image_list_quality',
        value: 'medium',
        menuOptions: [
          new MenuOption('medium', '中等 (省流)'),
          new MenuOption('large', '大图 (清晰)'),
          new MenuOption('original', '原图 (极耗流量)')
        ],
        onChange: (value) => {
          // TODO: 修改图片质量逻辑
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.picture_fill'),
        title: '插画详情质量',
        type: ItemActionType.MENU,
        id: 'image_detail_quality',
        value: 'medium',
        menuOptions: [
          new MenuOption('medium', '中等 (省流)'),
          new MenuOption('large', '大图 (清晰)'),
          new MenuOption('original', '原图 (耗流)')
        ],
        onChange: (value) => {
          // TODO: 修改图片质量逻辑
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.fullscreen'),
        title: '大图查看质量',
        type: ItemActionType.MENU,
        id: 'image_big_quality',
        value: 'medium',
        menuOptions: [
          new MenuOption('medium', '中等 (省流)'),
          new MenuOption('large', '大图 (清晰)'),
          new MenuOption('original', '原图 (耗流)')
        ],
        onChange: (value) => {
          // TODO: 修改图片质量逻辑
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.heart_house_fill'),
        title: '首页展示',
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
          appSettings.show_H = !value as boolean
          appSettings.save()
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.ai_edit'),
        title: '显示 AI 作品标记',
        type: ItemActionType.TOGGLE,
        id: 'sign_ai',
        value: appSettings.show_ai_sign,
        onChange: (value) => {
          appSettings.show_ai_sign = value as boolean
          appSettings.save()
        }
      }),
      // 个人偏好
      new CustomItemInfo({ id: 'download', title: '个人偏好', type: ItemActionType.GROUP }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.arrow_down_layer'),
        title: '同时下载数目',
        type: ItemActionType.MENU,
        id: 'download_sum',
        value: appSettings.download_sum,
        menuOptions: [
          new MenuOption('3', '3'),
          new MenuOption('5', '5'),
          new MenuOption('10', '10')
        ],
        onChange: (value) => {
          appSettings.download_sum = value.toString()
          appSettings.save()
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.AI_typeset'),
        title: '分享格式',
        type: ItemActionType.ROUTER,
        id: 'share_format',
        onChange: (value) => {
          // TODO: 修改分享格式
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.doc_text'),
        title: '保存格式',
        type: ItemActionType.ROUTER,
        id: 'file_format',
        onChange: (value) => {
          // TODO: 修改文件格式
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.person_badge_heart_fill'),
        title: '收藏后关注画师',
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
        title: '默认私密收藏',
        type: ItemActionType.TOGGLE,
        id: 'sign_ai',
        value: appSettings.show_ai_sign,
        onChange: (value) => {
          appSettings.show_ai_sign = value as boolean
          appSettings.save()
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.download_fill'),
        title: '收藏后自动下载',
        type: ItemActionType.TOGGLE,
        id: 'download_after_collecting',
        value: appSettings.download_after_collecting,
        onChange: (value) => {
          appSettings.download_after_collecting = value as boolean
          appSettings.save()
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.globe_badge_heart'),
        title: '下载时自动收藏',
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
      .contentEndOffset(PixState.bottomRectHeight)
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
