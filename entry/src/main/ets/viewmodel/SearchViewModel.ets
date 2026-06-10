import { DetailPageParams, IIllustSwiperProvider } from '../common/entity/DetailEntity';
import SearchHistoryInfo from '../common/entity/SearchHistoryInfo';
import { generateSuggestions, SuggestionItem } from '../common/entity/SearchSuggestion';
import { PixState, _PixState } from '../entryability/AppState';
import { PixivIllust, PixivNovel, PixivTrendingTag, UserPreview } from '../services/PixivTypes';
import { SearchHistoryTable } from '../common/utils/database/impl/SearchHistoryDao';
import { createLogger } from '../common/utils/Logger';
import { toastUtil } from '../common/utils/ToastUtils';
import { pixiv } from '../services/PixivService';
import { appSettings } from '../common/entity/SettingsModel';

const logger = createLogger('SearchViewModel')


@ObservedV2
class SearchViewModel implements IIllustSwiperProvider {

  // 搜索历史
  @Trace searchHistory: SearchHistoryInfo[] = []
  // 推荐标签
  @Trace trendingTags: PixivTrendingTag[] = [];
  // 搜索建议
  @Trace suggestions: SuggestionItem[] = [];
  // 搜索结果(插画)
  @Trace resultIllusts: PixivIllust[] = []
  // 小说搜索结果
  @Trace resultNovels: PixivNovel[] = []
  @Trace resultUsers: UserPreview[] = []

  @Trace showSuggestions: boolean = false
  @Trace searchHistoryEdit: boolean = false
  @Trace isLoadingMore: boolean = false;

  private IllustNextUrl: string = '';
  private novelNextUrl: string = '';
  private userNextUrl: string = '';

  @Trace keyword: string = '';
  @Trace searchType: 'illust' | 'novel' | 'user' = 'illust';

  private lastSearchedIllustKeyword: string = '';
  private lastSearchedNovelKeyword: string = '';
  private lastSearchedUserKeyword: string = '';

  private debounceTimerId: number = -1;
  private searchHistoryDB: SearchHistoryTable | null = null;

  // 嵌套滚动配置
  get nestedScrollOptions(): NestedScrollOptions {
    return {
      scrollForward: NestedScrollMode.PARENT_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST,
    };
  }
  get illustIds(): number[] { return this.searchType === 'illust' ? this.resultIllusts.map(i => i.id) : []; }
  get hasMore(): boolean {
    if (this.searchType === 'illust') return !!this.IllustNextUrl;
    if (this.searchType === 'novel') return !!this.novelNextUrl;
    return false;  // 画师模式不支持插画 Swiper 联动
  }
  get isLoading(): boolean { return this.isLoadingMore; }
  async loadMore(): Promise<void> { await this.loadMoreSearchResult(); }

  /**
   * 重置搜索状态
   * 通常在全局模式切换后，或重新进入搜索主页时调用
   */
  private resetSearchState() {
    // 强制将 searchType 对齐到当前全局模式
    this.searchType = appSettings.novel_mode ? 'novel' : 'illust';
    // 清空所有搜索结果和翻页 URL
    this.resultIllusts = [];
    this.resultNovels = [];
    this.resultUsers = [];
    this.IllustNextUrl = '';
    this.novelNextUrl = '';
    this.userNextUrl = '';
    // 清空缓存的关键词，确保下次搜索会真去请求
    this.lastSearchedIllustKeyword = '';
    this.lastSearchedNovelKeyword = '';
    this.lastSearchedUserKeyword = '';
    // 清空当前关键词
    this.keyword = '';
  }

  // 获取数据库实例，实现懒加载
  private getDB(): SearchHistoryTable {
    if (!this.searchHistoryDB) {
      // 确保 Context 存在
      if (!_PixState.Context) {
        logger.error('Context 未初始化！');
        // 抛出错误或返回一个空壳对象防止崩溃，这里建议抛错以便发现
        throw new Error("Database Context is not ready!");
      }
      this.searchHistoryDB = new SearchHistoryTable(_PixState.Context);
    }
    return this.searchHistoryDB;
  }

