import { ImageKnifeComponent, DownSamplingStrategy } from "@ohos/imageknifepro";
import { appSettings, UISettings } from "../common/entity/SettingsModel";
import { ConfigurationConstant } from "@kit.AbilityKit";
import { image } from "@kit.ImageKit";
import { PixState, _PixState } from "../entryability/AppState";
import { imageCache, CachedImage } from "../services/direct/ImageCache";
import { createLogger } from "../common/utils/Logger";
import { NetworkMode, parseNetworkMode, DEFAULT_IMAGE_HOST } from "../services/direct/NetworkModeState";

const logger = createLogger('PixivImage')


@ComponentV2
export struct PixivImageComponent {

  @Param @Require imageUrl: string;
  @Param needMask: boolean = false
  @Param needClick: boolean = false
  @Param showAISign: boolean = false
  @Param showHTips: boolean = false

  @Param imageID: string | undefined = undefined
  @Param imageObjectFit: ImageFit = ImageFit.Cover
  @Param imageWidth: Length | undefined = undefined
  @Param imageHeight: Length | undefined = undefined
  @Param imageAspectRatio: number | undefined = undefined
  @Param imageBorder:  BorderOptions | undefined = undefined
  @Param placeholderSrc: ResourceStr = $rawfile('loading_placeholder.jpg')

  @Event progress:  (progress: number) => void
  @Event onImageLongPress: (url: string) => void
  @Event onImageClick?: (url: string) => void
  @Event onLoadListener: (width: number, height: number) => void

  /** pximg 直连图片的加载状态（idle 表示非直连 URL，走 ImageKnife） */
  @Local directState: 'idle' | 'loading' | 'success' | 'error' = 'idle'
  @Local directMap: image.PixelMap | undefined = undefined

  aboutToAppear(): void {
    this.refreshDirectImage()
  }

  @Monitor('imageUrl', 'appSettings.picture_source', 'appSettings.network_mode_api')
  onImageUrlChange(): void {
    this.refreshDirectImage()
  }

  /**
   * 实际请求的 URL：配置了自定义图床源时把 i.pximg.net 改写为该 host
   * （上游 PixEz 同款：replaceFirst(ImageHost, pictureSource)）
   */
  private effectiveUrl(): string {
    const source = appSettings.picture_source;
    if (!source || source === DEFAULT_IMAGE_HOST) {
      return this.imageUrl;
    }
    return this.imageUrl.replace(DEFAULT_IMAGE_HOST, source);
  }

  /**
   * pximg 域名被 SNI 阻断，系统网络栈（ImageKnife 等）无法直接加载，
   * 统一走 fetchBytes 直连链路 + ImageCache 缓存后本地渲染；
   * API 组为标准模式或已改写为镜像图床时回退 ImageKnife（系统网络）
   */
  private isDirectUrl(): boolean {
    if (parseNetworkMode(appSettings.network_mode_api) === NetworkMode.STANDARD) {
      return false;
    }
    const url = this.effectiveUrl();
    const idx = url.indexOf('://')
    const rest = idx >= 0 ? url.substring(idx + 3) : url
    const hostEnd = rest.indexOf('/')
    const host = hostEnd >= 0 ? rest.substring(0, hostEnd) : rest
    return host.endsWith('.pximg.net')
  }

  private refreshDirectImage(): void {
    if (!this.isDirectUrl()) {
      this.directState = 'idle'
      this.directMap = undefined
      return
    }
    const url = this.effectiveUrl()
    this.directState = 'loading'
    this.directMap = undefined
    imageCache.load(url, this.decodeTargetPx())
      .then((result: CachedImage) => {
        // URL 已切换时丢弃过期结果
        if (this.effectiveUrl() !== url) {
          return
        }
        this.directMap = result.pixelMap
        this.directState = 'success'
        this.progress(100)
        this.onLoadListener(result.width, result.height)
      })
      .catch((e: Error) => {
        if (this.effectiveUrl() !== url) {
          return
        }
        this.directState = 'error'
        logger.warn(`load image failed: ${url}, ${e}`)
      })
  }

