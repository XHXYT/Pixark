import { UgoiraFrame, ugoiraCache } from '../services/direct/UgoiraCache';
import { PixState, _PixState } from '../entryability/AppState';
import { PixivImageComponent } from './PixivImage';
import { createLogger } from '../common/utils/Logger';

const logger = createLogger('UgoiraPlayer');

/** 默认帧延迟兜底（ms），metadata 帧延迟非法时使用 */
const DEFAULT_FRAME_DELAY = 100;

/**
 * ugoira（动图）播放器
 *
 * 加载 ugoiraCache 解压解码出的帧序列，按每帧延迟定时轮播；
 * 加载中/失败时回退展示静态首帧（PixivImageComponent）。
 */
@ComponentV2
export struct UgoiraPlayer {
  @Param @Require illustId: number
  /** 兜底静态首帧地址（加载中/失败时展示） */
  @Param @Require placeholderUrl: string
  @Param imageObjectFit: ImageFit = ImageFit.Auto
  /** 帧显示尺寸（查看器全屏传 '100%'；缺省按帧原始尺寸自适应） */
  @Param imageWidth: Length | undefined = undefined
  @Param imageHeight: Length | undefined = undefined

  @Local state: 'loading' | 'playing' | 'error' = 'loading'
  @Local frames: UgoiraFrame[] = []
  @Local frameIndex: number = 0

  private timerId: number = -1
  private disposed: boolean = false

  aboutToAppear(): void {
    this.startLoad()
  }

  aboutToDisappear(): void {
    this.disposed = true
    this.stopTimer()
  }

  private startLoad(): void {
    ugoiraCache.load(this.illustId, this.targetPx())
      .then((frames: UgoiraFrame[]) => {
        if (this.disposed || frames.length === 0) {
          return
        }
        this.frames = frames
        this.frameIndex = 0
        this.state = 'playing'
        this.scheduleNext()
      })
      .catch((e: Error) => {
        if (this.disposed) {
          return
        }
        this.state = 'error'
        logger.warn(`load ugoira ${this.illustId} failed: ${e}`)
      })
  }

  /** 展示当前帧，并在其延迟后切到下一帧（循环播放） */
  private scheduleNext(): void {
    const frame = this.frames[this.frameIndex]
    const delay = frame !== undefined && frame.delay > 0 ? frame.delay : DEFAULT_FRAME_DELAY
    this.timerId = setTimeout(() => {
      if (this.disposed || this.state !== 'playing' || this.frames.length === 0) {
        return
      }
      this.frameIndex = (this.frameIndex + 1) % this.frames.length
      this.scheduleNext()
    }, delay)
  }

  private stopTimer(): void {
    if (this.timerId !== -1) {
      clearTimeout(this.timerId)
      this.timerId = -1
    }
  }

  /** 解码目标宽度（px）：窗口宽度换算，限制在 [320, 2160] */
  private targetPx(): number {
    const density = PixState.windowWidth > 0 ? _PixState.windowWidth_px / PixState.windowWidth : 2
    const px = Math.ceil(PixState.windowWidth * density)
    return Math.min(Math.max(px, 320), 2160)
  }

  build() {
    Stack() {
      if (this.state === 'playing' && this.frames.length > 0) {
        ForEach(this.frames, (frame: UgoiraFrame, index: number) => {
          Image(frame.pixelMap)
            .objectFit(this.imageObjectFit)
            .interpolation(ImageInterpolation.High)
            .size({ width: this.imageWidth, height: this.imageHeight })
            .visibility(index === this.frameIndex ? Visibility.Visible : Visibility.Hidden)
        }, (frame: UgoiraFrame, index: number) => `${this.illustId}_${index}`)
      } else {
        // 加载中/失败：静态首帧兜底
        PixivImageComponent({
          imageUrl: this.placeholderUrl,
          imageObjectFit: this.imageObjectFit,
          imageWidth: this.imageWidth,
          imageHeight: this.imageHeight
        })
      }
    }
  }
}
