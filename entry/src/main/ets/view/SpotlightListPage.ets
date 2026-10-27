import { SpotlightArticle } from "../services/PixivTypes";
import { pixiv } from "../services/PixivService";
import { PixState } from "../entryability/AppState";
import { NaviContainer } from "../components/NaviContainer";
import { PixivImageComponent } from "../components/PixivImage";
import { createLogger } from "../common/utils/Logger";
import { toastUtil } from "../common/utils/ToastUtils";
import { BusinessError } from "@kit.BasicServicesKit";

const logger = createLogger('SpotlightListPage')

@Builder
export function SpotlightListPageBuilder(name: string, param: Object) {
  SpotlightListPage()
}

/** Pixivision 专题列表（更多轮播数据页，长按主页轮播图进入） */
@ComponentV2
struct SpotlightListPage {

  @Local articles: SpotlightArticle[] = [];
  @Local isRefreshing: boolean = false;
  @Local isLoadingMore: boolean = false;
  @Local initialLoaded: boolean = false;
  @Local loadFailed: boolean = false;

  private nextUrl: string = '';

  aboutToAppear(): void {
    this.loadFirstPage();
  }

  private async loadFirstPage(): Promise<void> {
    if (this.isRefreshing) {
      return;
    }
    this.isRefreshing = true;
    this.loadFailed = false;
    try {
      const data = await pixiv.getSpotlight();
      this.articles = data.spotlight_articles || [];
      this.nextUrl = data.next_url || '';
      this.initialLoaded = true;
      logger.warn(`first page loaded: ${this.articles.length}`);
    } catch (e) {
      const err = e as BusinessError;
      logger.error(`load spotlight list failed: ${err.message}`);
      this.loadFailed = true;
    } finally {
      this.isRefreshing = false;
    }
  }

  private async loadMore(): Promise<void> {
    if (this.isLoadingMore || !this.nextUrl || this.isRefreshing) {
      return;
    }
    this.isLoadingMore = true;
    try {
      const data = await pixiv.getSpotlight('all', this.nextUrl);
      const more = data.spotlight_articles || [];
      const seen = new Set<number>();
      this.articles.forEach(a => seen.add(a.id));
      const merged = this.articles.slice();
      more.forEach(a => {
        if (!seen.has(a.id)) {
          merged.push(a);
          seen.add(a.id);
        }
      });
      this.articles = merged;
      this.nextUrl = data.next_url || '';
    } catch (e) {
      const err = e as BusinessError;
      logger.error(`load more spotlight failed: ${err.message}`);
      toastUtil.showToast({ message: $r('app.string.load_more_failed') });
    } finally {
      this.isLoadingMore = false;
    }
  }

  private dateText(article: SpotlightArticle): string {
    const d = article.publish_date || '';
    return d.length >= 10 ? d.substring(0, 10) : d;
  }

  build() {
    NaviContainer({
      title: $r('app.string.pixivision'),
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

  @Builder
  Content() {
    if (!this.initialLoaded && !this.loadFailed) {
      Column({ space: 12 }) {
        LoadingProgress()
          .width(36)
          .height(36)
          .color($r('sys.color.font_secondary'))
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else if (this.loadFailed && this.articles.length === 0) {
      Column({ space: 16 }) {
        Text($r('app.string.load_failed_check_network'))
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
        Button($r('app.string.retry'))
          .onClick(() => {
            this.loadFirstPage()
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    } else {
      Refresh({ refreshing: this.isRefreshing }) {
        List({ space: 12 }) {
          ForEach(this.articles, (article: SpotlightArticle) => {
            ListItem() {
              this.ArticleCard(article)
            }
          }, (article: SpotlightArticle) => article.id.toString())

          ListItem() {
            if (this.isLoadingMore) {
              LoadingProgress()
                .width(24)
                .height(24)
                .color($r('sys.color.font_secondary'))
                .margin({ top: 12, bottom: 20 })
            } else if (this.articles.length > 0 && !this.nextUrl) {
              Text($r('app.string.no_more'))
                .fontSize(12)
                .fontColor($r('sys.color.font_tertiary'))
                .margin({ top: 12, bottom: 20 })
            }
          }
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .onReachEnd(() => {
          this.loadMore()
        })
        .padding({ left: 16, right: 16, top: 4 })
      }
      .onRefreshing(() => {
        this.loadFirstPage()
      })
    }
  }

  @Builder
  ArticleCard(article: SpotlightArticle) {
    Column({ space: 8 }) {
      PixivImageComponent({
        imageUrl: article.thumbnail,
        imageObjectFit: ImageFit.Cover,
        imageBorder: { radius: 12 }
      })
        .width('100%')
        .aspectRatio(1.75)
      Text(article.title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Row({ space: 8 }) {
        if (article.category) {
          Text(article.category)
            .fontSize(11)
            .fontColor(Color.White)
            .backgroundColor(PixState.currentThemeColor)
            .borderRadius(4)
            .padding({ left: 6, right: 6, top: 1, bottom: 1 })
        }
        Text(this.dateText(article))
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(12)
    .borderRadius(16)
    .backgroundColor($r('sys.color.background_secondary'))
    .onClick(() => {
      PixState.pushPage('spotlight', article, true)
    })
  }
}
