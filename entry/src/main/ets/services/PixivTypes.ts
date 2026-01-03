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
  /** 用户账号 ID (登录用的账号，通常不展示) */
  account: string;
  /** 用户头像 URL 列表 */
  profile_image_urls: {
    /** 头像中图 URL */
    medium: string;
  };
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
  image_urls: {               // 图片 URL 列表 (注意：这只是封面或单图，多图需看 meta_pages)
    large: string;            // 大图 URL
    medium: string;           // 中图 URL
    square_medium: string;    // 方形中图 URL (常用于列表封面)
  };
  tags: Array<{ tag: string }>; // 作品标签列表
  tools: string[];            // 使用的绘图工具 (如 SAI, Photoshop)
  created_time: string;       // 创建时间
  width: number;              // 图片宽度
  height: number;             // 图片高度
  total_view: number;         // 总浏览量
  total_bookmarks: number;    // 总收藏数

  // 仅在收藏接口返回的作品里存在：
  bookmark_id?: number;       // 标记该作品在用户收藏列表中的 ID，用于分页
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
 * Pixiv 亮点文章列表响应
 * 对应 /v1/spotlight/articles 接口返回的根对象
 */
export interface SpotlightResponse {
  /** 亮点文章列表 */
  spotlight_articles: SpotlightArticle[];
  /** 下一页的请求 URL（通常首页亮点数量较少，该字段可能为空） */
  next_url: string;
}

