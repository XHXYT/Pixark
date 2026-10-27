import { NaviContainer } from "../components/NaviContainer";
import { PixState } from "../entryability/AppState";
import { PixivImageComponent } from "../components/PixivImage";
import { pixiv } from "../services/PixivService";
import { PixivIllust } from "../services/PixivTypes";
import { createLogger } from "../common/utils/Logger";
import { toastUtil } from "../common/utils/ToastUtils";
import { BusinessError } from "@kit.BasicServicesKit";
import { DetailPageParams } from "../common/entity/DetailEntity";
import { pickImageUri, compressToJpegBuffer, uploadToSauceNao, parseSauceNaoResults, SauceNaoMatch } from "../services/SauceNaoService";

const logger = createLogger('SauceNaoPage')

/** 以图搜图（SauceNAO 原生结果页） */
@Builder
export function SauceNaoPageBuilder(name: string, param: Object) {
  SauceNaoPage()
}

@ComponentV2
struct SauceNaoPage {

  // 0 待选图 1 上传中 2 完成 3 失败
  @Local phase: number = 0;
  @Local matches: SauceNaoMatch[] = [];
  @Local errorMessage: string = '';
  @Local pickedUri: string = '';

  private searching: boolean = false;

  build() {
    NaviContainer({
      title: 'SauceNAO',
      content: () => {
        this.Content()
      },
      onReady: (ctx: NavDestinationContext) => {
      },
      onBackPressed: () => {
        return false
      }
    })
  }

  private async pickAndSearch(): Promise<void> {
    if (this.searching) {
      return;
    }
    try {
      const uri = await pickImageUri();
      if (!uri) {
        return;
      }
      this.pickedUri = uri;
      this.phase = 1;
      this.searching = true;
      const jpeg = await compressToJpegBuffer(uri);
      const html = await uploadToSauceNao(jpeg);
      this.matches = parseSauceNaoResults(html);
      this.phase = 2;
      logger.warn(`saucenao done: ${this.matches.length} matches`);
    } catch (e) {
      const err = e as BusinessError;
      this.errorMessage = err.message || JSON.stringify(e);
      this.phase = 3;
      logger.error(`saucenao failed: ${this.errorMessage}`);
    } finally {
      this.searching = false;
    }
  }

  @Builder
  Content() {
    if (this.phase === 1) {
      Column({ space: 16 }) {
        Image(this.pickedUri)
          .width(120)
          .height(120)
          .borderRadius(12)
          .objectFit(ImageFit.Cover)
        LoadingProgress()
          .width(32)
          .height(32)
          .color($r('sys.color.font_secondary'))
        Text($r('app.string.uploading_search'))
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.phase === 3) {
      Column({ space: 16 }) {
        Text($r('app.string.search_failed'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(this.errorMessage)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .constraintSize({ maxWidth: '80%' })
        Button($r('app.string.retry'))
          .onClick(() => {
            this.pickAndSearch()
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.phase === 2 && this.matches.length === 0) {
      Column({ space: 16 }) {
        Text($r('app.string.no_match_found'))
          .fontSize(15)
          .fontColor($r('sys.color.font_secondary'))
        Button($r('app.string.repick_image'))
          .onClick(() => {
            this.pickAndSearch()
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.phase === 2) {
      Column() {
        Row() {
          Text($r('app.string.match_result_count', this.matches.length))
            .fontSize(12)
            .fontColor($r('sys.color.font_tertiary'))
          Blank()
          Text($r('app.string.repick_image'))
            .fontSize(13)
            .fontColor(PixState.currentThemeColor)
            .onClick(() => {
              this.pickAndSearch()
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })

        List({ space: 10 }) {
          ForEach(this.matches, (match: SauceNaoMatch) => {
            ListItem() {
              SauceNaoResultItem({ match: match })
            }
          }, (match: SauceNaoMatch) => match.illustId.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .padding({ left: 16, right: 16, top: 4 })
      }
      .width('100%')
      .height('100%')
    } else {
      Column({ space: 20 }) {
        SymbolGlyph($r('sys.symbol.picture_star_fill'))
          .fontSize(64)
          .fontColor([$r('sys.color.font_tertiary')])
        Text($r('app.string.image_search'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        Text($r('app.string.image_search_desc'))
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
        Button($r('app.string.pick_image'))
          .onClick(() => {
            this.pickAndSearch()
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
  }
}

/** 单条匹配结果：缩略图/标题/作者通过 pixiv API 按需拉取（对齐 pixez） */
@ComponentV2
struct SauceNaoResultItem {

  @Param @Require match: SauceNaoMatch = new SauceNaoMatch();
  @Local illust: PixivIllust | null = null;
  @Local failed: boolean = false;

  aboutToAppear(): void {
    this.fetchDetail();
  }

  private async fetchDetail(): Promise<void> {
    try {
      this.illust = await pixiv.getIllustDetail(this.match.illustId);
    } catch (e) {
      const err = e as BusinessError;
      this.failed = true;
      logger.warn(`fetch illust ${this.match.illustId} failed: ${err.message}`);
    }
  }

  private subtitleText(): string {
    const parts: string[] = [];
    if (this.match.similarity) {
      parts.push(this.match.similarity);
    }
    if (this.illust?.user?.name) {
      parts.push(this.illust.user.name);
    }
    parts.push(`#${this.match.illustId}`);
    return parts.join(' · ');
  }

  build() {
    Row({ space: 12 }) {
      if (this.illust) {
        PixivImageComponent({
          imageUrl: this.illust.image_urls.square_medium,
          imageWidth: 56,
          imageHeight: 56,
          imageBorder: { radius: 8 },
          imageObjectFit: ImageFit.Cover
        })
      } else {
        Column() {
          if (this.failed) {
            Text(':(')
              .fontSize(18)
              .fontColor($r('sys.color.font_tertiary'))
          } else {
            LoadingProgress()
              .width(20)
              .height(20)
              .color($r('sys.color.font_tertiary'))
          }
        }
        .width(56)
        .height(56)
        .borderRadius(8)
        .backgroundColor($r('sys.color.background_tertiary'))
        .justifyContent(FlexAlign.Center)
      }

      Column({ space: 4 }) {
        Text(this.illust ? this.illust.title : `Pixiv #${this.match.illustId}`)
          .fontSize(15)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.subtitleText())
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .padding(12)
    .borderRadius(16)
    .backgroundColor($r('sys.color.background_secondary'))
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      const params: DetailPageParams = { id: this.match.illustId };
      PixState.pushPage('illust_detail', params, true);
    })
  }
}
