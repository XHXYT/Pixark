import axios, { AxiosInstance } from '@ohos/axios';
import { createLogger } from '../common/utils/Logger';
import { md5String } from '../common/utils/MD5';
import { Date2UTCTimeString } from '../common/utils/TimeUtils';
import { urlQueryString } from '../common/utils/Url2String';
import { AccountContext, PixivAuthResponse, PixivUser } from './PixivTypes';

const logger = createLogger('PixivAuth')


/**
 * 认证服务类
 * 处理 Pixiv 的登录、Token 刷新、凭证管理 (支持多账号)
 */
export class PixivAuth {

  // 将 axios 实例设为 public，以便 PixivData 可以复用（因其携带 Authorization Header）
  public axiosInstance: AxiosInstance;

  // 多账号映射表 (userId -> context)
  private accounts: Map<string, AccountContext> = new Map();
  // 当前激活的账号 ID
  private activeUserId: string | null = null;

  // 用于存储正在进行的刷新 Promise，防止并发刷新
  private refreshingPromise: Promise<AccountContext> | null = null;

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

    // 请求拦截器：动态注入当前激活账号的 Token
    this.axiosInstance.interceptors.request.use((config) => {
      const account = this.getActiveAccount();
      if (account?.accessToken) {
        config.headers.set('Authorization', `Bearer ${account.accessToken}`);
        // 隐式标记：记录这个请求是由哪个账号发出的 (防止切换账号后 401 重试串台)
        config.headers.set('X-Request-UserId', account.userId);
      }
      // 注入其他必须的固定 Header
      config.headers.set('User-Agent', 'PixivAndroidApp/5.0.234 (Android 11; Pixel 5)');
      config.headers.set('App-OS', 'android');
      config.headers.set('App-OS-Version', '11.0');
      config.headers.set('App-Version', '5.0.234');
      return config;
    });

