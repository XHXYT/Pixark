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
  user: {                     // 作者信息 / 用户信息
    id: number;               // 用户 ID
    name: string;             // 用户名 (昵称)
    account: string;          // 账号 ID (登录账号)
    profile_image_urls: {     // 用户头像 URL 列表
      medium: string;         // 头像图片地址 (中图)
    };
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
  user: {                     // 作者信息
    id: number;
    name: string;             // 作者昵称
    account: string;          // 作者账号 ID
    profile_image_urls: {
      medium: string;         // 作者头像 URL
    };
  };
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
export interface PixivSearchResult {
  illusts: PixivIllust[];     // 插画作品列表
  next_url: string | null;    // 下一页的 URL，如果为 null 表示没有下一页
}
