import axios, { AxiosInstance } from '@ohos/axios';
import { createLogger } from '../utils/Logger';
import { md5String } from '../utils/MD5';
import { Date2UTCTimeString } from '../utils/TimeUtils';
import { urlQueryString } from '../utils/Url2String';
import { PixivAuthResponse, PixivUser } from './PixivTypes';

const logger = createLogger('PixivAuth')

/**
 * 认证服务类
 * 处理 Pixiv 的登录、Token 刷新、凭证管理
 */
export class PixivAuth {
  // 将 axios 实例设为 public，以便 PixivData 可以复用（因其携带 Authorization Header）
  public axiosInstance: AxiosInstance;
  private accessToken: string = '';
  private refreshToken: string = '';
  private isLoggedIn: boolean = false;
  // 当前登录用户
  private currentUser: PixivUser

  // 用于存储正在进行的刷新 Promise，防止并发刷新
  private refreshingPromise: Promise<PixivAuthResponse> | null = null;

  /**
   * 客户端凭据列表
   * 因为 Pixiv 的官方凭据可能会失效或变动，这里配置了多组，
   * 登录时会按顺序尝试，直到成功或全部失败
   */
  private readonly CREDENTIALS = [
    {
      client_id: 'MOBrBDS8blbauoSck0ZfDbtuzpyT',
      client_secret: 'lsACyCD94FhDUtGTXi3QzcFE2uU1hqtDaKeqrdwj',
      hash_secret: '28c1fdd170a5204386cb1313c7077b34f83e4aaf4aa829ce78c231e05b0bae2c',
    },
    {
      client_id: 'KzEZED7aCQvptjY3VfNH3VSF6o54OtvB',
      client_secret: 'W9J1Y5T4V9tT7o5cC3qM8pT3zF6pC2x',
      hash_secret: '28c1fdd170a5204386cb1313c7077b34f83e4aaf4aa829ce78c231e05b0bae2c',
    }
  ];

  constructor() {
    logger.info('Initializing Auth Service...');
    this.axiosInstance = axios.create({
      baseURL: 'https://app-api.pixiv.net/',
      timeout: 30000,
    });
    logger.info('Axios instance created.');

    // 响应拦截器，处理 401 自动刷新 Token
    this.axiosInstance.interceptors.response.use(
      (response) => {
        // 请求成功，直接返回
        return response;
      },
      async (error) => {
        const originalRequest = error.config;
        //1. 判断错误状态码是否为 401 (未授权)
        //2. 判断 originalRequest 是否存在
        //3. 判断 originalRequest._retry 标记是否存在 (防止死循环)
        if (error.response?.status === 401 && originalRequest && !originalRequest._retry) {
          originalRequest._retry = true; // 标记该请求已重试过，避免无限循环
          // --- 场景 A: 已经有一个刷新请求正在进行 ---
          if (this.refreshingPromise) {
            logger.info('Token refreshing in progress, waiting...');
            try {
              // 等待正在进行的刷新完成
              await this.refreshingPromise;
              // 刷新完成后，重试原请求
              // 注意：this.axiosInstance.defaults.headers.common 已经在 updateTokens 中更新了
              return this.axiosInstance.request(originalRequest);
            } catch (e) {
              // 如果等待的那个刷新失败了，直接抛出错误
              return Promise.reject(e);
            }
          }
          // --- 场景 B: 还没有刷新请求，由当前请求发起刷新 ---
          try {
            logger.info('Access token expired, trying to refresh...');
            // 创建刷新 Promise 并保存，让其他并发请求能看到
            this.refreshingPromise = this.loginWithRefreshToken(this.refreshToken);
            // 执行刷新
            await this.refreshingPromise;
            // 刷新成功，清空 Promise 锁
            this.refreshingPromise = null;
            logger.info('Token refreshed, retrying original request.');
            // 重试原请求
            return this.axiosInstance.request(originalRequest);
          } catch (refreshError) {
            // 刷新失败（如 RefreshToken 也过期了）
            this.refreshingPromise = null; // 清空锁
            logger.error('Refresh token failed, user needs to re-login.');
            // 或者直接调用 this.isLoggedIn = false;
            return Promise.reject(refreshError);
          }
        }

        // 如果不是 401 错误，或者是重试后依然失败，直接抛出
        return Promise.reject(error);
      }
    );
  }

  /**
   * 检查当前是否已登录且 Token 有效
   * @returns 是否已登录
   */
  isLogin(): boolean {
    return this.isLoggedIn && this.accessToken.length > 0;
  }

