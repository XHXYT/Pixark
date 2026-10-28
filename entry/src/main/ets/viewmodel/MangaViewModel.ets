import { PixivIllust, WatchListSeriesModel } from '../services/PixivTypes';
import { createLogger } from '../common/utils/Logger';
import { toastUtil } from '../common/utils/ToastUtils';
import { pixiv } from '../services/PixivService';
import { IIllustSwiperProvider } from '../common/entity/DetailEntity';
import { muteFilter } from '../services/MuteFilter';
import IllustHistoryInfo from '../common/entity/IllustHistoryInfo';
import { IllustHistoryTable } from '../common/utils/database/impl/IllustHistoryDao';
import { _PixState } from '../entryability/AppState';

const logger = createLogger('MangaViewModel')

/**
 * 漫画页 ViewModel：推荐漫画瀑布流 + 在追系列列表 + 漫画浏览历史
 */
@ObservedV2
class MangaViewModel implements IIllustSwiperProvider {

  // 推荐漫画（瀑布流）
  @Trace mangaIllusts: PixivIllust[] = []
  @Trace nextUrl: string = ''
  @Trace isLoadingMore: boolean = false
  @Trace isRefreshing: boolean = false
  @Trace isInitialLoading: boolean = true

  // 在追漫画系列
  @Trace watchSeries: WatchListSeriesModel[] = []
  @Trace watchNextUrl: string = ''
  @Trace watchLoading: boolean = false
  @Trace watchLoaded: boolean = false

  // 漫画浏览历史（本地 DB，workType = 'manga'）
  @Trace mangaHistory: IllustHistoryInfo[] = []
  @Trace historyLoading: boolean = false
  private historyDb: IllustHistoryTable | null = null

  private getHistoryDB(): IllustHistoryTable {
    if (!this.historyDb) this.historyDb = new IllustHistoryTable(_PixState.Context)
    return this.historyDb
  }

  get illustIds(): number[] {
    return this.mangaIllusts.map(i => i.id)
  }

  get hasMore(): boolean {
    return !!this.nextUrl
  }

  get isLoading(): boolean {
    return this.isLoadingMore
  }

  async loadMore(): Promise<void> {
    await this.loadMoreManga()
  }

  /** 进入页面时按需加载（推荐首屏 + 在追列表） */
  initIfNeeded(): void {
    if (this.isInitialLoading && !this.isRefreshing) {
      this.loadRecommended()
    }
    if (!this.watchLoaded && !this.watchLoading) {
      this.loadWatchList()
    }
  }

  /** 加载推荐漫画（第一页，下拉刷新复用） */
  async loadRecommended(): Promise<void> {
    if (this.isRefreshing) return
    this.isRefreshing = true
    try {
      const data = await pixiv.getMangaRecommended()
      this.mangaIllusts = muteFilter.filterIllusts(data.illusts || [])
      this.nextUrl = data.next_url || ''
    } catch (e) {
      logger.error(`加载漫画推荐失败: ${JSON.stringify(e)}`)
      toastUtil.showToast({ message: $r('app.string.loading_failed') })
    } finally {
      this.isRefreshing = false
      this.isInitialLoading = false
    }
  }

  /** 加载更多推荐漫画 */
  async loadMoreManga(): Promise<void> {
    if (this.isLoadingMore) return
    if (!this.nextUrl) {
      toastUtil.showToast({ message: $r('app.string.recommend_not_tips') })
      return
    }
    try {
      this.isLoadingMore = true
      toastUtil.showToast({ message: $r('app.string.loading_more'), duration: 3000 })
      const data = await pixiv.getMangaRecommended(this.nextUrl)
      this.nextUrl = data.next_url || ''
      this.mergeManga(data.illusts || [])
    } catch (e) {
      logger.error(`加载更多漫画失败: ${JSON.stringify(e)}`)
      toastUtil.showToast({ message: $r('app.string.loading_failed') })
    } finally {
      this.isLoadingMore = false
    }
  }

