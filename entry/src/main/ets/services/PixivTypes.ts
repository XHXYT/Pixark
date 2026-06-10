/**
 * Pixiv 认证响应接口
 * 定义了登录或刷新 Token 成功后，服务器返回的数据结构
 */
export interface PixivAuthResponse {
  access_token: string;
  refresh_token: string;
  expires_in: number;
  token_type: string;
  scope: string;
  user: PixivUser;
}

/**
 * Pixiv 用户/画师信息
 */
export interface PixivUser {
  id: number;
  name: string;
  comment: string;
  created_date: string;
  account: string;
  is_followed: boolean;
  profile_image_urls: {
    medium: string;
  };
  mail_address?: string;
  is_premium?: boolean;
  x_restrict?: number;
  mail_address_is_verified?: boolean;
}

/**
 * Pixiv 插画作品接口
 */
export interface PixivIllust {
  id: number;
  title: string;
  type: string;
  caption: string;
  user: PixivUser;
  image_urls: PixivImage;
  tags: Array<PixivTag>;
  tools: string[];
  create_date: string;
  width: number;
  height: number;
  total_view: number;
  total_bookmarks: number;
  bookmark_id?: number;
  is_bookmarked: boolean;
  illust_ai_type?: number;
  meta_single_page?: {
    original_image_url?: string;
  };
  meta_pages?: Array<{
    image_urls: PixivImage;
  }>;
  /** 系列ID，如果属于某个系列 */
  series?: {
    id: number;
    title: string;
  } | null;
  /** 页数 */
  page_count: number;
  /** 是否为原创 */
  is_original?: boolean;
  /** 总评论数 */
  total_comments?: number;
  visible?: boolean;
  is_muted?: boolean;
  is_mypixiv_only?: boolean;
  is_x_restricted?: boolean;
  restrict?: number;
  x_restrict?: number;
  /** 评论区贴图信息 */
  comment_access_control?: number;
}

export interface PixivImage {
  large: string;
  medium: string;
  square_medium: string;
  original?: string;
}

export interface PixivTag {
  name: string;
  translated_name?: string | null;
}

/** 评论中的用户信息（精简版） */
export interface PixivCommentUser {
  id: number;
  name: string;
  account: string;
  profile_image_urls: {
    medium: string;
  };
}

/** 单条评论结构 */
export interface PixivComment {
  id: number;
  comment: string;
  date: string;
  user: PixivCommentUser;
  stamp: {
    stamp_id: number;
    stamp_url: string;
  } | null;
  parent_comment: {
    id: number;
    comment: string;
    user: PixivCommentUser;
  } | null;
  has_replies?: boolean;
  replies?: PixivComment[];
  repliesNextUrl?: string | null;
  isLoadingReplies?: boolean;
}

/** 小说数据结构  */
export interface PixivNovel {
  id: number;
  title: string;
  caption: string;
  restrict: number;
  x_restrict: number;
  is_original: boolean;
  image_urls: {
    square_medium: string;
    medium: string;
    large: string;
  };
  create_date: string;
  tags: PixivTag[];
  page_count: number;
  text_length: number;
  user: PixivUser;
  series: {
    id: number;
    title: string;
  } | null;
  is_bookmarked: boolean;
  total_bookmarks: number;
  total_view: number;
  visible: boolean;
  total_comments: number;
  is_muted: boolean;
  is_mypixiv_only: boolean;
  is_x_restricted: boolean;
  /** AI 类型: 0=未标记, 2=AI辅助, 3=AI生成 */
  novel_ai_type: number;
}

/**
 * 账号上下文
 */
export interface AccountContext {
  userId: string;
  accessToken: string;
  refreshToken: string;
  user: PixivUser;
  passWord?: string;
  isMailAuthorized?: number;
}

/** 用户预览 */
export type UserPreview = {
  user: PixivUser;
  illusts: PixivIllust[];
  novels: PixivNovel[];
  is_muted?: boolean;
};

/** 用户个人资料 */
export interface UserProfile {
  background_image_url: string | null;
  webpage: string | null;
  gender: string;
  region: string;
  birth?: string;
  birth_day?: string;
  birth_year?: number;
  total_follow_users: number;
  total_mypixiv_users: number;
  total_illusts: number;
  total_manga: number;
  total_novels: number;
  total_illust_bookmarks_public?: number;
  total_illust_series?: number;
  total_novel_series?: number;
  twitter_account?: string;
  twitter_url?: string | null;
  pawoo_url?: string | null;
  is_premium?: boolean;
  is_using_custom_profile_image?: boolean;
  job_id?: number;
  job?: string;
}

