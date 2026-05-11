/**
 * Pixiv 认证响应接口
 * 定义了登录或刷新 Token 成功后，服务器返回的数据结构
 */
export interface PixivAuthResponse {
  access_token: string;       // 访问令牌，用于后续 API 请求的身份验证
  refresh_token: string;      // 刷新令牌，用于当 access_token 过期时获取新的令牌
  expires_in: number;         // access_token 的过期时间（秒）
  token_type: string;         // 令牌类型，通常是 "Bearer"
  scope: string;              // 令牌的授权范围
  user: PixivUser;
}

/**
 * Pixiv 用户/画师信息
 * 定义了画师的基本信息
 */
export interface PixivUser {
  /** 用户 ID */
  id: number;
  /** 用户昵称 (画师名) */
  name: string;
  /** 个人简介/留言 */
  comment: string;
  /** 创建时间 */
  created_date: string;
  /** 用户账号 ID (登录用的账号，通常不展示) */
  account: string;
  /** 当前用户是否已关注该画师 */
  is_followed: boolean;
  /** 用户头像 URL 列表 */
  profile_image_urls: {
    /** 头像中图 URL */
    medium: string;
  };
  // 邮箱 仅在登录时返回的User中存在
  mail_address?: string;
  // 是否高级会员
  is_premium?: boolean;
  // R18/敏感设置（0: 全年龄, 1: R18, 2: R18G）
  x_restrict?: number;
  // 是否接受邮件通知
  mail_address_is_verified?: boolean;
}

/**
 * Pixiv 插画作品接口
 * 定义了单个插画作品的详细信息
 */
export interface PixivIllust {
  id: number;                 // 作品 ID
  title: string;              // 作品标题
  type: string;               // 作品类型 (例如: illust, manga)
  caption: string;            // 作品描述/简介
  user: PixivUser;
  image_urls: PixivImage;
  tags: Array<PixivTag>;      // 作品标签列表
  tools: string[];            // 使用的绘图工具 (如 SAI, Photoshop)
  create_date: string;        // 创建时间
  width: number;              // 图片宽度
  height: number;             // 图片高度
  total_view: number;         // 总浏览量
  total_bookmarks: number;    // 总收藏数

  // 仅在收藏接口返回的作品里存在：
  bookmark_id?: number;       // 标记该作品在用户收藏列表中的 ID，用于分页
  is_bookmarked: boolean;     // 该插画是否被当前登录用户收藏

  meta_single_page?: {
    original_image_url?: string;
  };

  /**
   * 多图页面数据
   * 注意：只有当 meta_pages.length > 1 时，或者详情页接口返回的数据里，才会有此字段
   * 列表接口通常为了省流量不返回此字段
   *
   * 结构说明：
   * meta_pages 是一个数组，每个元素代表一页。
   */
  meta_pages?: Array<{ image_urls: PixivImage }>;
}

export interface PixivImage {
  large: string;            // 大图 URL
  medium: string;           // 中图 URL
  square_medium: string;    // 方形中图 URL (常用于列表封面)
  original?: string;        // 原图，一般存在于详情页
}

// 标签接口
export interface PixivTag {
  name: string;
  translated_name?: string | null;
}

/**
 * 账号上下文：存储单个账号的所有凭证和状态
 */
export interface AccountContext {
  userId: string;       // Pixiv 用户 ID，作为唯一标识
  accessToken: string;
  refreshToken: string;
  user: PixivUser;
}


/**
 * 用户预览（用于 /v1/search/user）
 * 包含用户信息 + 若干预览作品
 */
export type UserPreview = {
  user: PixivUser;
  illusts: PixivIllust[];
  novels?: any[]; // 小说，预留
};

/**
 * 用户个人资料
 * 对应 API 返回的 profile 对象
 * 包含背景图、简介、地区、统计数据等详细信息
 */
export interface UserProfile {
  /* ==================== 基础信息 ==================== */
  /** 头像背景图 URL */
  background_image_url: string | null;
  /** 个人主页/网站 URL */
  webpage: string | null;
  /** 性别 (例如: "male", "female") */
  gender: string;
  /** 地区 */
  region: string;

  /* ==================== 生日信息 (可选) ==================== */
  /** 完整生日 (格式: "1996-07-22") */
  birth?: string;
  /** 生日 (格式: "07-22") */
  birth_day?: string;
  /** 生年 (例如: 1996) */
  birth_year?: number;

  /* ==================== 统计数据 (核心) ==================== */
  /** 关注数 (当前用户关注了多少人，即 "关注用户量") */
  total_follow_users: number;
  /** 我的好友数 */
  total_mypixiv_users: number;
  /** 插画作品总数 */
  total_illusts: number;
  /** 漫画作品总数 */
  total_manga: number;
  /** 小说作品总数 */
  total_novels: number;
  /** 公开的插画收藏数 */
  total_illust_bookmarks_public?: number;
  /** 插画系列数 */
  total_illust_series?: number;
  /** 小说系列数 */
  total_novel_series?: number;

  /* ==================== 社交账号 (可选) ==================== */
  /** Twitter 账号名 */
  twitter_account?: string;
  /** Twitter 主页 URL */
  twitter_url?: string | null;
  /** Pawoo (关联的 Mastodon 实例) URL */
  pawoo_url?: string | null;

  /* ==================== 账号状态 (可选) ==================== */
  /** 是否为高级会员 */
  is_premium?: boolean;
  /** 是否使用了自定义头像 */
  is_using_custom_profile_image?: boolean;
  /** 工作ID (内部字段) */
  job_id?: number;
  /** 工作名称 */
  job?: string;
}