  // 加载 搜索历史 & 推荐标签
  async loadData() {
    // 每次加载搜索主页数据时，先重置一下状态，避免模式切换后的残留
    this.resetSearchState();
    try {
      // await this.getDB().fixNullSearchType();
      const mode = appSettings.novel_mode ? 'novel' : 'illust';
      const values = await this.getDB().queryByMode(mode)
      this.searchHistory = values
    } catch (e) {
      logger.error('[DB_INIT] 加载搜索历史失败: ', e);
    }
    try {
      this.trendingTags = appSettings.novel_mode ? await pixiv.getNovelTrendTags() : await pixiv.getTrendingTags();
    } catch (e) {
      logger.error('加载热门标签失败:', e);
    }
  }

  async doSearch(force: boolean = false) {
    if (!this.keyword) return;
    this.showSuggestions = false

    let shouldRequest = true;
    if (!force) {
      if (this.searchType === 'illust' && this.keyword === this.lastSearchedIllustKeyword) shouldRequest = false;
      else if (this.searchType === 'novel' && this.keyword === this.lastSearchedNovelKeyword) shouldRequest = false;
      else if (this.searchType === 'user' && this.keyword === this.lastSearchedUserKeyword) shouldRequest = false;
    }
    if (!shouldRequest) return;

    try {
      if (this.searchType === 'illust') {
        const data = await pixiv.searchIllust(this.keyword, undefined, { sort: 'popular_desc', minBookmark: 1000, searchTarget: 'exact_match_for_tags' });
        this.resultIllusts = data.illusts as PixivIllust[];
        this.IllustNextUrl = data.next_url || '';
        this.lastSearchedIllustKeyword = this.keyword;
      }
      // 小说搜索逻辑
      else if (this.searchType === 'novel') {
        const data = await pixiv.searchNovel(this.keyword, undefined, { sort: 'popular_desc', searchTarget: 'exact_match_for_tags' });
        this.resultNovels = data.novels || [];
        this.novelNextUrl = data.next_url || '';
        this.lastSearchedNovelKeyword = this.keyword;
      }
      else {
        const data = await pixiv.searchUser(this.keyword);
        this.resultUsers = data.user_previews;
        this.userNextUrl = data.next_url || '';
        this.lastSearchedUserKeyword = this.keyword;
      }
    } catch (e) { logger.error(`[搜索异常] ${JSON.stringify(e)}`); }
  }

  // 加载更多
  async loadMoreSearchResult() {
    if (this.isLoadingMore) return; // 防抖

    const nextUrl = this.searchType === 'illust' ? this.IllustNextUrl :
      this.searchType === 'novel' ? this.novelNextUrl : this.userNextUrl;

    if (!nextUrl) {
      if ((this.searchType === 'illust' && this.resultIllusts.length > 0) ||
        (this.searchType === 'novel' && this.resultNovels.length > 0) ||
        (this.searchType === 'user' && this.resultUsers.length > 0)) {
        toastUtil.showToast({ message: $r('app.string.search_not_tips') });
      }
      return;
    }

    this.isLoadingMore = true;
    try {
      if (this.searchType === 'illust') {
        const data = await pixiv.searchIllust('', nextUrl);
        if (data.illusts)
        this.resultIllusts.push(...data.illusts);
        this.IllustNextUrl = data.next_url || '';
      } else if (this.searchType === 'novel') {
        const data = await pixiv.searchNovel('', nextUrl);
        if (data.novels) this.resultNovels.push(...data.novels);
        this.novelNextUrl = data.next_url || '';
      }  else {
        const data = await pixiv.searchUser('', nextUrl);
        this.resultUsers.push(...data.user_previews);
        this.userNextUrl = data.next_url || '';
      }
    } catch (e) {
      logger.error(`[加载更多失败] 错误详情: ${JSON.stringify(e)}`);
    } finally {
      this.isLoadingMore = false;
    }
  }

