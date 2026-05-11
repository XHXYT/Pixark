
/** URL 编码的表单序列化 */
export function urlQueryString(obj: Record<string, string | number | boolean>): string {
  return Object.keys(obj)
    .map(
      key =>
      `${encodeURIComponent(key)}=${encodeURIComponent(String(obj[key]))}`
    )
    .join('&');
}