/** 用户工作区 */
export interface UserWorkspace {
  pc: string;
  monitor: string;
  tool: string;
  scanner: string;
  tablet: string;
  mouse: string;
  printer: string;
  desktop: string;
  music: string;
  desk: string;
  chair: string;
  comment: string;
  workspace_image_url?: string;
}

/** 用户隐私/公开设置 */
export interface ProfilePublicity {
  gender: string;
  region: string;
  birth_day: string;
  birth_year: string;
  job: string;
  pawoo: boolean;
}

/** 热门标签 */
export interface PixivTrendingTag {
  tag: string;
  translated_name?: string | null;
  illust: PixivIllust;
}

/** 亮点/专题文章 */
export interface SpotlightArticle {
  id: number;
  title: string;
  pure_title: string;
  thumbnail: string;
  article_url: string;
  publish_date: string;
  category: string;
  author_name: string;
  main_image?: string;
}

/** 搜索筛选项 */
export interface SearchFilterOptions {
  sort?: 'date_desc' | 'date_asc' | 'popular_desc';
  searchTarget?: 'partial_match_for_tags' | 'exact_match_for_tags' | 'title_and_caption';
  startDate?: string;
  endDate?: string;
  minBookmark?: number;
  maxBookmark?: number;
  aiType?: 0 | 1 | 2;
}

/** 搜索用户结果 */
export type SearchUserResult = {
  user_previews: UserPreview[];
  next_url: string | null;
};

/** 热门标签响应 */
export interface PixivTrendingTagsResponse {
  trend_tags: PixivTrendingTag[];
}

/** 通用列表结果（插画或小说） */
export interface PixivListResult {
  illusts?: PixivIllust[];
  novels?: PixivNovel[];
  next_url: string | null;
}

/** 用户详情响应 */
export interface UserDetailResponse {
  user: PixivUser;
  profile: UserProfile;
  workspace: UserWorkspace;
  profile_publicity?: ProfilePublicity;
}

/** 亮点文章列表响应 */
export interface SpotlightResponse {
  spotlight_articles: SpotlightArticle[];
  next_url: string | null;
}

/** 评论列表响应 */
export interface PixivCommentsResponse {
  comments: PixivComment[];
  next_url: string | null;
}

/**
 * 小说文本响应 — 对应 Dart NovelTextResponse
 * 接口 /v1/novel/text
 */
export interface NovelTextResponse {
  /** 小说标记（阅读进度标记） */
  novel_marker: NovelMarker;
  /** 小说正文纯文本 */
  novel_text: string;
  /** 系列中上一篇小说 */
  series_prev: TextNovel | null;
  /** 系列中下一篇小说 */
  series_next: TextNovel | null;
}

/** 小说标记 — 对应 Dart NovelMarker */
export interface NovelMarker {
  /** 标记所在页码 */
  page: number | null;
}

/** 系列中的简略小说信息 — 对应 Dart TextNovel */
export interface TextNovel {
  id: number | null;
  title: string | null;
}

/**
 * 接口 /webview/v2/novel
 * 包含小说完整内容、插图、系列导航等
 */
export interface NovelWebResponse {
  id: string;
  title: string;
  /** 系列ID，可能为 null 或字符串 */
  seriesId: string | null;
  /** 系列标题 */
  seriesTitle: string | null;
  /** 是否已关注该系列 */
  seriesIsWatched: boolean | null;
  userId: string;
  coverUrl: string;
  tags: string[];
  caption: string;
  cdate: string;
  rating: NovelRating;
  /** 小说正文的HTML格式文本 */
  text: string;
  /** 标记信息 */
  marker: unknown;
  /** 系列导航（上一篇/下一篇） */
  seriesNavigation: SeriesNavigation | null;
  glossaryItems: unknown[] | null;
  replaceableItemIds: unknown[] | null;
  /** 小说中嵌入的图片，key 为图片在文中的标识 */
  images: Record<string, NovelImage> | null;
  /** 小说中嵌入的插画作品，key 为插画ID */
  illusts: Record<string, NovelIllusts | null> | null;
  /** AI 类型 */
  aiType: number | null;
  /** 是否原创 */
  isOriginal: boolean | null;
}

/** 小说评分 — 对应 Dart NovelRating */
export interface NovelRating {
  like: number;
  bookmark: number;
  view: number;
}

