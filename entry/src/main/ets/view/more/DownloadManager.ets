import { PixState } from "../../entryability/AppState";
import { createLogger } from "../../utils/Logger";
import { DownloadsViewModel, downloaderVM } from "../../viewmodel/DownloadsViewModel";
import { SegmentButtonV2Items, TabSegmentButtonV2 } from "@kit.ArkUI";
import { request } from "@kit.BasicServicesKit";
import DownloadRecordInfo from "../../entity/DownloadRecordInfo";

const logger = createLogger('DownloadManager');

@Builder
export function DownloadManagerBuilder() {
  DownloadManager()
}


@ComponentV2
struct DownloadManager {
  @Local dVM: DownloadsViewModel = downloaderVM
  private pageStack: NavPathStack = new NavPathStack()
  private panOptionL: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Left })
  private panOptionR: PanGestureOptions = new PanGestureOptions({ direction: PanDirection.Right })

  private downloadTabItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: $r('app.string.tasks') },
    { text: $r('app.string.downloading') },
    { text: $r('app.string.completed') },
    { text: $r('app.string.fail') }
  ]);

  aboutToAppear(): void {
    const context = this.getUIContext().getHostContext()!;
    // 初始化下载目录
    this.dVM.initDownLoad(context);
    // 刷新列表数据
    this.dVM.fetchSysTask(context);
  }

  build() {
    NavDestination() {
      Column() {
        // 筛选栏
        Row() {
          TabSegmentButtonV2({
            items: this.downloadTabItems,
            selectedIndex: this.dVM.currentPage!!,
            onItemClicked: (tab) => {
              this.dVM.currentPage = tab;
            }
          })
        }
        .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
        .width('100%')

        // 列表区域
        List({ space: 8 }) {
          ForEach(this.dVM.filterTask(), (item: DownloadRecordInfo) => {
            ListItem() {
              this.DownloadItemBuilder(item)
            }
            .swipeAction({ end: { builder: () => {
              this.DeleteSwipeButton(item)
            } } })
          }, (item: DownloadRecordInfo) => item.taskId)
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 8 })

      }
      .alignItems(HorizontalAlign.Center)
    }
    .padding({ top: PixState.topRectHeight, bottom: PixState.bottomRectHeight })
    .title($r('app.string.download_manage'))
    .hideToolBar(true)
    .menus(this.buttons())
    .onReady((ctx: NavDestinationContext) => {
      this.pageStack = ctx.pathStack
    })
  }

  // 列表项布局
  @Builder
  DownloadItemBuilder(item: DownloadRecordInfo) {
    Row() {
      // 左侧：作品信息
      Column() {
        Text(item.title || '未知作品')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        // 副标题：作者名 · 下载时间
        Text() {
          Span(item.artistName || '未知画师')
          Span(' · ')
          Span(this.formatTime(item.createTime))
        }
        .fontSize(13)
        .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      // 右侧：状态与操作
      Row({ space: 8 }) {
        // 根据状态渲染不同控件
        if (item.status === request.agent.State.COMPLETED) {
          // 完成状态
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(20)
            .fontColor([$r('sys.color.ohos_id_color_palette4')])
        } else if (item.status === request.agent.State.RUNNING || item.status === request.agent.State.RETRYING) {
          // 下载中：显示进度和暂停
          Text(item.progress || '0%')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_emphasize'))

          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.pause_fill'))
              .fontSize(18)
              .fontColor([$r('sys.color.ohos_id_color_primary')])
          }
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            const context = this.getUIContext().getHostContext()!;
            this.dVM.pauseSysTask(context, item.taskId);
          })
        } else if (item.status === request.agent.State.PAUSED) {
          // 暂停：继续
          Button('继续')
            .fontSize(14)
            .height(32)
            .onClick(() => {
              const context = this.getUIContext().getHostContext()!;
              this.dVM.resumeSysTask(context, item.taskId);
            })
        } else if (item.status === request.agent.State.FAILED || item.status === request.agent.State.STOPPED) {
          // 失败/停止：重试和删除
          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.arrow_clockwise'))
              .fontSize(18)
              .fontColor([$r('sys.color.ohos_id_color_primary')])
          }
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            const context = this.getUIContext().getHostContext()!;
            this.dVM.restartSysTask(context, item.taskId);
          })

          Button({ type: ButtonType.Circle }) {
            SymbolGlyph($r('sys.symbol.trash_fill'))
              .fontSize(18)
              .fontColor([Color.Red])
          }
          .backgroundColor(Color.Transparent)
          .onClick(() => this.deleteTask(item))
        } else {
          // 等待中
          Text('等待中...')
            .fontSize(14)
            .fontColor($r('sys.color.ohos_id_color_text_secondary'))
        }
      }
    }
    .width('100%')
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('sys.color.background_secondary'))
    .onClick(() => {
      // 打开插画详情
      this.openIllust(item.illustId);
    })
  }

  // 侧滑删除按钮
  @Builder
  DeleteSwipeButton(item: DownloadRecordInfo) {
    Button({ type: ButtonType.Circle }) {
      SymbolGlyph($r('sys.symbol.trash_fill'))
        .fontSize(20)
        .fontColor([Color.White])
    }
    .width(48)
    .height(48)
    .backgroundColor(Color.Red)
    .margin({ right: 16, left: 5 })
    .onClick(() => this.deleteTask(item))
  }

  private buttons(): NavigationMenuItem[] {
    return []
  }

  // 执行删除
  private async deleteTask(item: DownloadRecordInfo) {
    const context = this.getUIContext().getHostContext()!;
    await this.dVM.removeTask(context, item);
  }

  // 打开插画详情
  private async openIllust(illustID: number | undefined) {
    if (!illustID) return;

  }

  // 简单的时间格式化
  private formatTime(timestamp: number): string {
    if (!timestamp) return '';
    const date = new Date(timestamp);
    return `${date.getMonth() + 1}/${date.getDate()} ${date.getHours()}:${String(date.getMinutes()).padStart(2, '0')}`;
  }

}