  /**
   * 估算解码目标宽度（px）：数字宽度按 vp 换算，百分比按窗口宽度比例，缺省 720px
   * 解码时不会放大（超过原图尺寸按原图解码）
   */
  private decodeTargetPx(): number {
    const density = PixState.windowWidth > 0 ? _PixState.windowWidth_px / PixState.windowWidth : 2
    let targetVp = 0
    if (typeof this.imageWidth === 'number') {
      targetVp = this.imageWidth
    } else if (typeof this.imageWidth === 'string') {
      const percentReg = new RegExp('^(\\d+(?:\\.\\d+)?)%$')
      const match = percentReg.exec(this.imageWidth)
      if (match !== null) {
        targetVp = PixState.windowWidth * parseFloat(match[1]) / 100
      }
    }
    if (targetVp <= 0) {
      targetVp = 720 / density
    }
    const px = Math.ceil(targetVp * density)
    return Math.min(Math.max(px, 120), 2160)
  }

  /** 从 BorderOptions 中提取可用于 borderRadius 的标量圆角 */
  private radiusValue(): Length | undefined {
    const radius = this.imageBorder?.radius
    if (typeof radius === 'number' || typeof radius === 'string') {
      return radius
    }
    return undefined
  }

  build() {
    Stack() {
      if (this.isDirectUrl()) {
        if (this.directState === 'success' && this.directMap !== undefined) {
          Image(this.directMap)
            .objectFit(this.imageObjectFit)
            .interpolation(ImageInterpolation.High)
            .aspectRatio(this.imageAspectRatio)
            .size({ width: this.imageWidth, height: this.imageHeight })
            .borderRadius(this.radiusValue())
            .id(this.imageID || this.imageUrl)
            .foregroundBlurStyle(this.showHTips ? BlurStyle.Thick : BlurStyle.NONE,
              { colorMode: ThemeColorMode.SYSTEM, adaptiveColor: AdaptiveColor.DEFAULT, scale: 0.3 })
        } else {
          Image(this.directState === 'error' ? $rawfile('loading_failed.jpg') : this.placeholderSrc)
            .objectFit(ImageFit.Cover)
            .aspectRatio(this.imageAspectRatio)
            .size({ width: this.imageWidth || '100%', height: this.imageHeight })
            .borderRadius(this.radiusValue())
            .id(this.imageID || this.imageUrl)
        }
      } else {
        ImageKnifeComponent({
          imageKnifeOption: {
            loadSrc: this.effectiveUrl(),
            // 加载中显示的占位图
            placeholderSrc: this.placeholderSrc,
            // 加载失败显示的错误图
            errorSrc: $rawfile('loading_failed.jpg'),
            // 图片缩放模式
            objectFit: this.imageObjectFit,
            // 开启降采样，减少内存占用
            downSampling: DownSamplingStrategy.FIT_CENTER_QUALITY,
            progressListener: (progress: number) => {
              // console.log('下载进度：' + progress + '%')
              this.progress(progress)
            },
            onLoadListener: {
              onLoadSuccess: (info) => {
                this.onLoadListener(info.componentWidth, info.componentHeight)
              }
            },
            border: this.imageBorder
          }
        })
          .id(this.imageID || this.imageUrl)
          .aspectRatio(this.imageAspectRatio)
          .size({ width: this.imageWidth, height: this.imageHeight })
          .foregroundBlurStyle(this.showHTips ? BlurStyle.Thick : BlurStyle.NONE,
            { colorMode: ThemeColorMode.SYSTEM, adaptiveColor: AdaptiveColor.DEFAULT, scale: 0.3 })
      }
      if (this.needMask) {
        // 遮罩
        Row()
          .borderRadius(this.imageBorder?.radius)
          .aspectRatio(this.imageAspectRatio)
          .size({ width: this.imageWidth || '100%', height: this.imageHeight })
          .backgroundColor(UISettings.color_mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#80000000' : '#40000000')
          .shadow({ radius: typeof this.imageBorder?.radius == 'number' ? this.imageBorder.radius: undefined,
            color: UISettings.color_mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#000000' : '#aaaaaa',
            offsetX: 6, offsetY: 6 })
      }
      if (this.showAISign && appSettings.show_ai_sign) {
        Text('AI')
          .padding(2)
          .borderRadius(2)
          .fontColor(Color.White)
          .backgroundColor('#40000000')
          .offset({ x: -6, y: 5 })
      }
    }
    .hitTestBehavior(this.needClick ? HitTestMode.Default : HitTestMode.None)
    .alignContent(Alignment.TopEnd)
    .onClick(() => {
      if (this.onImageClick)
      this.onImageClick(this.imageUrl)
    })
  }

}
