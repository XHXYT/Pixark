import { webview } from "@kit.ArkWeb";
import { BusinessError } from "@kit.BasicServicesKit";
import { SpotlightArticle } from "../services/PixivTypes";
import { DetailPageParams } from "../common/entity/DetailEntity";
import { UserDetailParams } from "../common/entity/UserDetailEntity";
import { PixState } from "../entryability/AppState";
import { NaviContainer } from "../components/NaviContainer";
import { PixivImageComponent } from "../components/PixivImage";
import { createLogger } from "../common/utils/Logger";
import { installWebSchemeHandler } from "../services/direct/WebDirect";
import { toastUtil } from "../common/utils/ToastUtils";

const logger = createLogger('SpotlightPage')

// 提取轮询上限（约 120s 后放弃，停留在网页模式；pixivision 正文为客户端渲染，DOM 构建较慢）
const MAX_EXTRACT_ATTEMPTS: number = 40

// 捕获期间骨架屏作品卡槽位
const SKELETON_SLOTS: number[] = [0, 1, 2, 3];

/** pixivision 文章内作品（严格模型） */
class SpotWork {
  illustId: number = 0;
  userId: number = 0;
  title: string = '';
  image: string = '';
  userName: string = '';
  userImage: string = '';
}

/** runJavaScript 返回 JSON 的原始形状 */
interface SoupRawWork {
  illustId?: number;
  userId?: number;
  title?: string;
  image?: string;
  userName?: string;
  userImage?: string;
}

interface SoupRawProbe {
  title?: string;
  article?: number;
  amBody?: number;
  snippet?: string;
}

interface SoupRawResult {
  ok?: boolean;
  description?: string;
  works?: SoupRawWork[];
  probe?: SoupRawProbe;
}