  /**
   * 从搜索建议点击或搜索框提交时调用
   * 先判断是否为纯数字 ID，若是则跳转详情；否则执行关键词搜索
   */
  async handleSearchInput(input: string, type: 'illust' | 'user' | 'novel' = 'illust', force = false) {
    const text = input.trim();
    // 存数据库
    const currentMode = appSettings.novel_mode ? 'novel' : 'illust';
    this.getDB().saveOrUpdate(text, currentMode).then(async () => {
      const values = await this.getDB().queryByMode(currentMode)
      this.searchHistory = values
    })
    if (!text) return;
    // 判断是否为纯数字（作品 ID 或用户 ID）
    const isNumber = /^\d+$/.test(text);
    if (isNumber) {
      const id = Number(text);
      const params: DetailPageParams = {
        id,
      };
      if (type == 'illust') {
        // 跳转至插画详情页
        PixState.pageStack.pushPathByName('illust_detail', params, true);
      } else if (type == 'novel') {
        // 跳转至小说详情页
        PixState.pageStack.pushPathByName('illust_detail', params, true);
      } else {
        // 跳转至画师详情页
        PixState.pageStack.pushPathByName('user_detail', params, true);
      }
      return;
    }
    // 非数字，当成关键词搜索
    this.doSearch(force);
  }

  handleIllustClick(illust: PixivIllust) {
    // 判断是否处于真正的插画列表上下文中
    const isIllustContext = this.searchType === 'illust';
    // 计算索引
    const index = isIllustContext ? this.resultIllusts.findIndex(i => i.id === illust.id) : 0;

    const params: DetailPageParams = {
      id: illust.id,
      // 只有在插画上下文才传 Provider，关注页传 undefined！
      swiperProvider: isIllustContext ? this : undefined,
      swiperIndex: index >= 0 ? index : 0,
      // 数据兜底, 如果 illust 对象没有 user 信息，说明是残缺数据，强制置空，让详情页自己拉
      illust: illust.user ? illust : undefined
    };
    // 跳转详情页
    PixState.pageStack.pushPathByName('illust_detail', params, true);
  }

  handleNovelClick(novel: PixivNovel) {
    // TODO: 跳转小说详情
    logger.info(`[handleNovelClick] Clicked novel: ${novel.id}`);
  }

  handleLongPressGesture(item: PixivTrendingTag) {
    // 长按进入详情页
    const params: DetailPageParams = { id: item.illust.id, illust: item.illust };
    PixState.pageStack.pushPathByName('illust_detail', params, true);
  }

  updateSuggestions(input: string) {
    this.showSuggestions = true
    if (this.debounceTimerId !== -1) {
      clearTimeout(this.debounceTimerId);
    }
    if (!input || input.trim().length === 0) {
      this.suggestions = [];
      return;
    }
    this.debounceTimerId = setTimeout(() => {
      const tags = this.trendingTags || [];
      const resultList = generateSuggestions(input.trim(), tags, [
        toastUtil.getResourceString($r('app.string.jump_illusst')),
        toastUtil.getResourceString($r('app.string.jump_user')),
        toastUtil.getResourceString($r('app.string.search'))], appSettings.novel_mode);
      this.suggestions = resultList;
    }, 300);
  }

  clearSearchHistory() {
    toastUtil.showDialog({
      title: $r('app.string.tips'),
      message: $r('app.string.confirm_clear_search_history'),
      buttons: [
        { text: $r('app.string.cancel'), color: '#999999' },
        { text: $r('app.string.clear'), color: '#FF0000' }
      ]
    }, async (err, data) => {
      if (data?.index === 1) {
        // 只清空当前模式的历史
        const currentMode = appSettings.novel_mode ? 'novel' : 'illust';
        await this.getDB().clearAll(currentMode)
        this.searchHistory = []
        this.searchHistoryEdit = false
      }
    });
  }

  async deleteSearch(id: number) {
    await this.getDB().deleteByID(id)
    this.searchHistory = this.searchHistory.filter((item) => item.id != id)
    if (this.searchHistory.length == 0) {
      this.searchHistoryEdit = false
    }
  }

}

export const searchVM = new SearchViewModel();
