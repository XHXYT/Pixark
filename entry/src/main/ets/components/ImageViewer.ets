import { PixState } from "../entryability/AppState";
import { PixivImageComponent } from "./PixivImage";
import { PixivImage } from '../services/PixivTypes';
import { appSettings } from '../common/entity/SettingsModel';
import { ImageUtils } from '../common/utils/ImageUtils';

@ComponentV2
export struct PixivImageViewer {
  // 图片URL列表 (保持接收完整的 PixivImage 对象)
  @Param imageUrls: PixivImage[] = [];
  // 初始索引
  @Param startIndex: number = 0;
  // 当前索引 (用于显示页码)
  @Local currentIndex: number = 0;

  private swiperController: SwiperController = new SwiperController();

  // 事件：关闭查看器
  @Event onClose: () => void = () => {};
  // 事件：下载当前图片
  @Event onDownload: (index: number) => void = () => {};
  // 事件：分享当前图片
  @Event onShare: (url: string, index: number) => void = () => {};

  aboutToAppear(): void {
    this.currentIndex = this.startIndex;
  }


  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // Swiper 图片浏览区
      Swiper(this.swiperController) {
        ForEach(this.imageUrls, (image: PixivImage) => {
          PixivImageComponent({
            imageUrl: ImageUtils.getImageUrlByQuality(image, appSettings.image_view_quality),
            imageObjectFit: ImageFit.Contain,
            imageWidth: '100%',
            imageHeight: '100%',
            needMask: false
          })
        })
      }
      .index(this.startIndex)
      .loop(false)
      .indicator(false)
      .cachedCount(1)
      .onChange((index) => {
        this.currentIndex = index;
      })
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black)
      .onClick(() => {
        this.onClose();
      })

      // 底部工具栏
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
      .height(60)
      .padding({ left: 24, right: 24 })
      .backgroundColor(Color.Transparent)
      .linearGradient({ angle: 180, colors: [['#80000000', 0.0]] })
      .margin({ bottom: PixState.bottomRectHeight })
    }
    .width('100%')
    .height('100%')
  }
}
