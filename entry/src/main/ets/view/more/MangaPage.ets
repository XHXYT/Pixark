import { NaviContainer } from "../../components/NaviContainer";
import { PixState } from "../../entryability/AppState";
import { mangaVM } from "../../viewmodel/MangaViewModel";
import { WaterFlowView } from "../../components/WaterFlowView";
import { PixivImageComponent } from "../../components/PixivImage";
import { PixivIllust, WatchListSeriesModel } from "../../services/PixivTypes";
import IllustHistoryInfo from "../../common/entity/IllustHistoryInfo";
import { DetailPageParams } from "../../common/entity/DetailEntity";
import { CardUtil } from "../../common/utils/CardUtil";
import { SnapShotUtils } from "../../common/utils/SnapShotUtils";
import { toastUtil } from "../../common/utils/ToastUtils";
import { createLogger } from "../../common/utils/Logger";
import { image } from "@kit.ImageKit";
import { BusinessError } from "@kit.BasicServicesKit";

const logger = createLogger('MangaPage')

/** 漫画：推荐瀑布流 + 在追系列 */
@Builder
export function MangaPageBuilder() {
  MangaPage()
}

@ComponentV2
struct MangaPage {

  /** 当前页签：0 推荐 / 1 在追 */
  @Local currentTab: number = 0

  // 嵌套滚动选项（同主页/排行：外层优先向前，自身优先回弹）
  private nestedScrollOptions: NestedScrollOptions = {
    scrollForward: NestedScrollMode.PARENT_FIRST,
    scrollBackward: NestedScrollMode.SELF_FIRST
  }

  aboutToAppear(): void {
    mangaVM.initIfNeeded()
  }

  build() {
    NaviContainer({
      title: $r('app.string.manga'),
      content: () => {
        this.Content()
      },
      onReady: (ctx: NavDestinationContext) => {
      },
      onBackPressed: () => {
        return false
      },
      onNaviShown: () => {
        // 返回本页时按需刷新（如在详情页追更/取消追更了系列、产生了新的浏览历史）
        mangaVM.initIfNeeded()
        mangaVM.refreshWatchIfLoaded()
        if (this.currentTab === 2) {
          mangaVM.loadMangaHistory()
        }
      }
    })
  }

  @Builder
  Content() {
    if (mangaVM.isInitialLoading) {
      this.LoadingView()
    } else {
      this.MainList()
    }
  }

  /** 主体：Hero 横幅 + 吸顶页签 + 内容 */
  @Builder
  MainList() {
    Refresh({ refreshing: mangaVM.isRefreshing }) {
      List() {
        // 主题色渐变 Hero 横幅（跟随滚动划出屏幕）
        ListItem() {
          // 外层用 padding 收边：margin 叠加 width('100%') 会导致整体右溢出
          Column() {
            this.Hero()
          }
          .width('100%')
          .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
        }
        // 页签（sticky 吸顶）
        ListItemGroup({ header: this.TabsRow() }) {
          if (this.currentTab === 0) {
            this.RecommendContent()
          } else if (this.currentTab === 1) {
            this.WatchContent()
          } else {
            this.HistoryContent()
          }
        }
      }
      .sticky(StickyStyle.Header)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .height('100%')
      .contentEndOffset(PixState.bottomRectHeight)
      .margin({ right: PixState.rightAvoidWidth, left: PixState.leftAvoidWidth })
      .onReachEnd(() => {
        // 在追页签由外层 List 触底加载；推荐页签由瀑布流自身触底
        if (this.currentTab === 1) {
          mangaVM.loadMoreWatch()
        }
      })
    }
    .onRefreshing(() => {
      if (this.currentTab === 0) {
        mangaVM.loadRecommended()
      } else if (this.currentTab === 1) {
        mangaVM.loadWatchList()
      } else {
        mangaVM.loadMangaHistory()
      }
    })
  }