  /**
   * 使用用户名和密码进行登录 (已废弃)
   * 会遍历 CREDENTIALS 列表，尝试不同的 Client ID 进行登录
   *
   * @param username Pixiv 用户名或邮箱
   * @param password 密码
   * @returns 返回包含 Token 和用户信息的 AuthResponse
   */
  async loginWithPassword(username: string, password: string): Promise<PixivAuthResponse> {
    logger.info('Login with password.');
    const now = new Date();
    const localTime = Date2UTCTimeString(now);

    for (let i = 0; i < this.CREDENTIALS.length; i++) {
      const creds = this.CREDENTIALS[i];
      const hashString = `${localTime}${creds.hash_secret}`;
      const clientHash = await md5String(hashString);

      logger.info(`Trying credentials set ${i + 1}`);

      try {
        const response = await this.retryRequest(() => axios.post(
          'https://oauth.secure.pixiv.net/auth/token',
          urlQueryString({
            client_id: creds.client_id,
            client_secret: creds.client_secret,
            get_secure_url: '1',
            grant_type: 'password',
            username: username,
            password: password,
          }),
          {
            headers: {
              'User-Agent': 'PixivAndroidApp/5.0.234 (Android 11; Pixel 5)',
              'Accept': 'application/json',
              'Content-Type': 'application/x-www-form-urlencoded',
              'X-Client-Time': localTime,
              'X-Client-Hash': clientHash,
              'App-OS': 'android',
              'App-OS-Version': '11.0',
              'App-Version': '5.0.234',
            },
          }
        ), 'Password Login');

        const body: { response: PixivAuthResponse } = response.data;
        const auth = body.response;

        this.updateTokens(auth.access_token, auth.refresh_token);
        logger.info('Password login successful!');
        // 保存用户
        this.currentUser = auth.user;
        return auth;
      } catch (error: any) {
        if (i < this.CREDENTIALS.length - 1) continue;
        throw error;
      }
    }
    throw new Error('所有客户端凭据都无法登录');
  }

  /**
   * 使用 Web OAuth 授权码进行登录
   *
   * @param code 从 WebView 回调 URL 中获取的 code
   * @param codeVerifier PKCE 流程中生成的 code_verifier
   * @returns 返回包含 Token 和用户信息的 AuthResponse
   */
  async loginWithAuthCode(code: string, codeVerifier: string): Promise<PixivAuthResponse> {
    logger.info('Login with auth code.');

    const creds = this.CREDENTIALS[0];
    const now = new Date();
    const localTime = Date2UTCTimeString(now);
    const hashString = `${localTime}${creds.hash_secret}`;
    const clientHash = await md5String(hashString);

    // 使用 retryRequest 包裹请求，增加容错性
    const response = await this.retryRequest(() => axios.post(
      'https://oauth.secure.pixiv.net/auth/token',
      urlQueryString({
        client_id: creds.client_id,
        client_secret: creds.client_secret,
        get_secure_url: '1',
        grant_type: 'authorization_code',
        code: code,
        code_verifier: codeVerifier,
        redirect_uri: 'https://app-api.pixiv.net/web/v1/users/auth/pixiv/callback',
        include_policy: true
      }),
      {
        headers: {
          'User-Agent': 'PixivAndroidApp/5.0.234 (Android 11; Pixel 5)',
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-Client-Time': localTime,
          'X-Client-Hash': clientHash,
          'App-OS': 'android',
          'App-OS-Version': '11.0',
          'App-Version': '5.0.234',
        },
      }
    ), 'Auth Code Login');

    const body: { response: PixivAuthResponse } = response.data;
    const auth = body.response;

    this.updateTokens(auth.access_token, auth.refresh_token);
    // 保存用户 ID
    this.currentUser = auth.user;
    logger.info('Auth code login successful!');
    return auth;
  }

