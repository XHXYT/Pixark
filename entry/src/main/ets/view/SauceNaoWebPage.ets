import { NaviContainer } from "../components/NaviContainer";
import { PixState } from "../entryability/AppState";
import { createLogger } from "../common/utils/Logger";
import { toastUtil } from "../common/utils/ToastUtils";
import { webview } from "@kit.ArkWeb";
import { BusinessError } from "@kit.BasicServicesKit";
import { DetailPageParams } from "../common/entity/DetailEntity";
import { UserDetailParams } from "../common/entity/UserDetailEntity";
import { pickImageUri, compressToJpegBuffer, uploadToSauceNao, injectBaseHref, SAUCENAO_HOME } from "../services/SauceNaoService";

const logger = createLogger('SauceNaoWebPage')

/** 以图搜图（SauceNAO WebView 模式：上传后渲染结果页，拦截 pixiv 链接跳原生） */
@Builder
export function SauceNaoWebPageBuilder(name: string, param: Object) {
  SauceNaoWebPage()
}

@ComponentV2
struct SauceNaoWebPage {

  webviewController: webview.WebviewController = new webview.WebviewController();

  // 0 待选图 1 上传中 2 网页展示
  @Local loadState: number = 0;
  @Local pickedUri: string = '';

  private searching: boolean = false;

  build() {
    NaviContainer({
      title: $r('app.string.saucenao'),
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
      this.loadState = 1;
      this.searching = true;
      const jpeg = await compressToJpegBuffer(uri);
      const html = await uploadToSauceNao(jpeg);
      this.webviewController.loadData(injectBaseHref(html), 'text/html', 'utf-8');
      this.loadState = 2;
      logger.warn('saucenao web done');
    } catch (e) {
      const err = e as BusinessError;
      logger.error(`saucenao web failed: ${err.message}`);
      // 上传失败：退回真实网页让用户手动传图（浏览器引擎可过 CF）
      toastUtil.showToast({ message: $r('app.string.upload_failed_open_web') });
      try {
        this.webviewController.loadUrl(SAUCENAO_HOME);
        this.loadState = 2;
      } catch (error) {
        const e2 = error as BusinessError;
        logger.error(`loadUrl failed: ${e2.message}`);
      }
    } finally {
      this.searching = false;
    }
  }

  /** 拦截 pixiv 链接转原生页面 */
  private interceptLink(url: string): boolean {
    if (!url.includes('pixiv.net')) {
      return false;
    }
    const art = url.match(/artworks\/(\d+)/) || url.match(/illust_id=(\d+)/);
    if (art) {
      const params: DetailPageParams = { id: parseInt(art[1], 10) };
      PixState.pushPage('illust_detail', params, true);
      return true;
    }
    const usr = url.match(/users\/(\d+)/) || url.match(/member\.php\?id=(\d+)/);
    if (usr) {
      const params: UserDetailParams = { id: parseInt(usr[1], 10) };
      PixState.pushPage('user_detail', params, true);
      return true;
    }
    return false;
  }

  @Builder
  Content() {
    Stack() {
      Web({ src: '', controller: this.webviewController })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .mixedMode(MixedMode.All)
        .onLoadIntercept((event: OnLoadInterceptEvent) => {
          return this.interceptLink(event.data.getRequestUrl());
        })
        .width('100%')
        .height('100%')

      if (this.loadState === 0) {
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
        .backgroundColor($r('sys.color.background_primary'))
      } else if (this.loadState === 1) {
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
        .backgroundColor($r('sys.color.background_primary'))
      }
    }
    .width('100%')
    .height('100%')
  }
}
