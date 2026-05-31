import { CustomItemInfo, ItemActionType, ItemGroupData, makeItemGroups, DialogConfig } from "../../common/entity/CusItemInfo"
import { toastUtil } from "../../common/utils/ToastUtils"
import { CustomListItem } from "../../components/CusItemBuilder"
import { NaviContainer } from "../../components/NaviContainer"
import { PixState } from "../../entryability/AppState"
import { appDataVM } from "../../viewmodel/AppDataViewModel"
import { ResourceUtils } from "../../common/utils/ResourceUtil"

@Builder
export function AppDataBuilder() {
  AppData()
}


@ComponentV2
struct AppData {
  private pageStack: NavPathStack = new NavPathStack()

  private get itemList(): CustomItemInfo[] {
    // 提取基础国际化字符串用于拼接
    const exportStr = ResourceUtils.getString($r('app.string.export'));
    const importStr = ResourceUtils.getString($r('app.string.import'));
    const illustHistoryStr = ResourceUtils.getString($r('app.string.browse_records'));
    const searchHistoryStr = ResourceUtils.getString($r('app.string.search_records'));
    const downloadHistoryStr = ResourceUtils.getString($r('app.string.download_records'));
    const settingsStr = ResourceUtils.getString($r('app.string.preference'));

    const importConfirmStr = ResourceUtils.getString($r('app.string.import_confirm'));
    const overridePrefix = ResourceUtils.getString($r('app.string.import_override_prefix'));
    const overrideSuffix = ResourceUtils.getString($r('app.string.import_override_suffix'));

    return [
      // 浏览历史
      new CustomItemInfo({ id: 'illust_history', title: $r('app.string.browse_records'), type: ItemActionType.GROUP }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.doc_text_badge_arrow_up'),
        title: `${exportStr}${illustHistoryStr}`, // 导出浏览记录
        type: ItemActionType.ROUTER,
        id: 'export_ih',
        onChange: () => { appDataVM.exportIllustHistory() }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.arrow_down_layer'),
        title: `${importStr}${illustHistoryStr}`, // 导入浏览记录
        type: ItemActionType.ROUTER,
        id: 'import_ih',
        onChange: () => {
          toastUtil.showAlertDialog({
            title: importConfirmStr,
            message: `${overridePrefix}${illustHistoryStr}${overrideSuffix}`, // 导入将会覆盖当前的浏览记录，是否继续？
            primaryButton: { value: importStr, action: () => appDataVM.importIllustHistory() },
            secondaryButton: { value: $r('app.string.cancel'), action: () => {} }
          });
        }
      }),

      // 搜索记录
      new CustomItemInfo({ id: 'search_history', title: $r('app.string.search_records'), type: ItemActionType.GROUP }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.doc_text_badge_arrow_up'),
        title: `${exportStr}${searchHistoryStr}`,
        type: ItemActionType.ROUTER,
        id: 'export_sh',
        onChange: () => { appDataVM.exportSearchHistory() }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.arrow_down_layer'),
        title: `${importStr}${searchHistoryStr}`,
        type: ItemActionType.ROUTER,
        id: 'import_sh',
        onChange: () => {
          toastUtil.showAlertDialog({
            title: importConfirmStr,
            message: `${overridePrefix}${searchHistoryStr}${overrideSuffix}`,
            primaryButton: { value: importStr, action: () => appDataVM.importSearchHistory() },
            secondaryButton: { value: $r('app.string.cancel'), action: () => {} }
          });
        }
      }),

      // 下载记录
      new CustomItemInfo({ id: 'download_history', title: $r('app.string.download_records'), type: ItemActionType.GROUP }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.doc_text_badge_arrow_up'),
        title: `${exportStr}${downloadHistoryStr}`,
        type: ItemActionType.ROUTER,
        id: 'export_dl',
        onChange: () => { appDataVM.exportDownloadRecords() }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.arrow_down_layer'),
        title: `${importStr}${downloadHistoryStr}`,
        type: ItemActionType.ROUTER,
        id: 'import_dl',
        onChange: () => {
          toastUtil.showAlertDialog({
            title: importConfirmStr,
            message: `${overridePrefix}${downloadHistoryStr}${overrideSuffix}`,
            primaryButton: { value: importStr, action: () => appDataVM.importDownloadRecords() },
            secondaryButton: { value: $r('app.string.cancel'), action: () => {} }
          });
        }
      }),

      // 偏好设置
      new CustomItemInfo({ id: 'app_settings', title: $r('app.string.preference'), type: ItemActionType.GROUP }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.doc_text_badge_arrow_up'),
        title: `${exportStr}${settingsStr}`,
        type: ItemActionType.ROUTER,
        id: 'export_set',
        onChange: () => { appDataVM.exportSettings() }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.arrow_down_layer'),
        title: `${importStr}${settingsStr}`,
        type: ItemActionType.ROUTER,
        id: 'import_set',
        onChange: () => {
          toastUtil.showAlertDialog({
            title: importConfirmStr,
            message: `${overridePrefix}${settingsStr}${overrideSuffix}`,
            primaryButton: { value: importStr, action: () => appDataVM.importSettings() },
            secondaryButton: { value: $r('app.string.cancel'), action: () => {} }
          });
        }
      }),

      // 存储管理
      new CustomItemInfo({ id: 'storage', title: $r('app.string.storage_management'), type: ItemActionType.GROUP }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.trash'),
        title: $r('app.string.clear_image_cache'),
        subtitle: $r('app.string.confirm_clear_image_cache'),
        type: ItemActionType.DIALOG,
        id: 'clear_image_cache',
        isDanger: true,
        value: appDataVM.imageCacheSize,
        dialogConfig: new DialogConfig({
          buttons: [$r('app.string.cancel'), $r('app.string.clear')],
          onClick: (btn, index, dialog) => {
            if (index === 1) appDataVM.clearCache('ImageKnife');
            dialog?.close()
          }
        })
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.trash'),
        title: $r('app.string.clear_download_cache'),
        subtitle: $r('app.string.confirm_clear_download_cache'),
        type: ItemActionType.DIALOG,
        id: 'clear_download_cache',
        isDanger: true,
        value: appDataVM.pictureCacheSize,
        dialogConfig: new DialogConfig({
          buttons: [$r('app.string.cancel'), $r('app.string.clear')],
          onClick: (btn, index, dialog) => {
            if (index === 1) appDataVM.clearCache('Pixiv/Pictures');
            dialog?.close()
          }
        })
      }),
    ]
  }

  aboutToAppear() {
    appDataVM.calculateCacheSize();
  }

  build() {
    NaviContainer({
      title: $r('app.string.app_data'),
      content: () => { this.Content() },
      onReady: (ctx) => { this.pageStack = ctx.pathStack },
      onBackPressed: () => { return false },
      onNaviDisAppear: () => {} })
  }

  @Builder Content() {
    Column() {
      List({ space: 16 }) {
        ForEach(makeItemGroups(this.itemList), (group: ItemGroupData) => {
          ListItemGroup({ header: group.group?.title ? this.GroupHeader(group.group.title) : undefined }) {
            ForEach(group.items, (item: CustomItemInfo) => {
              ListItem() {
                CustomListItem({
                  item: item,
                  itemPadding: { left: 16, right: 16, top: 12, bottom: 12 }
                })
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

  @Builder
  GroupHeader(title: ResourceStr) {
    Text(title).fontSize(14).width('100%')
      .padding({ left: 4, top: 8, bottom: 4 })
      .fontColor($r('sys.color.font_secondary'))
  }

}
