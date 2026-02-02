import { ImageKnifeComponent, ImageKnifeOption, DownSamplingStrategy } from "@ohos/imageknifepro";
import { ConfigurationConstant } from "@kit.AbilityKit";
import { PixState } from "../entryability/AppState";

@ComponentV2
export struct PixivImageComponent {

  @Param @Require imageUrl: string;
  @Param needMask: boolean = false
  @Param imageID: string | undefined = undefined
  @Param imageObjectFit: ImageFit = ImageFit.Cover
  @Param imageWidth: Length | undefined = undefined
  @Param imageHeight: Length | undefined = undefined
  @Param imageAspectRatio: number | undefined = undefined
  @Param imageBorder:  BorderOptions | undefined = undefined

  @Event progress:  (progress: number) => void
  @Event onImageLongPress: (url: string) => void
  @Event onImageClick: (url: string) => void

  build() {
    if (this.needMask) {
      Stack() {
        ImageKnifeComponent({
          imageKnifeOption: {
            loadSrc: this.imageUrl,
            // 加载中显示的占位图
            placeholderSrc: $rawfile('loading_placeholder.jpg'),
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
            border: this.imageBorder
          }
        })
          .id(this.imageID || this.imageUrl)
          .aspectRatio(this.imageAspectRatio)
          .size({ width: this.imageWidth, height: this.imageHeight})
        // 遮罩
        Row()
          .width('100%')
          .borderRadius(this.imageBorder?.radius)
          .aspectRatio(this.imageAspectRatio)
          .backgroundColor(PixState.currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#80000000' : '#40000000')
          .shadow({ radius: typeof this.imageBorder?.radius == 'number' ? this.imageBorder.radius: undefined, color: PixState.currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#000000' : '#aaaaaa', offsetX: 6, offsetY: 6 })
      }
    } else {
      ImageKnifeComponent({
        imageKnifeOption: {
          loadSrc: this.imageUrl,
          // 加载中显示的占位图
          placeholderSrc: $rawfile('loading_placeholder.jpg'),
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
          border: this.imageBorder
        }
      })
        .id(this.imageID || this.imageUrl)
        .aspectRatio(this.imageAspectRatio)
        .size({ width: this.imageWidth, height: this.imageHeight})
    }
  }
}
