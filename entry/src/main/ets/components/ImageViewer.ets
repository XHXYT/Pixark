import { PixState } from "../entryability/AppState";
import { PixivImageComponent } from "./PixivImage";
import { PixivImage } from '../services/PixivTypes';


@ComponentV2
export struct PixivImageViewer {
  // 图片URL列表
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
            imageUrl: image.large,
            imageObjectFit: ImageFit.Contain, // 查看器通常使用 Contain 模式
            imageWidth: '100%',
            imageHeight: '100%',
            needMask: false
          })
        })
      }
      .index(this.startIndex)
      .loop(false)
      .indicator(false) // 不使用默认指示器，我们在自定义工具栏显示
      .cachedCount(1)   // 缓存前后各1页，提升体验
      .onChange((index) => {
        this.currentIndex = index;
      })
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Black) // 背景黑色，沉浸感更强
      .onClick(() => {
        // 点击图片区域关闭查看器 (常见交互)
        this.onClose();
      })

      // 底部工具栏 (透明背景)
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
        // 右侧：操作按钮 (返回、下载、分享)
        Row({ space: 24 }) {
          // 返回按钮
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(24)
            .fontColor([Color.White])
            .onClick(() => this.onClose())
          // 下载按钮
          SymbolGlyph($r('sys.symbol.circle_and_arrow_down'))
            .fontSize(22)
            .fontColor([Color.White])
            .onClick(() => {
              this.onDownload(this.currentIndex);
            })
          // 分享按钮
          SymbolGlyph($r('sys.symbol.share'))
            .fontSize(22)
            .fontColor([Color.White])
            .onClick(() => {
              const image = this.imageUrls[this.currentIndex]
              const currentUrl = image?.original || image.large;
              this.onShare(currentUrl, this.currentIndex);
            })
        }
      }
      .width('100%')
      .height(60)
      .padding({ left: 24, right: 24 })
      .backgroundColor(Color.Transparent) // 背景透明
      // 添加轻微的背景模糊，防止图片太白导致图标看不清
      .linearGradient({
        angle: 180,
        colors: [['#80000000', 0.0]]
      })
      .margin({ bottom: PixState.bottomRectHeight }) // 距离底部一点距离
    }
    .width('100%')
    .height('100%')
  }
}