/**
 * 用户工作区
 * 对应 API 返回的 workspace 对象
 * 存储了画师的电脑配置、使用的软件、外设等信息
 */
export interface UserWorkspace {
  /** PC 机型描述 */
  pc: string;
  /** 显示器描述 */
  monitor: string;
  /** 绘图软件/工具 (例如: "SAI", "Photoshop") */
  tool: string;
  /** 扫描仪型号 */
  scanner: string;
  /** 数位板/平板型号 */
  tablet: string;
  /** 鼠标型号 */
  mouse: string;
  /** 打印机型号 */
  printer: string;
  /** 桌面/机箱描述 */
  desktop: string;
  /** 常听音乐 */
  music: string;
  /** 书桌描述 */
  desk: string;
  /** 椅子型号 */
  chair: string;
  /** 工作区备注 */
  comment: string;
  /** 工作区图片 URL */
  workspace_image_url?: any;
}


/**
 * 用户隐私/公开设置
 * 决定了用户的哪些信息对其他人可见
 */
export interface ProfilePublicity {
  /** 性别是否公开 ('public' | 'private') */
  gender: string;
  /** 地区是否公开 ('public' | 'private') */
  region: string;
  /** 生日(日)是否公开 ('public' | 'private') */
  birth_day: string;
  /** 生日(年)是否公开 ('public' | 'private') */
  birth_year: string;
  /** 职业是否公开 ('public' | 'private') */
  job: string;
  /** Pawoo (关联服务) 是否关联/可见 */
  pawoo: boolean;
}


/**
 * Pixiv 热门标签
 * 对应 /v1/trending-tags/illust 接口返回的单个标签对象
 */
export interface PixivTrendingTag {
  /** 标签名 */
  tag: string;
  /** 标签翻译名（中文/英文等，取决于请求头或 API 返回） */
  translated_name?: string | null;
  /** 该标签下的关联插画（用作封面展示） */
  illust: PixivIllust;
}


/**
 * Pixiv 亮点/专题文章
 * 对应 /v1/spotlight/articles 接口返回的单个文章对象
 */
export interface SpotlightArticle {
  /** 文章唯一 ID */
  id: number;
  /** 文章标题（包含 HTML 转义字符，例如 &amp;） */
  title: string;
  /** 纯净版文章标题（去除 HTML 标签，适合直接展示在 UI 上） */
  pure_title: string;
  /** 文章封面缩略图 URL（通常为正方形，适合轮播图） */
  thumbnail: string;
  /** 文章详情页 URL（需要使用 WebView 组件打开此链接） */
  article_url: string;
  /** 文章发布时间（格式示例：2023-10-01 12:00:00） */
  publish_date: string;
  /** 文章分类（常见值：'all' 全部, 'illust' 插画专题, 'android' 官方精选） */
  category: string;
  /** 文章作者/发布者姓名（例如：'Pixiv官方'） */
  author_name: string;
  /** 文章主图大图 URL（可选字段，尺寸较大） */
  main_image?: string;
}


/**
 * 搜索筛选项
 */
export interface SearchFilterOptions {
  // 基础
  sort?: 'date_desc' | 'date_asc' | 'popular_desc'; // 排序方式：最新、最早、热门

  // 匹配范围
  searchTarget?: 'partial_match_for_tags' | 'exact_match_for_tags' | 'title_and_caption';
  // partial_match_for_tags: 部分标签匹配(默认)
  // exact_match_for_tags: 精确标签匹配
  // title_and_caption: 包含标题和简介

  // 高级筛选
  startDate?: string; // 格式 '2023-01-01'
  endDate?: string;   // 格式 '2023-12-31'
  minBookmark?: number; // 最小收藏数

  // 可选：AI 筛选
  aiType?: 0 | 1 | 2; // 0: 全部, 1: 排除AI, 2: 仅AI
}


/**
 * 搜索用户结果
 * 对应 /v1/search/user 的返回结构
 */
export type SearchUserResult = {
  user_previews: UserPreview[];
  next_url: string | null;
};

/**
 * 热门标签响应
 * 对应 /v1/trending-tags/illust 接口返回的根对象
 */
export interface PixivTrendingTagsResponse {
  /** 热门标签列表 */
  trend_tags: PixivTrendingTag[];
}

/**
 * Pixiv 搜索结果接口
 * 定义了搜索或排行榜等接口返回的列表数据结构
 */
export interface PixivListResult {
  illusts: PixivIllust[];     // 插画作品列表
  next_url: string | null;    // 下一页的 URL，如果为 null 表示没有下一页
}

/**
 * 用户详情响应
 * 包含 user 对象 + profile/workspace/stats 扩展信息
 */
export interface UserDetailResponse {
  /** 用户基础信息 */
  user: PixivUser;
  /** 个人资料 */
  profile: UserProfile;
  /** 工作区信息 */
  workspace: UserWorkspace;
  /** 公开设置 */
  profile_publicity?: ProfilePublicity;
}

/**
 * Pixiv 亮点文章列表响应
 * 对应 /v1/spotlight/articles 接口返回的根对象
 */
export interface SpotlightResponse {
  /** 亮点文章列表 */
  spotlight_articles: SpotlightArticle[];
  /** 下一页的请求 URL（通常首页亮点数量较少，该字段可能为空） */
  next_url: string;
}

