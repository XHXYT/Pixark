import { PixState } from "../entryability/AppState";
import { PixivImageComponent } from "./PixivImage";
import { PixivImage } from '../services/PixivTypes';
import { appSettings } from '../common/entity/SettingsModel';
import { ImageUtils } from '../common/utils/ImageUtils';

const VIEWER_MAX_ZOOM = 4;
const VIEWER_MIN_ZOOM = 0.5;
const VIEWER_DOUBLE_TAP_ZOOM = 2.5;
const VIEWER_TOOLBAR_HEIGHT = 60;

// 单页可缩放图片：双指捏合缩放、双指旋转、双击放大/还原、放大后可拖拽、单击关闭
@ComponentV2
struct ViewerImage {
  @Param image: PixivImage | undefined = undefined;
  @Param isActive: boolean = false;
  @Event onTap: () => void = () => {};

  @Local zoom: number = 1;
  @Local offsetX: number = 0;
  @Local offsetY: number = 0;
  @Local rotateAngle: number = 0;

  private pinchBaseZoom: number = 1;
  private rotateBaseAngle: number = 0;
  private panStartX: number = 0;
  private panStartY: number = 0;
  // 双指手势进行中/刚结束的标记：Parallel 组内 tap 识别器不会因捏合自动失败，
  // 捏合中某指位移小于阈值再抬起会被判定为单击（且被双击仲裁延迟回调），必须显式拦截
  private isPinchActive: boolean = false;
  private isRotating: boolean = false;
  private lastMultiEnd: number = 0;

  @Monitor('isActive')
  onActiveChange(): void {
    if (!this.isActive) {
      this.zoom = 1;
      this.offsetX = 0;
      this.offsetY = 0;
      this.rotateAngle = 0;
    }
  }

  private multiTouchGuard(): boolean {
    return this.isPinchActive || this.isRotating || (Date.now() - this.lastMultiEnd < 500);
  }

  private clampOffset(): void {
    const maxX = Math.max(0, (this.zoom - 1) * PixState.windowWidth / 2);
    const maxY = Math.max(0, (this.zoom - 1) * PixState.windowHeight / 2);
    this.offsetX = Math.min(maxX, Math.max(-maxX, this.offsetX));
    this.offsetY = Math.min(maxY, Math.max(-maxY, this.offsetY));
  }

  private applyZoom(zoom: number): void {
    this.zoom = Math.min(VIEWER_MAX_ZOOM, Math.max(VIEWER_MIN_ZOOM, zoom));
    this.clampOffset();
  }

