import { _PixState } from "../../entryability/AppState";
import { appSettings } from "../entity/SettingsModel";
import { createLogger } from "./Logger";
import { i18n } from "@kit.LocalizationKit";

const logger = createLogger('SettingsUtils')


export class SettingsUtils {

  /**
   * 设置颜色模式
   */
  static setColorMode() {
    try {
      logger.info('ColorMode', `保存的颜色模式：${appSettings.color_mode}`);
      _PixState.Context.getApplicationContext().setColorMode(appSettings.color_mode);
    } catch (err) {
      logger.error(`ColorMode`, `Failed to set colorMode, ${err}`)
    }
  }

  /**
   * 设置语言
   */
  static setLanguage() {
    try {
      i18n.System.setAppPreferredLanguage(appSettings.language)
    } catch (error) {
      // TODO: Implement error handling.
    }
  }

}