// 注入网页的提取脚本（结构无关，兼容新旧版 pixivision）：
// 导语取 amsp__header（新版）/ article>header（旧版）内的 <p> 文本；
// 作品卡：全文档扫描 artworks/{id} 链接，向上找同时含 users 链接与 img 的容器，
// 从容器内取标题(h3/链接文本)、封面(非画师区 img)、画师(id/文本/头像 img)；
// probe 回传 DOM 结构信息用于诊断
const SOUP_EXTRACT_JS = `(function () {
  try {
    var out = { ok: false, description: '', works: [], probe: { title: document.title, article: 0, amBody: 0, snippet: '' } };
    var arts = document.getElementsByTagName('article');
    out.probe.article = arts ? arts.length : 0;
    out.probe.amBody = document.getElementsByClassName('am__body').length;

    var desc = '';
    var heads = document.getElementsByClassName('amsp__header');
    if (!heads || !heads.length) {
      var oldHeads = arts && arts.length ? arts[0].getElementsByTagName('header') : [];
      heads = oldHeads;
    }
    if (heads && heads.length) {
      var ps = heads[0].getElementsByTagName('p');
      var parts = [];
      for (var i = 0; i < ps.length; i++) {
        var t = (ps[i].textContent || '').replace(/\\s+/g, ' ').trim();
        if (t) { parts.push(t); }
      }
      desc = parts.join('\\n');
    }

    var works = [];
    var seen = {};
    var links = document.getElementsByTagName('a');
    for (var i2 = 0; i2 < links.length; i2++) {
      var href = links[i2].getAttribute('href') || '';
      var m = href.match(/artworks\\/(\\d+)/);
      if (!m) { continue; }
      var iid = parseInt(m[1], 10);
      if (!iid || seen[iid]) { continue; }

      // 向上找同时含 users 链接与 img 的卡片容器
      var card = links[i2];
      var userLink = null;
      for (var lv = 0; lv < 8; lv++) {
        if (!card || !card.getElementsByTagName || card === document.body) { card = null; break; }
        var uls = card.getElementsByTagName('a');
        var hasUser = false;
        for (var uj = 0; uj < uls.length; uj++) {
          if (/users\\/(\\d+)/.test(uls[uj].getAttribute('href') || '')) { hasUser = true; userLink = uls[uj]; break; }
        }
        if (hasUser && card.getElementsByTagName('img').length >= 1) { break; }
        card = card.parentElement;
      }
      if (!card || card === document.body) { continue; }

      var mu = userLink ? ((userLink.getAttribute('href') || '').match(/users\\/(\\d+)/)) : null;
      if (!mu) { continue; }
      var work = { illustId: iid, userId: parseInt(mu[1], 10), title: '', image: '', userName: '', userImage: '' };

      // 画师头像：users 链接内的 img；封面：卡片内非画师区的第一张 img
      var cardImgs = card.getElementsByTagName('img');
      if (userLink) {
        var uImgs = userLink.getElementsByTagName('img');
        if (uImgs && uImgs.length) {
          work.userImage = uImgs[0].getAttribute('src') || uImgs[0].getAttribute('data-src') || '';
        }
      }
      for (var ik = 0; ik < cardImgs.length; ik++) {
        var insideUser = false;
        var pn = cardImgs[ik].parentElement;
        for (var pk = 0; pk < 6 && pn; pk++) {
          if (userLink && pn === userLink) { insideUser = true; break; }
          pn = pn.parentElement;
        }
        if (!insideUser) {
          work.image = cardImgs[ik].getAttribute('src') || cardImgs[ik].getAttribute('data-src') || '';
          break;
        }
      }
      if (!work.image && cardImgs.length) {
        work.image = cardImgs[0].getAttribute('src') || '';
      }

      // 标题：h3，否则取 artworks 链接文本
      var h3s = card.getElementsByTagName('h3');
      if (h3s && h3s.length) {
        work.title = (h3s[0].textContent || '').replace(/\\s+/g, ' ').trim();
      }
      if (!work.title) {
        work.title = (links[i2].textContent || '').replace(/\\s+/g, ' ').trim();
      }

      // 画师名：users 链接文本，否则卡片内第一个 <p>
      if (userLink) {
        work.userName = (userLink.textContent || '').replace(/\\s+/g, ' ').trim();
      }
      if (!work.userName) {
        var cps = card.getElementsByTagName('p');
        if (cps && cps.length) {
          work.userName = (cps[0].textContent || '').replace(/\\s+/g, ' ').trim();
        }
      }

      seen[iid] = true;
      works.push(work);
      if (!out.probe.snippet) {
        out.probe.snippet = String(card.innerHTML).replace(/\\s+/g, ' ').substring(0, 300);
      }
    }
    out.ok = true;
    out.description = desc;
    out.works = works;
    return 'SOUPJSON:' + JSON.stringify(out);
  } catch (e) {
    return 'SOUPJSON:' + JSON.stringify({ ok: false, description: '', works: [], probe: { title: String(e), article: -1, amBody: -1, snippet: '' } });
  }
})()`

@Builder
export function SpotlightPageBuilder(name: string, param: Object) {
  SpotlightPage()
}

@ComponentV2
struct SpotlightPage {

  webviewController: webview.WebviewController = new webview.WebviewController();

  @Local article: SpotlightArticle | null = null;
  // 0 解析中（网页可见） 1 原生渲染 2 网页模式（放弃解析）
  @Local loadState: number = 0;
  @Local works: SpotWork[] = [];
  @Local description: string = '';

  private urlLoaded: boolean = false;
  private extractAttempts: number = 0;
  private pollTimer: number = -1;

  aboutToDisappear(): void {
    this.stopPolling();
  }

  build() {
    NaviContainer({
      title: this.article ? this.article.pure_title : $r('app.string.spotlight'),
      content: () => {
        this.Content()
      },
      onReady: (ctx: NavDestinationContext) => {
        this.onReady(ctx)
      },
      onBackPressed: () => {
        return false
      }
    })
  }

  private onReady(ctx: NavDestinationContext): void {
    const p: SpotlightArticle | null = ctx.pathInfo.param as SpotlightArticle | null;
    if (p) {
      this.article = p;
    }
    logger.warn(`onReady: ${this.article ? this.article.article_url : 'no article'}`);
    this.tryLoadUrl();
    this.startPolling();
  }