  private toggleZoom(): void {
    this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      if (this.zoom > 1) {
        this.zoom = 1;
        this.offsetX = 0;
        this.offsetY = 0;
      } else {
        this.zoom = VIEWER_DOUBLE_TAP_ZOOM;
      }
    });
  }

  // 视图是否偏离默认状态（缩放/旋转/位移任一非默认）
  @Computed
  get isTransformed(): boolean {
    return this.zoom !== 1 || this.rotateAngle !== 0 || this.offsetX !== 0 || this.offsetY !== 0;
  }

  private resetView(): void {
    this.getUIContext().animateTo({ duration: 220, curve: Curve.EaseOut }, () => {
      this.zoom = 1;
      this.offsetX = 0;
      this.offsetY = 0;
      this.rotateAngle = 0;
    });
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.image !== undefined) {
        PixivImageComponent({
          imageUrl: ImageUtils.getImageUrlByQuality(this.image, appSettings.image_view_quality),
          imageObjectFit: ImageFit.Contain,
          imageWidth: '100%',
          imageHeight: '100%',
          needMask: false
        })
          // 必须显式撑满：组件根节点是 wrap-content，否则内部 100% 高度解析为 0
          .width('100%')
          .height('100%')
          // 变换只施加在图片上：拖拽层与回正按钮不跟着缩放旋转
          .scale({ x: this.zoom, y: this.zoom })
          .translate({ x: this.offsetX, y: this.offsetY })
          .rotate({ angle: this.rotateAngle, centerX: '50%', centerY: '50%' })
      }

      // 放大后才挂载拖拽层，避免常驻 pan 手势抢占翻页滑动；
      // 缩放/旋转必须一并挂在本层：本层是根 Stack 的子节点，仲裁中子组件优先，
      // 若只挂 pan 会反过来抢占根上的 Pinch/Rotation，导致放大后无法缩小
      if (this.zoom > 1) {
        Column()
          .width('100%')
          .height('100%')
          .gesture(
            GestureGroup(GestureMode.Parallel,
              PinchGesture({ fingers: 2 })
                .onActionStart(() => {
                  this.pinchBaseZoom = this.zoom;
                  this.isPinchActive = true;
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.applyZoom(this.pinchBaseZoom * event.scale);
                })
                .onActionEnd(() => {
                  this.isPinchActive = false;
                  this.lastMultiEnd = Date.now();
                  // 仅对接近 1 的值吸附回正；允许持久缩到比原始适配尺寸更小（下限 0.5）
                  if (this.zoom > 0.95 && this.zoom < 1.05) {
                    this.zoom = 1;
                    this.offsetX = 0;
                    this.offsetY = 0;
                    if (Math.abs(this.rotateAngle) < 10) {
                      this.rotateAngle = 0;
                    }
                  }
                })
                .onActionCancel(() => {
                  this.isPinchActive = false;
                  this.lastMultiEnd = Date.now();
                }),
              RotationGesture({ fingers: 2 })
                .onActionStart(() => {
                  this.rotateBaseAngle = this.rotateAngle;
                  this.isRotating = true;
                })
                .onActionUpdate((event: GestureEvent) => {
                  this.rotateAngle = this.rotateBaseAngle + event.angle;
                })
                .onActionEnd(() => {
                  this.isRotating = false;
                  this.lastMultiEnd = Date.now();
                  if (Math.abs(this.rotateAngle) < 5) {
                    this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
                      this.rotateAngle = 0;
                    });
                  }
                })
                .onActionCancel(() => {
                  this.isRotating = false;
                  this.lastMultiEnd = Date.now();
                }),
              PanGesture({ fingers: 1, direction: PanDirection.All })
                .onActionStart(() => {
                  if (this.isPinchActive || this.isRotating) {
                    return;
                  }
                  this.panStartX = this.offsetX;
                  this.panStartY = this.offsetY;
                })
                .onActionUpdate((event: GestureEvent) => {
                  if (this.isPinchActive || this.isRotating) {
                    return;
                  }
                  this.offsetX = this.panStartX + event.offsetX;
                  this.offsetY = this.panStartY + event.offsetY;
                  this.clampOffset();
                })
            )
          )
      }

      // 视图偏离默认（缩放/旋转/位移任一非默认）时右下角显示回正按钮，避开底部工具栏
      if (this.isTransformed) {
        Column() {
          SymbolGlyph($r('sys.symbol.arrow_2_circlepath'))
            .fontSize(22)
            .fontColor([Color.White])
        }
        .width(42)
        .height(42)
        .borderRadius(21)
        .backgroundColor('#66000000')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .margin({ right: 16, bottom: VIEWER_TOOLBAR_HEIGHT + PixState.bottomRectHeight + 12 })
        .transition(TransitionEffect.OPACITY.animation({ duration: 150 }))
        .onClick(() => {
          this.resetView();
        })
      }
    }
    .width('100%')
    .height('100%')
    .gesture(
      GestureGroup(GestureMode.Parallel,
        PinchGesture({ fingers: 2 })
          .onActionStart(() => {
            this.pinchBaseZoom = this.zoom;
            this.isPinchActive = true;
          })
          .onActionUpdate((event: GestureEvent) => {
            this.applyZoom(this.pinchBaseZoom * event.scale);
          })
          .onActionEnd(() => {
            this.isPinchActive = false;
            this.lastMultiEnd = Date.now();
            // 仅对接近 1 的值吸附回正；允许持久缩到比原始适配尺寸更小（下限 0.5）
            if (this.zoom > 0.95 && this.zoom < 1.05) {
              this.zoom = 1;
              this.offsetX = 0;
              this.offsetY = 0;
              if (Math.abs(this.rotateAngle) < 10) {
                this.rotateAngle = 0;
              }
            }
          })
          .onActionCancel(() => {
            this.isPinchActive = false;
            this.lastMultiEnd = Date.now();
          }),
        RotationGesture({ fingers: 2 })
          .onActionStart(() => {
            this.rotateBaseAngle = this.rotateAngle;
            this.isRotating = true;
          })
          .onActionUpdate((event: GestureEvent) => {
            this.rotateAngle = this.rotateBaseAngle + event.angle;
          })
          .onActionEnd(() => {
            this.isRotating = false;
            this.lastMultiEnd = Date.now();
            if (Math.abs(this.rotateAngle) < 5) {
              this.getUIContext().animateTo({ duration: 150, curve: Curve.EaseOut }, () => {
                this.rotateAngle = 0;
              });
            }
          })
          .onActionCancel(() => {
            this.isRotating = false;
            this.lastMultiEnd = Date.now();
          }),
        GestureGroup(GestureMode.Exclusive,
          TapGesture({ count: 2 })
            .onAction(() => {
              if (this.multiTouchGuard()) {
                return;
              }
              this.toggleZoom();
            }),
          TapGesture({ count: 1 })
            .onAction(() => {
              if (this.multiTouchGuard()) {
                return;
              }
              this.onTap();
            })
        )
      )
    )
  }
}

@ComponentV2
export struct PixivImageViewer {
  // 图片URL列表 (保持接收完整的 PixivImage 对象)
  @Param imageUrls: PixivImage[] = [];
  // 初始索引
  @Param startIndex: number = 0;
  // 当前索引 (用于显示页码)
  @Local currentIndex: number = 0;
  // 翻页拖拽中的横向偏移
  @Local dragX: number = 0;
  // 翻页动画进行中（屏蔽拖拽输入）
  private isSettling: boolean = false;