  /**
   * 使用 Refresh Token 进行登录（刷新会话）- 带重试机制
   * 通常用于 App 启动时自动登录，或 Access Token 过期时刷新
   *
   * @param refreshToken 之前保存的 Refresh Token
   * @returns 返回新的 Token 和用户信息
   */
  async loginWithRefreshToken(refreshToken: string): Promise<PixivAuthResponse> {
    logger.info('Login with refresh token.');
    if (!refreshToken) throw new Error('请提供 refresh token');

    const now = new Date();
    const localTime = Date2UTCTimeString(now);
    const hashString = `${localTime}${this.CREDENTIALS[0].hash_secret}`;
    const clientHash = await md5String(hashString);

    // 使用 retryRequest 包裹请求，自动处理网络抖动或 5xx 错误
    const response = await this.retryRequest(() => axios.post(
      'https://oauth.secure.pixiv.net/auth/token',
      urlQueryString({
        client_id: this.CREDENTIALS[0].client_id,
        client_secret: this.CREDENTIALS[0].client_secret,
        get_secure_url: '1',
        grant_type: 'refresh_token',
        refresh_token: refreshToken,
      }),
      {
        headers: {
          'User-Agent': 'PixivAndroidApp/5.0.234 (Android 11; Pixel 5)',
          'Accept': 'application/json',
          'Content-Type': 'application/x-www-form-urlencoded',
          'X-Client-Time': localTime,
          'X-Client-Hash': clientHash,
          'App-OS': 'android',
          'App-OS-Version': '11.0',
          'App-Version': '5.0.234',
        },
      }
    ), 'Refresh Token Login');

    const body: { response: PixivAuthResponse } = response.data;
    const auth = body.response;

    this.updateTokens(auth.access_token, auth.refresh_token);
    // 保存用户 ID
    this.currentUser = auth.user;
    logger.info('Refresh token login successful!');
    return auth;
  }

  /**
   * 获取当前保存的 Refresh Token
   * 用于将 Token 持久化存储到本地
   */
  getCurrentRefreshToken(): string {
    return this.refreshToken;
  }

  /**
   * 获取当前登录用户信息
   */
  getCurrentUser(): PixivUser {
    return this.currentUser;
  }

  /**
   * 内部方法：更新 Token 并配置 Axios
   */
  private updateTokens(access: string, refresh: string) {
    this.accessToken = access;
    this.refreshToken = refresh;
    this.isLoggedIn = true;

    // 更新 axios 实例的默认 header
    this.axiosInstance.defaults.headers.common['Authorization'] = `Bearer ${this.accessToken}`;
    this.axiosInstance.defaults.headers.common['User-Agent'] = 'PixivAndroidApp/5.0.234 (Android 11; Pixel 5)';
    // ⭐ 关键 headers ⭐
    this.axiosInstance.defaults.headers.common['App-OS'] = 'android';
    this.axiosInstance.defaults.headers.common['App-OS-Version'] = '11.0';
    this.axiosInstance.defaults.headers.common['App-Version'] = '5.0.234';
  }

  /**
   * 辅助方法：延迟函数
   * @param ms 毫秒
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * 辅助方法：带重试机制的请求执行器
   *
   * @param requestFn 执行请求的函数
   * @param operationName 操作名称（用于日志）
   * @param maxAttempts 最大重试次数，默认 3
   * @param baseDelay 基础延迟时间，默认 1000ms
   */
  private async retryRequest<T>(
    requestFn: () => Promise<T>,
    operationName: string = 'Request',
    maxAttempts: number = 3,
    baseDelay: number = 1000
  ): Promise<T> {
    let lastError: any;

    for (let attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await requestFn();
      } catch (error: any) {
        lastError = error;
        const isLastAttempt = attempt === maxAttempts;

        // 获取错误状态码
        const status = error?.response?.status;
        // 判断是否为网络错误（没有 response 对象通常意味着断网或超时）
        const isNetworkError = !error.response && error.code;

        let shouldRetry = false;

        // 策略：
        // 1. 网络错误（超时、断网） -> 重试
        // 2. 5xx 服务器错误 -> 重试
        // 3. 4xx 客户端错误（400/401/403） -> 不重试（避免死循环，Token失效就是失效了）
        if (isNetworkError) {
          shouldRetry = true;
        } else if (status && status >= 500) {
          shouldRetry = true;
        } else {
          // 对于 4xx 错误，通常不需要重试，直接抛出
          // 但如果你发现 Pixiv 偶尔会在负载高时返回 400，也可以酌情放宽条件
          shouldRetry = false;
        }

        if (!shouldRetry || isLastAttempt) {
          logger.error(`${operationName} failed finally (attempt ${attempt}/${maxAttempts}).`, error?.message || error);
          throw lastError; // 重试次数用尽 或 不应重试，抛出错误
        }

        // 计算延迟时间：指数退避 (1s, 2s, 4s...)
        const delay = baseDelay * Math.pow(2, attempt - 1);
        logger.warn(`${operationName} failed (attempt ${attempt}/${maxAttempts}), retrying in ${delay}ms...`);
        await this.sleep(delay);
      }
    }

    // 理论上代码走不到这里，因为上面循环一定会 throw 或 return
    throw lastError;
  }
}
