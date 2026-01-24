
import { ConfigurationConstant } from "@kit.AbilityKit";
import { BaseDataSource } from "../viewmodel/BaseDataSource";
import { PixivImageComponent } from "./PixivImage";
import { SpotlightArticle } from "../services/PixivTypes";
import { HomeBannerBannerMargin, HomeBannerDisplayCount } from "../utils/breakpoint/BreakPoint";
import { PixState } from "../entryability/AppState";

// 主页轮播图
@ComponentV2
export struct BannerView {

  @Param swiperMargin: Length = 12
  @Param @Require bannerList: SpotlightArticle[]

  private bannerDataSource: BannerDataSource = new BannerDataSource([])

  aboutToAppear(): void {
    this.bannerDataSource.pushData(this.bannerList)
  }

  build() {
    Swiper() {
      LazyForEach(this.bannerDataSource, (item: SpotlightArticle, index: number) => {
        this.BannerItem(item)
      }, (item: SpotlightArticle) => item.id + item.title)
    }.loop(true)
    .width('100%')
    .autoPlay(true)
    .interval(6000)
    .indicator(false)
    .prevMargin(HomeBannerBannerMargin(PixState.widthBp))
    .nextMargin(HomeBannerBannerMargin(PixState.widthBp))
    .displayCount(HomeBannerDisplayCount(PixState.widthBp))
  }

  // 轮播图项
  @Builder BannerItem(article: SpotlightArticle) {
    Stack({ alignContent: Alignment.BottomStart }) {
      // 封面
      PixivImageComponent({
        imageUrl: article.thumbnail,
        imageBorderRadius: 16
      })
        .layoutWeight(1)
        .aspectRatio(1.75)
      // 遮罩
      Row()
        .zIndex(10)
        .width('100%')
        .borderRadius(16)
        .aspectRatio(1.75)
        .backgroundColor(PixState.currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#80000000' : '#40000000')
        .shadow({ radius: 16, color: PixState.currentColorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#000000' : '#aaaaaa', offsetX: 6, offsetY: 6 })
      // 标题
      Text(article.title)
        .fontColor(Color.White)
        .fontSize(16)
        .padding(12)
        .maxLines(1)
        .zIndex(11)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .alignSelf(ItemAlign.Start)
    }
    .clip(true)
    .padding({ top: 16, bottom: 16, left: 9, right: 9 })
    .onClick(() => {
      console.log(' 点击图片 ')

    })
    .margin(({ left: this.swiperMargin, right: this.swiperMargin }))
  }
}

class BannerDataSource extends BaseDataSource<SpotlightArticle> {
  private dataArray: SpotlightArticle[] = []

  public totalCount(): number {
    return this.dataArray.length
  }

  public getData(index: number): SpotlightArticle {
    return this.dataArray[index]
  }

  public addData(index: number, data: SpotlightArticle): void {
    this.dataArray.splice(index, 0, data)
    this.notifyDataAdd(index)
  }

  public pushData(data: SpotlightArticle[]): void {
    this.dataArray = data
    this.notifyDataAdd(this.dataArray.length - 1)
  }

  // 删除全部数据
  public clear(): void {
    this.empty()
    this.refresh()
  }

  public empty(): void {
    this.dataArray = []
  }
  public refresh(): void {
    this.notifyDataReload()
  }
}