  // 事件：关闭查看器
  @Event onClose: () => void = () => {};
  // 事件：下载当前图片
  @Event onDownload: (index: number) => void = () => {};
  // 事件：分享当前图片
  @Event onShare: (url: string, index: number) => void = () => {};

  aboutToAppear(): void {
    this.currentIndex = this.startIndex;
  }

  private clampDrag(x: number): number {
    // 向左滑（负）露出下一页，向右滑（正）露出上一页
    const min = this.currentIndex < this.imageUrls.length - 1 ? -PixState.windowWidth : 0;
    const max = this.currentIndex > 0 ? PixState.windowWidth : 0;
    return Math.min(max, Math.max(min, x));
  }

  private settlePage(): void {
    const threshold = PixState.windowWidth / 4;
    let target = this.currentIndex;
    if (this.dragX <= -threshold && this.currentIndex < this.imageUrls.length - 1) {
      target = this.currentIndex + 1;
    } else if (this.dragX >= threshold && this.currentIndex > 0) {
      target = this.currentIndex - 1;
    }
    if (target === this.currentIndex) {
      this.getUIContext().animateTo({ duration: 220, curve: Curve.Friction }, () => {
        this.dragX = 0;
      });
      return;
    }
    // 先把 dragX 动画到目标偏移，动画结束后再原子换索引（渲染窗口切换发生在屏外，避免闪黑）
    const delta = (target - this.currentIndex) * PixState.windowWidth;
    this.isSettling = true;
    this.getUIContext().animateTo({
      duration: 220,
      curve: Curve.Friction,
      onFinish: () => {
        this.currentIndex = target;
        this.dragX = 0;
        this.isSettling = false;
      }
    }, () => {
      this.dragX = -delta;
    });
  }


  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 分页区：Stack + 每页 translate 定位
      // （超宽 Row 会被父容器钳制并触发 flex 收缩把子页挤压变形，transform 不受布局约束）
      Stack() {
        ForEach(this.imageUrls, (image: PixivImage, index: number) => {
          if (Math.abs(index - this.currentIndex) <= 1) {
            ViewerImage({
              image: image,
              isActive: index === this.currentIndex,
              onTap: () => {
                this.onClose();
              }
            })
              .width('100%')
              .height('100%')
              .translate({ x: (index - this.currentIndex) * PixState.windowWidth + this.dragX })
          } else {
            // 窗口外的页不渲染内容，仅保留占位避免常驻加载所有大图
            Stack()
              .width(0)
              .height(0)
          }
        }, (image: PixivImage) => image.medium)
      }
      .width('100%')
      .height('100%')
      .gesture(
        PanGesture({ fingers: 1, direction: PanDirection.Horizontal })
          .onActionStart(() => {
            if (this.isSettling) {
              return;
            }
            this.dragX = 0;
          })
          .onActionUpdate((event: GestureEvent) => {
            if (this.isSettling) {
              return;
            }
            this.dragX = this.clampDrag(event.offsetX);
          })
          .onActionEnd(() => {
            if (this.isSettling) {
              return;
            }
            this.settlePage();
          })
      )

      // 底部工具栏：底部安全区避让折进内边距，背景延伸覆盖避让区不再悬空
      Row() {
        // 左侧：图片组进度序号
        Row({ space: 6 }) {
          SymbolGlyph($r('sys.symbol.shutter_photo'))
            .fontSize(18)
            .fontColor([Color.White])
          Text(`${this.currentIndex + 1} / ${this.imageUrls.length}`)
            .fontSize(15)
            .fontColor(Color.White)
            .fontWeight(FontWeight.Medium)
        }

        Blank()

        // 右侧：操作按钮
        Row({ space: 24 }) {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24)
            .fontColor([Color.White])
            .onClick(() => this.onClose())

          SymbolGlyph($r('sys.symbol.circle_and_arrow_down'))
            .fontSize(22)
            .fontColor([Color.White])
            .onClick(() => {
              this.onDownload(this.currentIndex);
            })

          SymbolGlyph($r('sys.symbol.share'))
            .fontSize(22)
            .fontColor([Color.White])
            .onClick(() => {
              const image = this.imageUrls[this.currentIndex]
              // 分享的链接也跟随当前展示的质量设置
              const currentUrl = ImageUtils.getImageUrlByQuality(image, appSettings.image_view_quality);
              this.onShare(currentUrl, this.currentIndex);
            })
        }
      }
      .width('100%')
      .height(VIEWER_TOOLBAR_HEIGHT + PixState.bottomRectHeight)
      .padding({ left: 24, right: 24, bottom: PixState.bottomRectHeight })
      .linearGradient({ angle: 180, colors: [['#80000000', 0.0]] })
    }
    .width('100%')
    .height('100%')
  }
}