    // 响应拦截器，处理 401 自动刷新 Token
    this.axiosInstance.interceptors.response.use(
      (response) => {
        return response;
      },
      async (error) => {
        const originalRequest = error.config;
        // 1. 判断错误状态码是否为 401 (未授权)
        // 2. 判断 originalRequest 是否存在
        // 3. 判断 originalRequest._retry 标记是否存在 (防止死循环)
        if (error.response?.status === 401 && originalRequest && !originalRequest._retry) {
          originalRequest._retry = true; // 标记该请求已重试过，避免无限循环

          // 提取发起该请求的原始账号 ID
          const requestUserId = originalRequest.headers?.['X-Request-UserId'] as string;
          const currentActiveUserId = this.activeUserId;

          // 边界防御：如果发起请求的账号已经不是当前激活账号，说明用户已经切号了，直接放弃重试
          if (requestUserId && requestUserId !== currentActiveUserId) {
            logger.warn(`Request account ${requestUserId} switched to ${currentActiveUserId}, abort retry.`);
            return Promise.reject(error);
          }

          // --- 场景 A: 已经有一个刷新请求正在进行 ---
          if (this.refreshingPromise) {
            logger.info('Token refreshing in progress, waiting...');
            try {
              // 等待正在进行的刷新完成
              await this.refreshingPromise;
              // 刷新完成后，重试原请求 (拦截器会自动注入新 Token)
              return this.axiosInstance.request(originalRequest);
            } catch (e) {
              // 如果等待的那个刷新失败了，直接抛出错误
              return Promise.reject(e);
            }
          }

          // --- 场景 B: 还没有刷新请求，由当前请求发起刷新 ---
          try {
            logger.info('Access token expired, trying to refresh...');
            const activeAccount = this.getActiveAccount();
            if (!activeAccount) throw new Error("No active account to refresh");

            // 创建刷新 Promise 并保存，让其他并发请求能看到
            this.refreshingPromise = this.loginWithRefreshToken(activeAccount.refreshToken);
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
            return Promise.reject(refreshError);
          }
        }
        // 如果不是 401 错误，或者是重试后依然失败，直接抛出
        return Promise.reject(error);
      }
    );
  }

  // 账号管理模块
  /**
   * 初始化账号数据 (App启动时调用)
   * @param accounts 从持久化DB读取的账号列表
   * @param activeId 上次使用的激活账号ID
   */
  initAccounts(accounts: AccountContext[], activeId?: string) {
    accounts.forEach(acc => this.accounts.set(acc.userId, acc));
    this.activeUserId = activeId || this.accounts.keys().next().value || null;
    logger.info(`Accounts initialized. Count: ${this.accounts.size}, Active: ${this.activeUserId}`);
  }

  /** 切换当前激活账号 */
  switchAccount(userId: string) {
    if (this.accounts.has(userId)) {
      this.activeUserId = userId;
      // 因为用了请求拦截器，这里不需要再改 axios defaults 了！
      logger.info(`Switched to account: ${userId}`);
    } else {
      logger.error(`Account not found: ${userId}`);
    }
  }

  /**
   * 更新指定账号的用户信息 (用于补全头像等)
   */
  updateAccountUser(userId: string, updatedUser: PixivUser) {
    const account = this.accounts.get(userId);
    if (account) {
      // 保留原有的 mail_address (如果新获取的没有)
      const mergedUser = { ...updatedUser, mail_address: updatedUser.mail_address || account.user.mail_address };
      account.user = mergedUser;
      this.accounts.set(userId, account);
    }
  }


  /** 获取当前所有账号列表 (给 UI 画侧滑菜单用) */
  getAllAccounts(): AccountContext[] {
    return Array.from(this.accounts.values());
  }

  /** 登出/移除特定账号 */
  removeAccount(userId: string) {
    this.accounts.delete(userId);
    if (this.activeUserId === userId) {
      // 如果删除的是当前账号，切到列表里第一个，或者置空
      this.activeUserId = this.accounts.keys().next().value || null;
    }
    logger.info(`Account removed: ${userId}`);
  }

  // 状态获取模块

  /** 获取当前激活的账号上下文 */
  getActiveAccount(): AccountContext | undefined {
    if (!this.activeUserId) return undefined;
    return this.accounts.get(this.activeUserId);
  }

  /**
   * 检查当前是否已登录且 Token 有效
   * @returns 是否已登录
   */
  isLogin(): boolean {
    const account = this.getActiveAccount();
    return !!account && account.accessToken.length > 0;
  }

  /**
   * 获取当前登录用户信息
   */
  getCurrentUser(): PixivUser | undefined {
    return this.getActiveAccount()?.user;
  }

  /**
   * 获取当前保存的 Refresh Token
   * 用于将 Token 持久化存储到本地
   */
  getCurrentRefreshToken(): string {
    return this.getActiveAccount()?.refreshToken || '';
  }

  // 登录模块
  /**
   * 使用用户名和密码进行登录 (已废弃)
   * 会遍历 CREDENTIALS 列表，尝试不同的 Client ID 进行登录
   */
  async loginWithPassword(username: string, password: string): Promise<AccountContext> {
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
        logger.info('Password login successful!');
        return this.updateAccountContext(auth.access_token, auth.refresh_token, auth.user);

      } catch (error: any) {
        if (i < this.CREDENTIALS.length - 1) continue;
        throw error;
      }
    }
    throw new Error('所有客户端凭据都无法登录');
  }

  /**
   * 使用 Web OAuth 授权码进行登录
   */
  async loginWithAuthCode(code: string, codeVerifier: string): Promise<AccountContext> {
    logger.info('Login with auth code.');
    const creds = this.CREDENTIALS[0];
    const now = new Date();
    const localTime = Date2UTCTimeString(now);
    const hashString = `${localTime}${creds.hash_secret}`;
    const clientHash = await md5String(hashString);

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
    logger.info('Auth code login successful!');
    return this.updateAccountContext(auth.access_token, auth.refresh_token, auth.user);
  }

  /**
   * 使用 Refresh Token 进行登录（刷新会话）- 带重试机制
   */
  async loginWithRefreshToken(refreshToken: string): Promise<AccountContext> {
    logger.info('Login with refresh token.');
    if (!refreshToken) throw new Error('请提供 refresh token');

    const now = new Date();
    const localTime = Date2UTCTimeString(now);
    const hashString = `${localTime}${this.CREDENTIALS[0].hash_secret}`;
    const clientHash = await md5String(hashString);

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
    logger.info('Refresh token login successful!');
    return this.updateAccountContext(auth.access_token, auth.refresh_token, auth.user);
  }

  /**
   * 内部方法：更新/添加账号上下文，并设为激活状态
   */
  private updateAccountContext(access: string, refresh: string, user: PixivUser): AccountContext {
    const userId = user.id.toString(); // 假设 PixivUser 有 id 字段
    const context: AccountContext = { userId, accessToken: access, refreshToken: refresh, user };

    // 存入或更新映射表
    this.accounts.set(userId, context);
    // 设为当前激活账号
    this.activeUserId = userId;

    logger.info(`Account context updated. Active: ${userId}`);
    return context;
  }

  // 辅助模块
  /**
   * 辅助方法：延迟函数
   * @param ms 毫秒
   */
  private sleep(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  /**
   * 辅助方法：带重试机制的请求执行器
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

        const status = error?.response?.status;
        const isNetworkError = !error.response && error.code;

        let shouldRetry = false;
        if (isNetworkError) {
          shouldRetry = true;
        } else if (status && status >= 500) {
          shouldRetry = true;
        } else {
          shouldRetry = false;
        }

        if (!shouldRetry || isLastAttempt) {
          logger.error(`${operationName} failed finally (attempt ${attempt}/${maxAttempts}).`, error?.message || error);
          throw lastError;
        }

        const delay = baseDelay * Math.pow(2, attempt - 1);
        logger.warn(`${operationName} failed (attempt ${attempt}/${maxAttempts}), retrying in ${delay}ms...`);
        await this.sleep(delay);
      }
    }
    throw lastError;
  }

}
