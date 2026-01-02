export interface IHttpAdapter {
  /**
   * 发起 POST 请求
   * @param url 请求地址（可能已经被重写为 IP）
   * @param data 请求体字符串（通常经过 urlQueryString 处理）
   * @param headers 请求头对象
   */
  post(url: string, data: string, headers: Record<string, string>): Promise<any>;
}