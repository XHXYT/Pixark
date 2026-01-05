import { ImageKnifeComponent, ImageKnifeOption, DownSamplingStrategy } from "@ohos/imageknifepro";

@ComponentV2
export struct PixivImage {

  @Param imageUrl: string = '';
  @Param imageObjectFit: ImageFit = ImageFit.Cover
  @Param imageWidth: Length | undefined = undefined
  @Param imageHeight: Length | undefined = undefined
  @Param imageBorderRadius:  Length | BorderRadiuses | LocalizedBorderRadiuses | undefined = undefined

  @Event progress:  (progress: number) => void

  build() {
    ImageKnifeComponent({
      imageKnifeOption: {
        loadSrc: this.imageUrl,
        // 加载中显示的占位图
        placeholderSrc: $rawfile('loading_placeholder.jpg'),
        // 加载失败显示的错误图
        errorSrc: $rawfile('loading_failed.jpg'),
        // 图片缩放模式：Cover 瀑布流最常用的模式，填充满不变形
        objectFit: this.imageObjectFit,
        // 开启降采样，减少内存占用
        downSampling: DownSamplingStrategy.FIT_CENTER_QUALITY,
        progressListener: (progress: number) => {
          // console.log('下载进度：' + progress + '%')
          this.progress(progress)
        },
        border: {
          radius: this.imageBorderRadius
        }
      }
    })
      .size({ width: this.imageWidth, height: this.imageHeight})
  }
}
