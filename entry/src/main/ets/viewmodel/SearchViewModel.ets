import { PixState } from '../entryability/AppState';
import { MockData } from '../services/MockData';
import { PixivIllust, PixivTrendingTag, SearchFilterOptions, UserPreview } from '../services/PixivTypes';
import { createLogger } from '../utils/Logger';
import { toastUtil } from '../utils/ToastUtils';

const logger = createLogger('SearchViewModel')

@ObservedV2
class SearchViewModel {

  // 推荐标签
  @Trace trendingTags: PixivTrendingTag[] = [];
  // 搜索结果(插画)
  @Trace resultIllusts: PixivIllust[] = []
  // 搜索结果(画师)
  @Trace resultUsers: UserPreview[] = []

  private IllustNextUrl: string = '';
  private userNextUrl: string = '';
  @Trace keyword: string = '';

  @Trace searchType: 'illust' | 'user' = 'illust';

  // 缓存记录：上一次针对该类型搜索的关键词
  private lastSearchedIllustKeyword: string = '';
  private lastSearchedUserKeyword: string = '';

  // 嵌套滚动配置
  get nestedScrollOptions(): NestedScrollOptions {
    return {
      scrollForward: NestedScrollMode.PARENT_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST,
    };
  }

  // 加载推荐标签
  async loadTrendingTags() {
    try {
      if (PixState.isTest) {
        // 调试数据
        this.trendingTags = await MockData.getTrendingTags();
      } else {
        this.trendingTags = await PixState.pixiv.getTrendingTags();
      }
    } catch (e) {
      console.error('加载热门标签失败:', e);
    }
  }

  async doSearch(force: boolean = false) {
    if (!this.keyword) {
      return;
    }
    // 判断是否需要发起请求
    // 如果不是强制刷新(force=false)，且当前关键词和缓存一致，则跳过请求（直接利用历史数据）
    let shouldRequest = true;
    if (!force) {
      if (this.searchType === 'illust') {
        if (this.keyword === this.lastSearchedIllustKeyword) {
          logger.debug(`[doSearch] 缓存命中，跳过插画搜索: ${this.keyword}`);
          shouldRequest = false;
        }
      } else {
        if (this.keyword === this.lastSearchedUserKeyword) {
          logger.debug(`[doSearch] 缓存命中，跳过画师搜索: ${this.keyword}`);
          shouldRequest = false;
        }
      }
    }
    if (!shouldRequest) {
      return;
    }
    logger.debug(`[开始搜索] 类型: ${this.searchType}, 关键词: "${this.keyword}"`);
    try {
      if (this.searchType === 'illust') {
        const data = await PixState.pixiv.searchIllust(this.keyword, undefined, {
          sort: 'popular_desc',
          minBookmark: 1000,
          searchTarget: 'exact_match_for_tags'
        });
        this.resultIllusts = data.illusts;
        this.IllustNextUrl = data.next_url || '';
        // 更新缓存
        this.lastSearchedIllustKeyword = this.keyword;
      } else {
        const data = await PixState.pixiv.searchUser(this.keyword);
        this.resultUsers = data.user_previews;
        this.userNextUrl = data.next_url || '';
        // 更新缓存
        this.lastSearchedUserKeyword = this.keyword;
      }
    } catch (e) {
      logger.error(`[搜索异常] ${JSON.stringify(e)}`);
    }
  }


  // 加载更多
  async loadMoreSearchResult() {
    const nextUrl = this.searchType === 'illust' ? this.IllustNextUrl : this.userNextUrl;
    if (!nextUrl && this.resultIllusts.length > 0 && this.resultUsers.length > 0) {
      toastUtil.showToast({ message: $r('app.string.search_not_tips') });
      return;
    }
    try {
      if (this.searchType === 'illust') {
        const data = await PixState.pixiv.searchIllust('', nextUrl);
        this.resultIllusts.push(...data.illusts);
        this.IllustNextUrl = data.next_url || '';
      } else {
        const data = await PixState.pixiv.searchUser('', nextUrl);
        this.resultUsers.push(...data.user_previews);
        this.userNextUrl = data.next_url || '';
      }
    } catch (e) {
      logger.error(`[加载更多失败] 错误详情: ${JSON.stringify(e)}`);
    }
  }

}

export const searchVM = new SearchViewModel();