  private tryLoadUrl(): void {
    if (this.urlLoaded || !this.article) {
      return;
    }
    try {
      this.webviewController.loadUrl(this.article.article_url);
      this.urlLoaded = true;
      logger.warn(`loadUrl: ${this.article.article_url}`);
    } catch (error) {
      // controller 尚未就绪，等待 onControllerAttached 重试
      const err = error as BusinessError;
      logger.warn(`loadUrl pending: ${err.message}`);
    }
  }

  private startPolling(): void {
    if (this.pollTimer >= 0) {
      return;
    }
    this.pollTimer = setInterval(() => {
      this.tryExtract();
    }, 3000);
  }

  private stopPolling(): void {
    if (this.pollTimer >= 0) {
      clearInterval(this.pollTimer);
      this.pollTimer = -1;
    }
  }

  private tryExtract(): void {
    if (this.loadState !== 0) {
      return;
    }
    if (this.extractAttempts >= MAX_EXTRACT_ATTEMPTS) {
      this.loadState = 2;
      this.stopPolling();
      logger.warn('extract timeout, stay in web mode');
      toastUtil.showToast({ message: $r('app.string.parse_timeout_web_mode') });
      return;
    }
    if (!this.urlLoaded) {
      return;
    }
    this.extractAttempts++;
    try {
      this.webviewController.runJavaScript(SOUP_EXTRACT_JS, (err: BusinessError, result: string) => {
        if (err) {
          logger.warn(`runJavaScript err: ${err.message}`);
          return;
        }
        if (typeof result === 'string') {
          this.handleExtractResult(result);
        } else {
          logger.warn(`runJavaScript empty result (attempt ${this.extractAttempts})`);
        }
      });
    } catch (error) {
      const e = error as BusinessError;
      logger.warn(`runJavaScript pending: ${e.message}`);
    }
  }

  private handleExtractResult(result: string): void {
    try {
      let json: string = result;
      // runJavaScript 的字符串返回值会额外带一层 JSON 编码（以引号开头）
      if (json.length > 0 && json.charAt(0) === '"') {
        json = JSON.parse(json) as string;
      }
      const marker = 'SOUPJSON:';
      if (json.indexOf(marker) !== 0) {
        logger.warn(`unexpected extract result: ${json.substring(0, 200)}`);
        return;
      }
      const raw = JSON.parse(json.substring(marker.length)) as SoupRawResult;
      if (raw.ok !== true) {
        const probe = raw.probe;
        if (probe) {
          logger.warn(`extract not ok (attempt ${this.extractAttempts}): title=${probe.title ?? ''} article=${probe.article ?? -1} amBody=${probe.amBody ?? -1} snippet=${(probe.snippet ?? '').substring(0, 300)}`);
        }
        return;
      }
      this.applyResult(raw);
    } catch (error) {
      const e = error as BusinessError;
      logger.error(`parse extract result failed: ${e.message}`);
    }
  }

  private applyResult(raw: SoupRawResult): void {
    const list: SpotWork[] = [];
    const rawWorks = raw.works ?? [];
    for (let i = 0; i < rawWorks.length; i++) {
      const w = rawWorks[i];
      if (!w) {
        continue;
      }
      if (typeof w.illustId !== 'number' || typeof w.userId !== 'number') {
        continue;
      }
      if (!(w.illustId > 0) || !(w.userId > 0)) {
        continue;
      }
      const item = new SpotWork();
      item.illustId = w.illustId;
      item.userId = w.userId;
      item.title = typeof w.title === 'string' ? w.title : '';
      item.image = typeof w.image === 'string' ? w.image : '';
      item.userName = typeof w.userName === 'string' ? w.userName : '';
      item.userImage = typeof w.userImage === 'string' ? w.userImage : '';
      list.push(item);
    }
    const desc = typeof raw.description === 'string' ? raw.description : '';
    const probe = raw.probe;
    if (list.length === 0 && desc.length === 0) {
      // 可能仍是挑战页或结构异常，继续轮询
      logger.warn(`extract ok but empty (works=0, desc=0, attempt ${this.extractAttempts}): title=${probe?.title ?? ''} article=${probe?.article ?? -1} amBody=${probe?.amBody ?? -1} snippet=${(probe?.snippet ?? '').substring(0, 300)}`);
      return;
    }
    this.works = list;
    this.description = desc;
    this.loadState = 1;
    this.stopPolling();
    logger.warn(`extract ok, works=${list.length}, descLen=${desc.length}, cardSnippet=${(probe?.snippet ?? '').substring(0, 200)}`);
  }