  /** 主题色渐变 Hero 横幅 */
  @Builder
  Hero() {
    Stack({ alignContent: Alignment.End }) {
      Row({ space: 14 }) {
        SymbolGlyph($r('sys.symbol.bookmark_book_closed'))
          .fontSize(28)
          .fontColor([Color.White])
          .padding(11)
          .borderRadius(25)
          .backgroundColor('#33FFFFFF')
        Column({ space: 4 }) {
          Text($r('app.string.manga_hero_title'))
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
          Text($r('app.string.manga_hero_subtitle'))
            .fontSize(12)
            .fontColor('#E6FFFFFF')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 右下角装饰性大图标
      SymbolGlyph($r('sys.symbol.bookmark_book_closed'))
        .fontSize(110)
        .fontColor([Color.White])
        .opacity(0.15)
        .margin({ right: -12 })
        .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .borderRadius(18)
    .clip(true)
    .linearGradient({
      angle: 135,
      colors: [[PixState.currentThemeColor, 0.05], [$r('sys.color.background_primary'), 1]]
    })
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .margin({ top: 4, bottom: 6 })
    .shadow({
      radius: 14,
      color: $r('app.color.card_shadow_color'),
      offsetX: 6,
      offsetY: 6
    })
  }

  /** 吸顶页签行：推荐 / 在追 / 历史 */
  @Builder
  TabsRow() {
    Row({ space: 10 }) {
      this.TabPill($r('app.string.manga_recommend_tab'), 0)
      this.TabPill($r('app.string.manga_watch_tab'), 1)
      this.TabPill($r('app.string.manga_history_tab'), 2)
    }
    .width('100%')
    .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue, top: 10, bottom: 10 })
    .backgroundColor($r('sys.color.background_primary'))
    .zIndex(10)
  }

  @Builder
  TabPill(label: ResourceStr, index: number) {
    Text(label)
      .fontSize(14)
      .fontWeight(this.currentTab === index ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.currentTab === index ? Color.White : $r('sys.color.font_secondary'))
      .padding({ left: 20, right: 20, top: 8, bottom: 8 })
      .borderRadius(20)
      .backgroundColor(this.currentTab === index ? PixState.currentThemeColor : $r('sys.color.comp_background_tertiary'))
      .onClick(() => {
        this.switchTab(index)
      })
  }

  /** 推荐页签内容：漫画瀑布流 */
  @Builder
  RecommendContent() {
    ListItem() {
      if (mangaVM.mangaIllusts.length === 0) {
        this.EmptyHint($r('app.string.manga_recommend_empty'))
      } else {
        WaterFlowView({
          illustList: mangaVM.mangaIllusts,
          nestedScroll: this.nestedScrollOptions,
          clipContent: false,
          onCardClick: (illust: PixivIllust) => {
            this.onCardClick(illust)
          },
          onReachEnd: () => {
            mangaVM.loadMoreManga()
          }
        })
      }
    }
  }

  /** 在追页签内容：漫画系列卡片列表 */
  @Builder
  WatchContent() {
    if (mangaVM.watchLoading && mangaVM.watchSeries.length === 0) {
      ListItem() {
        this.EmptyHint($r('app.string.loading_info'))
      }
    } else if (mangaVM.watchSeries.length === 0) {
      ListItem() {
        this.EmptyHint($r('app.string.manga_watch_empty'))
      }
    } else {
      ForEach(mangaVM.watchSeries, (series: WatchListSeriesModel) => {
        ListItem() {
          // 外层 padding 收边（margin + width('100%') 会右溢出）
          Column() {
            this.SeriesCard(series)
          }
          .width('100%')
          .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
        }
      }, (series: WatchListSeriesModel) => `${series.id}`)
    }
  }

  /** 历史页签内容：漫画浏览记录列表 */
  @Builder
  HistoryContent() {
    if (mangaVM.historyLoading && mangaVM.mangaHistory.length === 0) {
      ListItem() {
        this.EmptyHint($r('app.string.loading_info'))
      }
    } else if (mangaVM.mangaHistory.length === 0) {
      ListItem() {
        this.EmptyHint($r('app.string.manga_history_empty'))
      }
    } else {
      ForEach(mangaVM.mangaHistory, (item: IllustHistoryInfo) => {
        ListItem() {
          // 外层 padding 收边（margin + width('100%') 会右溢出）
          Column() {
            this.HistoryCard(item)
          }
          .width('100%')
          .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
        }
      }, (item: IllustHistoryInfo) => `${item.id ?? item.pid}`)
    }
  }

  /** 漫画历史卡片：点击打开详情，长按删除记录 */
  @Builder
  HistoryCard(item: IllustHistoryInfo) {
    Row({ space: 12 }) {
      // 封面
      PixivImageComponent({
        imageUrl: item.coverUrl || '',
        imageWidth: 56,
        imageHeight: 56,
        imageBorder: { radius: 10 }
      })
      Column({ space: 4 }) {
        Text(item.title || item.pid)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(formatHistoryTime(item.accessTime))
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(14)
        .fontColor([$r('sys.color.font_fourth')])
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(16)
    .backgroundColor($r('sys.color.comp_background_list_card'))
    .shadow({
      radius: 10,
      color: $r('app.color.card_shadow_color'),
      offsetX: 4,
      offsetY: 4
    })
    .onClick(() => {
      this.openHistory(item)
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          this.confirmDeleteHistory(item)
        })
    )
  }

  /** 在追系列卡片：点击看最新一话，长按取消追更 */
  @Builder
  SeriesCard(series: WatchListSeriesModel) {
    Row({ space: 12 }) {
      // 作者头像
      PixivImageComponent({
        imageUrl: series.user?.profile_image_urls?.medium || '',
        imageWidth: 46,
        imageHeight: 46,
        imageBorder: { radius: 23 }
      })
      Column({ space: 3 }) {
        Text(series.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text($r('app.string.manga_series_info', series.published_content_count, formatUpdateDate(series.last_published_content_datetime)))
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
        if (series.user) {
          Text(series.user.name)
            .fontSize(12)
            .fontColor($r('sys.color.font_tertiary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      // 看最新一话按钮
      Text($r('app.string.manga_open_latest'))
        .fontSize(13)
        .fontColor(Color.White)
        .padding({ left: 14, right: 14, top: 7, bottom: 7 })
        .borderRadius(17)
        .backgroundColor(PixState.currentThemeColor)
    }
    .width('100%')
    .padding({ left: 14, right: 12, top: 12, bottom: 12 })
    .borderRadius(16)
    .backgroundColor($r('sys.color.comp_background_list_card'))
    .shadow({
      radius: 10,
      color: $r('app.color.card_shadow_color'),
      offsetX: 4,
      offsetY: 4
    })
    .onClick(() => {
      this.openLatest(series)
    })
    .gesture(
      LongPressGesture()
        .onAction(() => {
          this.confirmUnwatch(series)
        })
    )
  }

  /** 初始加载中 */
  @Builder
  LoadingView() {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(36)
        .height(36)
        .color(PixState.currentThemeColor)
      Text($r('app.string.loading_info'))
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  /** 空态提示 */
  @Builder
  EmptyHint(message: ResourceStr) {
    Column({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.bookmark_book_closed'))
        .fontSize(48)
        .fontColor([$r('sys.color.font_fourth')])
      Text(message)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
        .lineHeight(20)
    }
    .width('100%')
    .padding({ top: 64, left: 32, right: 32, bottom: PixState.bottomRectHeight })
    .justifyContent(FlexAlign.Start)
  }

  /** 切换页签 */
  private switchTab(index: number): void {
    if (this.currentTab === index) return
    this.currentTab = index
    if (index === 1 && !mangaVM.watchLoaded) {
      mangaVM.loadWatchList()
    }
    if (index === 2) {
      // 漫画历史是本地查询，切换时直接刷新
      mangaVM.loadMangaHistory()
    }
  }

  /** 点击推荐卡片：截图 + 跳转详情（支持左右滑动联动） */
  private onCardClick(illust: PixivIllust): void {
    const sourceCardId = CardUtil.getFlowItemIdByIndex(illust.id)
    try {
      this.getUIContext().getComponentSnapshot().get(sourceCardId, (err: BusinessError, pixelMap: image.PixelMap) => {
        if (err || !pixelMap) {
          logger.error(`截图失败，使用普通跳转: ${JSON.stringify(err)}`)
          this.pushDetail(illust, '')
          return
        }
        SnapShotUtils.pixelMap = pixelMap
        this.pushDetail(illust, sourceCardId)
      })
    } catch (e) {
      logger.error(`点击处理异常: ${JSON.stringify(e)}`)
      this.pushDetail(illust, '')
    }
  }

  private pushDetail(illust: PixivIllust, fromId: string): void {
    const index = mangaVM.mangaIllusts.findIndex(i => i.id === illust.id)
    const params: DetailPageParams = {
      id: illust.id,
      fromId: fromId,
      illust: illust,
      swiperProvider: mangaVM,
      swiperIndex: index >= 0 ? index : 0
    }
    PixState.pushPage('illust_detail', params, true)
  }

  /** 打开系列最新一话 */
  private openLatest(series: WatchListSeriesModel): void {
    const params: DetailPageParams = {
      id: series.latest_content_id
    }
    PixState.pushPage('illust_detail', params, true)
  }

  /** 打开漫画历史记录对应的详情 */
  private openHistory(item: IllustHistoryInfo): void {
    const id = Number(item.pid)
    if (!id || id < 0) return
    const params: DetailPageParams = {
      id: id
    }
    PixState.pushPage('illust_detail', params, true)
  }

  /** 长按历史卡片：确认删除该条记录 */
  private confirmDeleteHistory(item: IllustHistoryInfo): void {
    toastUtil.showAlertDialog({
      title: $r('app.string.manga_history_delete_confirm'),
      message: item.title || item.pid,
      primaryButton: {
        value: $r('app.string.cancel'),
        action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.delete'),
        fontColor: $r('sys.color.ohos_id_color_warning'),
        action: () => {
          if (item.id !== null) {
            mangaVM.deleteMangaHistory(item.id)
          }
        }
      },
      alignment: DialogAlignment.Center
    })
  }

  /** 长按卡片：确认取消追更 */
  private confirmUnwatch(series: WatchListSeriesModel): void {
    toastUtil.showAlertDialog({
      title: $r('app.string.manga_unwatch_confirm'),
      message: series.title,
      primaryButton: {
        value: $r('app.string.cancel'),
        action: () => {
        }
      },
      secondaryButton: {
        value: $r('app.string.manga_unwatch_ok'),
        fontColor: $r('sys.color.ohos_id_color_warning'),
        action: () => {
          this.unwatch(series)
        }
      },
      alignment: DialogAlignment.Bottom
    })
  }

  private async unwatch(series: WatchListSeriesModel): Promise<void> {
    const ok = await mangaVM.unwatch(series.id)
    if (ok) {
      toastUtil.showToast({ message: $r('app.string.manga_unwatched') })
    } else {
      toastUtil.showToast({ message: $r('app.string.manga_unwatch_failed') })
    }
  }
}

/** ISO 日期 → "MM/dd"（用于在追卡片更新时间展示） */
function formatUpdateDate(iso: string): string {
  if (!iso || iso.length < 10) return ''
  return iso.substring(5, 10).replace('-', '/')
}

/** 时间戳 → "MM/dd HH:mm"（用于漫画历史卡片访问时间展示） */
function formatHistoryTime(ts: number): string {
  if (!ts) return ''
  const d = new Date(ts)
  const month = d.getMonth() + 1
  const day = d.getDate()
  const hours = d.getHours()
  const minutes = d.getMinutes()
  let result = `${month < 10 ? '0' : ''}${month}/${day < 10 ? '0' : ''}${day}`
  result += ` ${hours < 10 ? '0' : ''}${hours}:${minutes < 10 ? '0' : ''}${minutes}`
  return result
}
