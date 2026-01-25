import { PixState } from '../entryability/AppState';
import { PixivTrendingTag } from '../services/PixivTypes';


@ObservedV2
class SearchViewModel {
  @Trace trendingTags: PixivTrendingTag[] = [];

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
      this.trendingTags = await PixState.pixiv.getTrendingTags();
    } catch (e) {
      console.error('加载热门标签失败:', e);
    }
  }

}

export const searchVM = new SearchViewModel();