  /** 拦截作品/画师跳转，转原生页面 */
  private interceptLink(url: string): boolean {
    if (this.loadState === 1) {
      return false;
    }
    const artMatch = url.match(/pixiv\.net\/artworks\/(\d+)/);
    if (artMatch) {
      const params: DetailPageParams = { id: parseInt(artMatch[1]) };
      PixState.pushPage('illust_detail', params, true);
      return true;
    }
    const userMatch = url.match(/pixiv\.net\/users\/(\d+)/);
    if (userMatch) {
      const params: UserDetailParams = { id: parseInt(userMatch[1]) };
      PixState.pushPage('user_detail', params, true);
      return true;
    }
    return false;
  }

  private openWork(work: SpotWork): void {
    const params: DetailPageParams = { id: work.illustId };
    PixState.pushPage('illust_detail', params, true);
  }

  /** 从封面 URL 解析插画 ID（pxivision 封面通常为文章代表作，URL 含 {illustId}_p0） */
  private heroIllustId(): number {
    const url = this.article?.main_image ?? this.article?.thumbnail ?? '';
    const m = url.match(/(\d+)_p\d+/);
    return m ? parseInt(m[1], 10) : -1;
  }

  private openHero(): void {
    const id = this.heroIllustId();
    if (id > 0) {
      const params: DetailPageParams = { id: id };
      PixState.pushPage('illust_detail', params, true);
    } else {
      toastUtil.showToast({ message: $r('app.string.cover_not_illust') });
    }
  }

  private openUser(work: SpotWork): void {
    const params: UserDetailParams = { id: work.userId };
    PixState.pushPage('user_detail', params, true);
  }

  private dateText(): string {
    const d = this.article?.publish_date ?? '';
    return d.length >= 10 ? d.substring(0, 10) : d;
  }

