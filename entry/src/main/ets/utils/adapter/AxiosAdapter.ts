import axios from '@ohos/axios';
import { IHttpAdapter } from './HttpAdapter';

export class AxiosAdapter implements IHttpAdapter {
  async post(url: string, data: string, headers: Record<string, string>): Promise<any> {
    try {
      const response = await axios.post(url, data, {
        headers: headers,
        timeout: 10000, // 统一超时设置
      });
      return response.data;
    } catch (e) {
      throw e;
    }
  }
}
