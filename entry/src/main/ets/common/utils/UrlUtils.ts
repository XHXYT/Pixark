/**
 * URL 处理工具类
 * 提供统一的 URL 编码、解码和拼接方法
 */
export class UrlUtils {
  /**
   * URL 编码的表单序列化 (增强版)
   * 自动过滤掉值为 undefined 或 null 的键值对，避免将 "undefined" 发给后端
   * @param obj 键值对对象
   * @returns 编码后的字符串 (如: key1=value1&key2=value2)
   */
  static encodeQuery(obj: Record<string, Object | string | number | boolean | undefined | null>): string {
    const keys: string[] = Object.keys(obj);
    const parts: string[] = [];

    for (let i = 0; i < keys.length; i++) {
      const key: string = keys[i];
      const value: Object | string | number | boolean | undefined | null = obj[key];

      // 过滤掉 undefined 和 null
      if (value !== undefined && value !== null) {
        parts.push(`${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`);
      }
    }

    return parts.join('&');
  }

  /**
   * 解析 URL 查询字符串为对象
   * @param queryString 例如 "?a=1&b=2" 或 "a=1&b=2"
   * @returns 键值对对象
   */
  static decodeQuery(queryString: string): Record<string, string> {
    const result: Record<string, string> = {};
    if (!queryString) return result;

    // 去除开头的 ?
    const str: string = queryString.startsWith('?') ? queryString.substring(1) : queryString;
    const pairs: string[] = str.split('&');

    for (let i = 0; i < pairs.length; i++) {
      const pair: string = pairs[i];
      if (!pair) continue;

      const eqIndex: number = pair.indexOf('=');
      if (eqIndex === -1) {
        result[decodeURIComponent(pair)] = '';
      } else {
        const key: string = pair.substring(0, eqIndex);
        const value: string = pair.substring(eqIndex + 1);
        result[decodeURIComponent(key)] = decodeURIComponent(value);
      }
    }

    return result;
  }

  /**
   * 拼接 URL 和查询参数
   * @param baseUrl 基础 URL
   * @param params 查询参数对象
   * @returns 完整的 URL (如: https://api.com?a=1&b=2)
   */
  static buildUrl(baseUrl: string, params: Record<string, Object | string | number | boolean | undefined | null>): string {
    const query: string = UrlUtils.encodeQuery(params);
    if (!query) return baseUrl;

    // 判断原 URL 是否已经包含参数
    const separator: string = baseUrl.includes('?') ? '&' : '?';
    return `${baseUrl}${separator}${query}`;
  }

}
