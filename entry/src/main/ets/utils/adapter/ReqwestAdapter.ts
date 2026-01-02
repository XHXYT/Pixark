import reqwest from '@kingtous/reqwest';
import { IHttpAdapter } from './HttpAdapter';

export class ReqwestAdapter implements IHttpAdapter {
  async post(url: string, data: string, headers: Record<string, string>): Promise<any> {
    try {
      const resp = await reqwest.request(url, 'POST', {
        ignoreSsl: true, // 跳过 SSL 证书校验
        noProxy: false,   // 是否不走系统代理
        responseType: 'application/json',
        timeout: 10000,

        // Reqwest 支持 body 字符串，直接传入即可
        body: data,

        // 传入 headers
        headers: headers,

        // 证书相关先留空
        caCert: [],
        clientCert: '',
      });

      // Reqwest 返回结构: { statusCode, responseBody, ... }
      return resp.responseBody;
    } catch (e) {
      // 捕获错误并统一抛出，方便上层处理
      throw e;
    }
  }
}
