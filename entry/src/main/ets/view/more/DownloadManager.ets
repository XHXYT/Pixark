import { PixState, _PixState } from "../../entryability/AppState";
import { createLogger } from "../../utils/Logger";
import { DownloadsViewModel, downloaderVM } from "../../viewmodel/DownloadsViewModel";
import { SegmentButtonV2Items, SymbolGlyphModifier, TabSegmentButtonV2 } from "@kit.ArkUI";
import { request } from "@kit.BasicServicesKit";
import DownloadRecordInfo from "../../entity/DownloadRecordInfo";
import { DetailPageParams } from "../../entity/IllustDetailEntity";
import { toastUtil } from "../../utils/ToastUtils";

const logger = createLogger('DownloadManager');

@Builder
export function DownloadManagerBuilder() {
  DownloadManager()
}


@ComponentV2
struct DownloadManager {

  @Local showMenu: boolean = false
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
    const context = _PixState.Context;
    // 初始化下载目录
    this.dVM.initDownLoad(context);
    // 刷新列表数据
    this.dVM.fetchSysTask();
  }

  build() {
    NavDestination() {
      Row().width('100%').height(1)
        .bindMenu(this.showMenu!!, this.menusBuilder,
          {
            offset: { x: 0, y: -15 },
            placement: Placement.BottomRight,
            onDisappear: () => {
              this.showMenu = false
            }
          })
      // 筛选栏
      Row() {
        TabSegmentButtonV2({
          items: this.downloadTabItems,
          selectedIndex: this.dVM.currentPage!!,
          onItemClicked: (tab) => {
            toastUtil.animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
              this.dVM.currentPage = tab;
            })
          }
        })
      }
      .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
      .width('100%')
      // 列表区域
      List({ space: 8 }) {
        ForEach(this.dVM.filterTask(), (item: DownloadRecordInfo) => {
          ListItem() {
            Row() {
              if (this.dVM.isEditMode) {
                Checkbox()
                  .select(this.dVM.isSelected(item.taskId))
                  .shape(CheckBoxShape.CIRCLE)
                  .margin({ right: 12 })
              }
              Column({ space: 5 }) {
                Row() {
                  // 左侧：作品信息
                  this.TitleBuilder(item)
                  // 右侧：状态与操作
                  if (!this.dVM.isEditMode) {
                    Row({ space: 8 }) {
                      // 根据状态渲染不同控件
                      if (item.status === request.agent.State.COMPLETED) {
                        // 完成状态
                        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
                          .fontSize(20)
                          .fontColor([$r('sys.color.ohos_id_color_palette4')])
                      } else if (item.status === request.agent.State.RUNNING || item.status === request.agent.State.RETRYING) {
                        // 下载中：显示进度和暂停
                        Text(item.progress.toString() || '0%')
                          .fontSize(14)
                          .fontColor($r('sys.color.ohos_id_color_emphasize'))

                        Button({ type: ButtonType.Circle }) {
                          SymbolGlyph($r('sys.symbol.pause_fill'))
                            .fontSize(18)
                            .fontColor([$r('sys.color.ohos_id_color_primary')])
                        }
                        .backgroundColor(Color.Transparent)
                        .onClick(() => {
                          this.dVM.pauseTask(item.taskId);
                        })
                      } else if (item.status === request.agent.State.PAUSED) {
                        // 暂停：继续
                        Button($r('app.string.continue'))
                          .fontSize(14)
                          .height(32)
                          .onClick(() => {
                            this.dVM.resumeTask(item.taskId);
                          })
                      } else if (item.status === request.agent.State.FAILED || item.status === request.agent.State.STOPPED) {
                        // 失败/停止：重试
                        Button({ type: ButtonType.Circle }) {
                          SymbolGlyph($r('sys.symbol.arrow_clockwise'))
                            .fontSize(18)
                            .fontColor([$r('sys.color.ohos_id_color_primary')])
                        }
                        .backgroundColor(Color.Transparent)
                        .onClick(() => {
                          this.dVM.restartTask(item.taskId);
                        })
                        // 删除
                        Button({ type: ButtonType.Circle }) {
                          SymbolGlyph($r('sys.symbol.trash_fill'))
                            .fontSize(18)
                            .fontColor([Color.Red])
                        }
                        .backgroundColor(Color.Transparent)
                        .onClick(() => this.deleteTask(item))
                      } else {
                        // 等待中
                        Text($r('app.string.in_line'))
                          .fontSize(14)
                          .fontColor($r('sys.color.ohos_id_color_text_secondary'))
                      }
                    }
                  }
                }
                .width('100%')
                if (item.status == request.agent.State.RUNNING) {
                  Progress({ value: item.progress, type: ProgressType.Linear })
                }
              }
            }
            .padding(16)
            .borderRadius(16)
            .backgroundColor($r('sys.color.button_background_color_transparent'))
          }
          .onClick(() => {
            if (!this.dVM.isEditMode) {
              // 打开插画详情
              this.openIllust(item.illustId);
            } else {
              this.dVM.toggleSelect(item.taskId);
            }
          })
          .swipeAction(this.dVM.isEditMode ? undefined : {
            end: { builder: () => { this.DeleteSwipeButton(item) } }
          })
          // 组件出现时的动画 (透明度从 0 到 1)
          .transition({
            type: TransitionType.Insert,
            opacity: 0,
          })
          // 组件消失时的动画 (透明度从 1 到 0，同时轻微缩小)
          .transition({
            type: TransitionType.Delete,
            opacity: 0,
            scale: { x: 0.95, y: 0.95 }
          })
        }, (item: DownloadRecordInfo) => item.taskId + item.status + item.progress)
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16, top: 8 })
      .contentEndOffset(PixState.bottomRectHeight)
      // 左滑手势
      .gesture(
        PanGesture(this.panOptionL)
          .onActionStart((event: GestureEvent) => {
            if (event) {
              const targetPage = this.dVM.currentPage == 3 ? 0 : this.dVM.currentPage + 1;
              toastUtil.animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
                this.dVM.currentPage = targetPage;
              })
            }
          }),
      )
      // 右滑滑手势
      .gesture(
        PanGesture(this.panOptionR)
          .onActionStart((event: GestureEvent) => {
            if (event) {
              const targetPage = this.dVM.currentPage == 0 ? 3 : this.dVM.currentPage - 1;
              toastUtil.animateTo({ duration: 300, curve: Curve.EaseInOut }, () => {
                this.dVM.currentPage = targetPage;
              })
            }
          }),
      )
      if (this.dVM.isEditMode) {
        Row() {
          Button("全选")
            .fontSize(16)
            .backgroundColor(Color.Transparent)
            .fontColor($r('sys.color.ohos_id_color_primary'))
            .onClick(() => {
              // 如果当前已全选，则取消全选；否则全选
              if (this.dVM.getSelectedCount() === this.dVM.filterTask().length) {
                this.dVM.deselectAll();
              } else {
                this.dVM.selectAllVisible();
              }
            })

          Text(`已选择 ${this.dVM.getSelectedCount()} 项`)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Button("删除")
            .fontSize(16)
            .backgroundColor(Color.Transparent)
            .fontColor(Color.Red)
            .onClick(() => {
              this.dVM.editDelete()
            })
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 16 })
        .backgroundColor($r('sys.color.background_primary'))
        .shadow({ radius: 10, color: '#00000010', offsetY: -2 })
      }
    }
    .padding({ top: PixState.topRectHeight || 12 })
    .title($r('app.string.download_manage'))
    .hideToolBar(true)
    .menus(this.buttons())
    .onReady((ctx: NavDestinationContext) => {
      this.pageStack = ctx.pathStack
    })
    .onBackPressed(() => {
      if (this.dVM.isEditMode) {
        toastUtil.animateTo({ duration: 350 }, () => {
          this.dVM.toggleEditMode()
        })
        return true
      } else {
        return false
      }
    })
  }

  // 标题
  @Builder
  TitleBuilder(item: DownloadRecordInfo) {
    Column() {
      Text(item.title || $r('app.string.unknown_works'))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      // 副标题：作者名 · 下载时间
      Text() {
        Span(item.artistName || $r('app.string.unknown_artist'))
        Span(' · ')
        Span(this.formatTime(item.createTime))
      }
      .fontSize(13)
      .fontColor($r('sys.color.ohos_id_color_text_secondary'))
      .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
  }

  // 侧滑删除按钮
  @Builder
  DeleteSwipeButton(item: DownloadRecordInfo) {
    SymbolGlyph($r('sys.symbol.trash_fill'))
      .fontSize(20)
      .fontColor([Color.Red])
      .margin({ right: 12, left: 10 })
      .onClick(() => this.deleteTask(item))
  }

  @Builder
  menusBuilder() {
    Menu() {
      MenuItem({ content: $r('app.string.pause_all_tasks')})
        .onClick(() => {
          // 暂停所有下载任务
          this.dVM.pauseAllTask()
        })
      MenuItem({ content: $r('app.string.resume_all_tasks')})
        .onClick(() => {
          // 恢复所有下载任务
          this.dVM.resumeAllTask()
        })
      MenuItem({ content: $r('app.string.restart_all_failed_tasks')})
        .onClick(() => {
          // 重试所有失败任务
          this.dVM.restartAllTask()
        })
      MenuItem({ content: $r('app.string.clear_all_completed_tasks')})
        .onClick(() => {
          // 清空所有已完成任务
          this.dVM.clearAllCompletedTasks()
        })
    }
  }

  private buttons(): NavigationMenuItem[] {
    const btns: NavigationMenuItem[] = [
      {
        value: '',
        symbolIcon: new SymbolGlyphModifier($r('sys.symbol.square_and_pencil')),
        action: () => {
          toastUtil.animateTo({ duration: 350 }, () => {
            this.dVM.toggleEditMode()
          })
        }
      }
    ];
    btns.push({
      value: '',
      symbolIcon: new SymbolGlyphModifier($r('sys.symbol.dot_grid_2x2')),
      action: () => {
        // 编辑模式下禁用右上角“更多”菜单，防止逻辑交叉
        if (!this.dVM.isEditMode) {
          this.showMenu = !this.showMenu
        } else {
          return
        }
      }
    });

    return btns;
  }

  // 执行删除
  private async deleteTask(item: DownloadRecordInfo) {
    await this.dVM.removeTask(item);
  }

  // 打开插画详情
  private async openIllust(illustID: number | undefined) {
    if (!illustID) return;
    const params: DetailPageParams = {
      id: illustID,
      fromId: illustID.toString()
    }
    // 跳转详情页
    this.pageStack.pushPathByName('illust_detail', params, true);
  }

  // 简单的时间格式化
  private formatTime(timestamp: number): string {
    if (!timestamp) return '';
    const date = new Date(timestamp);
    return `${date.getMonth() + 1}/${date.getDate()} ${date.getHours()}:${String(date.getMinutes()).padStart(2, '0')}:${String(date.getSeconds()).padStart(2, '0')}`;
  }

}