/** 系列导航 — 对应 Dart SeriesNavigation */
export interface SeriesNavigation {
  nextNovel: PrevNovel | null;
  prevNovel: PrevNovel | null;
}

/** 系列中的前/后一篇小说 — 对应 Dart PrevNovel */
export interface PrevNovel {
  id: number;
  viewable: boolean;
  contentOrder: string;
  title: string;
  coverUrl: string;
}

/** 小说嵌入图片 — 对应 Dart NovelImage */
export interface NovelImage {
  novelImageId: string | null;
  sl: string;
  urls: NovelUrls;
}

/** 小说嵌入图片URL — 对应 Dart NovelUrls */
export interface NovelUrls {
  '240mw': string | null;
  '480mw': string | null;
  '1200x1200': string | null;
  '128x128': string | null;
  original: string | null;
}

/** 小说嵌入插画 — 对应 Dart NovelIllusts */
export interface NovelIllusts {
  illust: NovelIllust;
}

/** 小说嵌入插画详情 — 对应 Dart NovelIllust */
export interface NovelIllust {
  images: NovelIllustImages;
}

/** 小说嵌入插画图片URL — 对应 Dart NovelIllustImages */
export interface NovelIllustImages {
  small: string | null;
  medium: string | null;
  original: string | null;
}

/**
 * 小说系列详情响应 — 对应 Dart NovelSeriesResponse
 * 接口 /v2/novel/series
 */
export interface NovelSeriesResponse {
  /** 系列详细信息 */
  novel_series_detail: NovelSeriesDetail;
  /** 系列中的第一部小说 */
  novel_series_first_novel: NovelSeriesFirstNovel;
  /** 系列中的最新一部小说 */
  novel_series_latest_novel: NovelSeriesFirstNovel | null;
  /** 系列中的小说列表 */
  novels: PixivNovel[];
  /** 下一页URL */
  next_url: string | null;
}

/** 小说系列详情 — 对应 Dart NovelSeriesDetail */
export interface NovelSeriesDetail {
  id: number;
  title: string;
  caption: string | null;
  is_original: boolean;
  /** 系列是否已完结 */
  is_concluded: boolean;
  /** 系列中作品数量 */
  content_count: number;
  /** 系列总字数 */
  total_character_count: number;
  user: SeriesDetailUser;
  display_text: string;
  novel_ai_type: number;
  /** 当前用户是否已将此系列加入关注列表 */
  watchlist_added: boolean | null;
}

/** 系列详情中的用户 — 对应 Dart NovelSeriesUser (novel_series_detail.dart) */
export interface SeriesDetailUser {
  id: number;
  name: string;
  account: string;
  profile_image_urls: {
    medium: string;
  };
  is_followed: boolean;
  is_access_blocking_user: boolean;
}

/** 系列中第一/最新小说 — 对应 Dart NovelSeriesFirstNovel */
export interface NovelSeriesFirstNovel {
  id: number;
  title: string;
  caption: string;
  restrict: number;
  x_restrict: number;
  is_original: boolean;
  image_urls: {
    square_medium: string;
    medium: string;
    large: string;
  };
  create_date: string;
  tags: NovelSeriesNovelTag[];
  page_count: number;
  text_length: number;
  user: SeriesDetailUser;
  series: NovelSeriesSeries;
  is_bookmarked: boolean;
  total_bookmarks: number;
  total_view: number;
  visible: boolean;
  total_comments: number;
  is_muted: boolean | null;
  is_mypixiv_only: boolean | null;
  is_x_restricted: boolean | null;
  novel_ai_type: number;
}

/** 系列中的小说标签 — 对应 Dart NovelSeriesNovelTag */
export interface NovelSeriesNovelTag {
  name: string;
  translated_name: string | null;
  added_by_uploaded_user: boolean;
}

/** 系列基本信息 — 对应 Dart NovelSeriesSeries */
export interface NovelSeriesSeries {
  id: number;
  title: string;
}

/**
 * 小说关注列表响应 — 对应 Dart NovelWatchListModel
 * 接口 /v1/watchlist/novel
 */
export interface NovelWatchListResponse {
  series: WatchListSeriesModel[];
  next_url: string | null;
}

/** 关注列表中的系列模型 — 对应 Dart NovelSeriesModel (watch_list) */
export interface WatchListSeriesModel {
  id: number;
  title: string;
  url: string | null;
  /** 被遮罩的文本（可能用于年龄限制提示） */
  mask_text: string | null;
  /** 已发布的作品数量 */
  published_content_count: number;
  /** 最新发布作品的日期时间 */
  last_published_content_datetime: string;
  /** 最新作品ID */
  latest_content_id: number;
  user: WatchListSeriesUser | null;
}

