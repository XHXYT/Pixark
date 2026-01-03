import { createLogger } from "../utils/Logger";
import { preferenceUtil } from "../utils/PreferenceUtil";

const logger = createLogger('SettingManager')

export class PreferenceKey {
  static readonly USER_ID = 'user_id';
  static readonly IS_LOGGED_IN = 'is_logged_in';
  static readonly THEME_COLOR = 'theme_color';
  static readonly FONT_SIZE = 'font_size';
  // ... 其他 Key
}


// 持久化变量管理
export class SettingManager {
  private static instance: SettingManager;

  // 定义运行时状态
  userId: string = '';

  private constructor() {}

  static getInstance(): SettingManager {
    if (!SettingManager.instance) {
      SettingManager.instance = new SettingManager();
    }
    return SettingManager.instance;
  }

  // 初始化：一次性加载所有配置
  async loadAll() {
    try {
      const results = await Promise.all([
        preferenceUtil.get<string>(PreferenceKey.USER_ID, '')
      ]);
      this.userId = results[0];

      logger.info('#loadAll Loaded all settings.');
    } catch (e) {
      logger.error('#loadAll Load failed', e);
    }
  }

  // 更新：使用同步写入内存
  updateToken(userID: string) {
    this.userId = userID;
    preferenceUtil.putSync(PreferenceKey.USER_ID, userID);
  }

  // 持久化：统一保存
  async saveAll() {
    await preferenceUtil.save();
  }
}

export const settingManager = SettingManager.getInstance();
