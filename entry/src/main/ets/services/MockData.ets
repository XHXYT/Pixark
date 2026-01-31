import { PixivTrendingTag, PixivIllust, PixivUser, PixivListResult, SpotlightArticle, SpotlightResponse } from './PixivTypes';

/**
 * 模拟 Pixiv 数据的服务类
 * 专门用于 UI 调试，不需要网络请求
 */
export class MockData {

  // 模拟网络延迟，检查 Loading 效果
  private static delay(ms: number = 300): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * 模拟：获取热门标签 (SearchViewModel 用)
   */
  static async getTrendingTags(): Promise<PixivTrendingTag[]> {
    await MockData.delay();

    const tags: string[] = ['原创', '原神', '风景', '女の子', 'R-18', '机甲', '猫', '和风', 'pixiv', '插画'];
    const result: PixivTrendingTag[] = [];

    for (let i = 0; i < 20; i++) {
      const randomTag = tags[Math.floor(Math.random() * tags.length)];
      result.push({
        tag: randomTag + (i + 1), // 防止同名
        translated_name: randomTag + (i + 1),
        illust: {
          id: 1000 + i,
          title: `测试封面图 ${i + 1}`,
          image_urls: {
            square_medium: ''  // 留空，UI 层会自动用占位图
          }
        }
      });
    }
    return result;
  }

  /**
   * 模拟：获取推荐插画 (HomeViewModel 用)
   */
  static async getRecommended(refresh: boolean = false): Promise<PixivListResult> {
    await MockData.delay();
    const illusts: PixivIllust[] = [];

    for (let i = 0; i < 20; i++) {
      illusts.push({
        id: 2000 + i,
        title: `推荐插画 ${i + 1}`,
        type: 'illust',
        caption: '这是测试用的描述文案...',
        user: {
          id: 3000 + i,
          name: `测试画师 ${i + 1}`,
          account: 'test_account',
          profile_image_urls: { medium: '' },
          is_followed: i % 3 === 0 // 模拟部分已关注
        },
        image_urls: {
          large: '',
          medium: '',
          square_medium: '',
          original: ''
        },
        tags: [],
        tools: ['SAI', 'Photoshop'],
        create_date: new Date().toISOString(),
        width: 800,
        height: 1200,
        total_view: Math.floor(Math.random() * 10000),
        total_bookmarks: Math.floor(Math.random() * 1000),
        is_bookmarked: i % 5 === 0 // 模拟部分已收藏
      });
    }

    return {
      illusts: illusts,
      next_url: refresh ? 'has_next_page_mock_url' : null // 模拟分页
    };
  }

  /**
   * 模拟：获取亮点文章 (HomeViewModel 用)
   */
  static async getSpotlight(): Promise<SpotlightResponse> {
    await MockData.delay();

    const articles: SpotlightArticle[] = [];
    for (let i = 0; i < 5; i++) {
      articles.push({
        id: 4000 + i,
        title: `第 ${i + 1} 期 Pixiv 亮点文章`,
        pure_title: `第 ${i + 1} 期 Pixiv 亮点文章`,
        thumbnail: 'https:example.com', // 占位图
        article_url: 'https://pixiv.net',
        publish_date: new Date().toISOString(),
        category: 'all',
        author_name: 'Pixiv官方',
        main_image: ''
      });
    }

    return {
      spotlight_articles: articles,
      next_url: ''
    };
  }
}