  // 推荐漫画合并去重（过滤屏蔽项）
  private mergeManga(newIllusts: PixivIllust[]): void {
    const filtered = muteFilter.filterIllusts(newIllusts)
    if (filtered.length === 0) return
    const uniqueMap = new Map<number, PixivIllust>()
    this.mangaIllusts.forEach(i => uniqueMap.set(i.id, i))
    filtered.forEach(i => {
      if (!uniqueMap.has(i.id)) uniqueMap.set(i.id, i)
    })
    this.mangaIllusts = Array.from(uniqueMap.values())
  }

  /** 加载在追漫画系列（第一页，切换页签/下拉刷新复用） */
  async loadWatchList(): Promise<void> {
    if (this.watchLoading) return
    this.watchLoading = true
    try {
      const data = await pixiv.watchListManga()
      this.watchSeries = data.series || []
      this.watchNextUrl = data.next_url || ''
      this.watchLoaded = true
    } catch (e) {
      logger.error(`加载在追漫画失败: ${JSON.stringify(e)}`)
      toastUtil.showToast({ message: $r('app.string.loading_failed') })
    } finally {
      this.watchLoading = false
    }
  }

  /** 页面重新显示时刷新在追列表（可能从详情页追更/取消追更了） */
  refreshWatchIfLoaded(): void {
    if (this.watchLoaded && !this.watchLoading) {
      this.loadWatchList()
    }
  }

  /** 追更漫画系列，返回是否成功（已在追更时服务端报错走失败分支） */
  async watch(seriesId: number): Promise<boolean> {
    try {
      await pixiv.watchListMangaAdd(seriesId)
      // 漫画页已加载过在追列表时，刷新以显示新系列
      if (this.watchLoaded && !this.watchLoading) {
        this.loadWatchList()
      }
      return true
    } catch (e) {
      logger.error(`追更失败: ${JSON.stringify(e)}`)
      return false
    }
  }

  /** 加载更多在追系列 */
  async loadMoreWatch(): Promise<void> {
    if (this.watchLoading || !this.watchNextUrl) return
    this.watchLoading = true
    try {
      const data = await pixiv.watchListManga(this.watchNextUrl)
      this.watchNextUrl = data.next_url || ''
      const list = data.series || []
      const uniqueMap = new Map<number, WatchListSeriesModel>()
      this.watchSeries.forEach(s => uniqueMap.set(s.id, s))
      list.forEach(s => {
        if (!uniqueMap.has(s.id)) uniqueMap.set(s.id, s)
      })
      this.watchSeries = Array.from(uniqueMap.values())
    } catch (e) {
      logger.error(`加载更多在追漫画失败: ${JSON.stringify(e)}`)
      toastUtil.showToast({ message: $r('app.string.loading_failed') })
    } finally {
      this.watchLoading = false
    }
  }

  /** 取消追更，返回是否成功（本地列表同步移除） */
  async unwatch(seriesId: number): Promise<boolean> {
    try {
      await pixiv.watchListMangaDelete(seriesId)
      this.watchSeries = this.watchSeries.filter(s => s.id !== seriesId)
      return true
    } catch (e) {
      logger.error(`取消追更失败: ${JSON.stringify(e)}`)
      return false
    }
  }

  /** 加载漫画浏览历史（本地查询，切换页签时直接刷新） */
  async loadMangaHistory(): Promise<void> {
    if (this.historyLoading) return
    this.historyLoading = true
    try {
      this.mangaHistory = await this.getHistoryDB().queryByWorkType('manga')
    } catch (e) {
      logger.error(`加载漫画历史失败: ${JSON.stringify(e)}`)
    } finally {
      this.historyLoading = false
    }
  }

  /** 删除单条漫画历史记录 */
  async deleteMangaHistory(id: number): Promise<void> {
    try {
      await this.getHistoryDB().deleteById(id)
      this.mangaHistory = this.mangaHistory.filter(h => h.id !== id)
    } catch (e) {
      logger.error(`删除漫画历史失败: ${JSON.stringify(e)}`)
    }
  }
}

export const mangaVM = new MangaViewModel()