  @Builder
  Content() {
    Stack({ alignContent: Alignment.Top }) {
      Web({ src: '', controller: this.webviewController })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .cacheMode(CacheMode.Default)
        .mixedMode(MixedMode.All)
        .onControllerAttached(() => {
          try {
            this.webviewController.setCustomUserAgent('Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36');
          } catch (error) {
            const err = error as BusinessError;
            logger.error(`setCustomUserAgent failed: ${err.message}`);
          }
          try {
            // 直连桥：Pixiv 域名（ECH/COMPAT 模式）接管 WebView 网络层
            installWebSchemeHandler(this.webviewController);
          } catch (error) {
            const err = error as BusinessError;
            logger.error(`install scheme handler failed: ${err.message}`);
          }
          this.tryLoadUrl();
        })
        .onPageEnd(() => {
          this.tryExtract();
        })
        .onLoadIntercept((event: OnLoadInterceptEvent) => {
          return this.interceptLink(event.data.getRequestUrl());
        })
        .onErrorReceive((event) => {
          const errInfo = event.error;
          if (event.request?.isMainFrame()) {
            logger.error(`main frame error - Code: ${errInfo.getErrorCode()}, Message: ${errInfo.getErrorInfo()}`);
          }
        })
        .width('100%')
        .height('100%')

      if (this.loadState !== 2) {
        // 加载中骨架 / 原生数据视图（不透明背景盖住底层捕获用 Web）
        this.ArticleView()
      }
      // loadState === 2: 网页回退模式，无覆盖层
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  ArticleView() {
    Scroll() {
      Column() {
        PixivImageComponent({
          imageUrl: this.article?.main_image ?? this.article?.thumbnail ?? '',
          imageObjectFit: ImageFit.Cover
        })
          .width('100%')
          .aspectRatio(1.78)
          .onClick(() => this.openHero())

        Column({ space: 10 }) {
          Text(this.article?.pure_title ?? '')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .width('100%')

          Row({ space: 8 }) {
            if (this.article?.category) {
              Text(this.article.category)
                .fontSize(12)
                .fontColor(Color.White)
                .backgroundColor(PixState.currentThemeColor)
                .borderRadius(4)
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            }
            Text(this.dateText())
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')

          Text(this.article?.author_name ?? '')
            .fontSize(13)
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')

          if (this.loadState === 0) {
            // 捕获期间：描述 + 作品列表骨架屏
            this.SkeletonPart()
          } else {
            if (this.description) {
              Text(this.description)
                .fontSize(15)
                .fontColor($r('sys.color.font_secondary'))
                .lineHeight(24)
                .width('100%')
                .margin({ top: 4 })
            }

            ForEach(this.works, (work: SpotWork) => {
              this.WorkItem(work)
            }, (work: SpotWork) => work.illustId.toString())
          }
        }
        .padding(16)
        .width('100%')
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.TopStart)
  }

  @Builder
  SkeletonPart() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        LoadingProgress()
          .width(16)
          .height(16)
          .color($r('sys.color.font_secondary'))
        Text($r('app.string.loading_work_list'))
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .margin({ top: 4 })

      // 描述骨架
      Column({ space: 8 }) {
        Row()
          .height(14)
          .width('92%')
          .borderRadius(7)
          .backgroundColor($r('sys.color.font_on_fourth'))
        Row()
          .height(14)
          .width('78%')
          .borderRadius(7)
          .backgroundColor($r('sys.color.font_on_fourth'))
        Row()
          .height(14)
          .width('85%')
          .borderRadius(7)
          .backgroundColor($r('sys.color.font_on_fourth'))
      }
      .width('100%')
      .margin({ top: 4 })

      // 作品卡骨架
      ForEach(SKELETON_SLOTS, (slot: number) => {
        this.SkeletonCard()
      }, (slot: number) => slot.toString())
    }
    .width('100%')
  }

  @Builder
  SkeletonCard() {
    Row({ space: 12 }) {
      Row()
        .width(112)
        .aspectRatio(1)
        .borderRadius(12)
        .backgroundColor($r('sys.color.font_on_fourth'))

      Column({ space: 8 }) {
        Row()
          .height(15)
          .width('90%')
          .borderRadius(7)
          .backgroundColor($r('sys.color.font_on_fourth'))
        Row()
          .height(15)
          .width('60%')
          .borderRadius(7)
          .backgroundColor($r('sys.color.font_on_fourth'))
        Row({ space: 6 }) {
          Row()
            .width(20)
            .height(20)
            .borderRadius(10)
            .backgroundColor($r('sys.color.font_on_fourth'))
          Row()
            .height(12)
            .width('40%')
            .borderRadius(6)
            .backgroundColor($r('sys.color.font_on_fourth'))
        }
        .width('100%')
      }
      .layoutWeight(1)
    }
    .width('100%')
    .padding(10)
    .borderRadius(16)
    .backgroundColor($r('sys.color.background_secondary'))
    .margin({ bottom: 10 })
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  WorkItem(work: SpotWork) {
    Row({ space: 12 }) {
      PixivImageComponent({
        imageUrl: work.image,
        imageObjectFit: ImageFit.Cover,
        imageBorder: { radius: 12 }
      })
        .width(112)
        .aspectRatio(1)
        .borderRadius(12)
        .clip(true)

      Column({ space: 6 }) {
        Text(work.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Row({ space: 6 }) {
          PixivImageComponent({
            imageUrl: work.userImage,
            imageObjectFit: ImageFit.Cover,
            imageBorder: { radius: 10 }
          })
            .width(20)
            .height(20)
            .borderRadius(10)

          Text(work.userName)
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: '80%' })
        }
        .width('100%')
        .onClick(() => {
          this.openUser(work)
        })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding(10)
    .borderRadius(16)
    .backgroundColor($r('sys.color.background_secondary'))
    .margin({ bottom: 10 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.openWork(work)
    })
  }

}
