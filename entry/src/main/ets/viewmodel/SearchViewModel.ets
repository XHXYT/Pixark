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
  private IllustNextUrl: string = '';
  // 搜索结果(画师)
  @Trace resultUsers: UserPreview[] = []
  private userNextUrl: string = '';

  keyword: string = '';
  @Trace searchType: 'illust' | 'user' = 'illust';

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

  async doSearch() {
    if (!this.keyword) {
      logger.warn('搜索关键词为空，忽略搜索请求');
      return;
    }
    logger.debug(`[开始搜索] 类型: ${this.searchType}, 关键词: "${this.keyword}"`);
    try {
      if (this.searchType === 'illust') {
        // 搜插画
        // 构建筛选参数 TODO 可选持久化
        const options: SearchFilterOptions = {
          sort: 'popular_desc',      // 热度降序
          minBookmark: 1000,         // 收藏数
          searchTarget: 'exact_match_for_tags' // 匹配标签
        };
        logger.debug(`[插画搜索] 发起请求，筛选参数: ${JSON.stringify(options)}`);
        const data = await PixState.pixiv.searchIllust(this.keyword, undefined, options);
        logger.info(`[插画搜索] 请求成功，结果数量: ${data.illusts.length}, 下一页URL: ${data.next_url ? '存在' : '空'}`);
        this.resultIllusts = data.illusts;
        this.IllustNextUrl = data.next_url || '';
      } else {
        // 搜作者
        logger.debug(`[用户搜索] 发起请求，关键词: "${this.keyword}"`);
        const data = await PixState.pixiv.searchUser(this.keyword);
        logger.debug(`[用户搜索] 请求成功，结果数量: ${data.user_previews.length}`);
        this.resultUsers = data.user_previews;
        this.userNextUrl = data.next_url || '';
      }
    } catch (e) {
      logger.error(`[搜索异常] 错误详情: ${JSON.stringify(e)}`);
    }
  }

  // 加载更多
  async loadMoreSearchResult() {
    const nextUrl = this.searchType === 'illust' ? this.IllustNextUrl : this.userNextUrl;
    if (!nextUrl) {
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
