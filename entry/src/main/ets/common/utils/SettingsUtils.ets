import { _PixState } from "../../entryability/AppState";
import { appSettings, UISettings } from "../entity/SettingsModel";
import { createLogger } from "./Logger";
import { i18n } from "@kit.LocalizationKit";

const logger = createLogger('SettingsUtils')


export class SettingsUtils {

  /**
   * 设置颜色模式
   */
  static setColorMode() {
    try {
      logger.info('ColorMode', `保存的颜色模式：${UISettings.color_mode}`);
      _PixState.Context.getApplicationContext().setColorMode(UISettings.color_mode);
    } catch (err) {
      logger.error(`ColorMode`, `Failed to set colorMode, ${err}`)
    }
  }

  /**
   * 设置语言
   */
  static setLanguage() {
    try {
      i18n.System.setAppPreferredLanguage(UISettings.language)
    } catch (error) {
      // TODO: Implement error handling.
    }
  }

}