/** 关注列表系列中的用户 — 对应 Dart NovelSeriesUser (watch_list_model) */
export interface WatchListSeriesUser {
  id: number;
  name: string;
  account: string;
  profile_image_urls: {
    medium: string | null;
  } | null;
  /** 是否接受约稿请求 */
  is_accept_request: boolean;
}

/**
 * 漫画关注列表响应
 * 接口 /v1/watchlist/manga
 * 结构与小说关注列表类似
 */
export interface MangaWatchListResponse {
  series: WatchListSeriesModel[];
  next_url: string | null;
}

/**
 * 插画系列响应
 * 接口 /v1/illust/series
 */
export interface IllustSeriesResponse {
  illust_series_detail: IllustSeriesDetail;
  illust_series_first_illust: IllustSeriesFirstIllust;
  illust_series_latest_illust: IllustSeriesFirstIllust | null;
  illusts: PixivIllust[];
  next_url: string | null;
}

/** 插画系列详情 */
export interface IllustSeriesDetail {
  id: number;
  title: string;
  caption: string | null;
  is_original: boolean;
  is_concluded: boolean;
  content_count: number;
  total_character_count: number;
  user: SeriesDetailUser;
  display_text: string;
  watchlist_added: boolean | null;
}

/** 插画系列中的第一幅插画 */
export interface IllustSeriesFirstIllust {
  id: number;
  title: string;
  caption: string;
  restrict: number;
  x_restrict: number;
  is_original: boolean;
  image_urls: PixivImage;
  create_date: string;
  tags: PixivTag[];
  page_count: number;
  user: SeriesDetailUser;
  series: { id: number; title: string };
  is_bookmarked: boolean;
  total_bookmarks: number;
  total_view: number;
  visible: boolean;
  total_comments: number;
}

/**
 * 插画系列中的插画响应
 * 接口 /v1/illust-series/illust
 */
export interface IllustSeriesIllustResponse {
  illust_series_detail: IllustSeriesDetail;
  illusts: PixivIllust[];
  next_url: string | null;
}

/**
 * Ugoira（动图）元数据 — 对应 Dart UgoiraMetadataResponse
 * 接口 /v1/ugoira/metadata
 */
export interface UgoiraMetadata {
  zip_urls: {
    medium: string;
  };
  frames: Array<{
    file: string;
    delay: number;
  }>;
}

/** Ugoira 元数据完整响应 */
export interface UgoiraMetadataResponse {
  ugoira_metadata: UgoiraMetadata;
}

/**
 * 插画收藏详情 — 对应 Dart IllustBookmarkDetail
 * 接口 /v2/illust/bookmark/detail
 */
export interface IllustBookmarkDetail {
  is_bookmarked: boolean;
  tags: Array<{
    name: string;
    is_registered: boolean;
  }>;
  restrict: 'public' | 'private';
}

/** 插画收藏详情完整响应 */
export interface IllustBookmarkDetailResponse {
  bookmark_detail: IllustBookmarkDetail;
}

/**
 * 收藏标签列表 — 对应 Dart IllustBookmarkTagsResponse
 * 接口 /v1/user/bookmark-tags/illust
 */
export interface BookmarkTag {
  name: string;
  count: number;
}

/** 收藏标签列表完整响应 */
export interface BookmarkTagsResponse {
  bookmark_tags: BookmarkTag[];
  next_url: string | null;
}

/**
 * 用户关注详情 — 对应 Dart FollowDetail
 * 接口 /v1/user/follow/detail
 */
export interface FollowDetail {
  is_followed: boolean;
  restrict: 'public' | 'private';
}

/**
 * 搜索自动补全响应 — 对应 Dart AutoWords
 * 接口 /v2/search/autocomplete
 */
export interface AutoCompleteResponse {
  tags: Array<{
    name: string;
    translated_name?: string | null;
  }>;
}

/**
 * 用户 AI 显示设置响应
 * 接口 /v1/user/ai-show-settings
 */
export interface UserAISettingsResponse {
  show_ai: boolean;
}

/**
 * 用户受限模式设置响应
 * 接口 /v1/user/restricted-mode-settings
 */
export interface UserRestrictedModeResponse {
  is_restricted_mode_enabled: boolean;
}
