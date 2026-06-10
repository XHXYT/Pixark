import { AppConstants } from "../constants/AppConstants";
import { preferenceUtil } from "../utils/persistence/PreferenceUtil";
import { ConfigurationConstant } from "@kit.AbilityKit";
import { FunctionConstants } from "../constants/FunctionConstants";
import { ReadingTheme } from "./NovelModel";

/**
 * UI 设定类
 */
@ObservedV2
export class _UISettings {
  @Trace language: string = 'zh-CN'
  @Trace main_show: string = '0'
  @Trace reading_color_mode: ReadingTheme = 'sepia'
  @Trace color_mode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET

  constructor() {}

  public async load(): Promise<void> {
    try {
      const jsonStr: string = await preferenceUtil.get<string>(AppConstants.KEY_UI_SETTINGS, "");
      if (!jsonStr) return;
      const json: Record<string, Object> = JSON.parse(jsonStr);

      this.language = (json["language"] as string) ?? this.language;
      this.main_show = (json["main_show"] as string) ?? this.main_show;
      this.color_mode = (json["color_mode"] as number) ?? this.color_mode;
      this.reading_color_mode = (json["reading_color_mode"] as ReadingTheme) ?? this.reading_color_mode;

      console.info("[UISettings] UI配置加载成功");
    } catch (e) {
      console.error("[UISettings] JSON 解析失败，使用默认配置", e);
    }
  }

  @Monitor('language', 'main_show', 'color_mode', 'reading_color_mode')
  public async save(): Promise<void> {
    try {
      const data: Record<string, Object> = {
        "language": this.language,
        "main_show": this.main_show,
        "color_mode": this.color_mode,
        "reading_color_mode": this.reading_color_mode
      };
      const jsonStr: string = JSON.stringify(data);
      await preferenceUtil.put(AppConstants.KEY_UI_SETTINGS, jsonStr);
    } catch (error) {
      console.error("[UISettings] 保存失败:", error);
    }
  }

  public async reset(): Promise<void> {
    try {
      this.language = 'zh-CN';
      this.main_show = '0';
      this.color_mode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
      this.reading_color_mode = 'light'
      this.save();
      console.info("[UISettings] UI配置已恢复默认");
    } catch (error) {
      console.error("[UISettings] 重置失败:", error);
    }
  }

}

export const  UISettings: _UISettings = new _UISettings()

@ObservedV2
export class AppSettings {

  // number类型
  @Trace max_download_count: string = '5'
  @Trace image_preview_quality: string = 'medium'
  @Trace image_detail_quality: string = 'large'
  @Trace image_view_quality: string = 'original'
  @Trace rank_modes: string[] = [] // 排行榜已选项目 (存储 mode 的 key 数组，如 ['day', 'week', 'day_male'])
  @Trace novel_rank_modes: string[] = []
  @Trace file_name: string = FunctionConstants.DEFAULT_SAVE_FORMAT
  @Trace share_text: string = FunctionConstants.DEFAULT_SHARE_FORMAT
  @Trace show_ai_sign: boolean = true
  @Trace show_H: boolean = false
  @Trace private_collecting: boolean = false
  @Trace follow_after_collecting: boolean = false
  @Trace download_after_collecting: boolean = false
  @Trace collecting_when_download: boolean = false
  @Trace swiper_browsing: boolean = true
  @Trace show_thumbnail: boolean = false
  @Trace novel_mode: boolean = false

  constructor() {}

  public async load(): Promise<void> {
    try {
      const jsonStr: string = await preferenceUtil.get<string>(AppConstants.KEY_APP_SETTINGS, "");
      if (!jsonStr) return;
      const json: Record<string, Object> = JSON.parse(jsonStr);

      this.max_download_count = (json["max_download_count"] as string) ?? this.max_download_count;
      this.image_preview_quality = (json["image_preview_quality"] as string) ?? this.image_preview_quality;
      this.image_detail_quality = (json["image_detail_quality"] as string) ?? this.image_detail_quality;
      this.image_view_quality = (json["image_view_quality"] as string) ?? this.image_view_quality;
      this.rank_modes = (json["rank_modes"] as string[]) ?? this.rank_modes;
      this.file_name = (json["file_name"] as string) ?? this.file_name;
      this.share_text = (json["share_text"] as string) ?? this.share_text;
      this.show_ai_sign = (json["show_ai_sign"] as boolean) ?? this.show_ai_sign;
      this.show_H = (json["show_H"] as boolean) ?? this.show_H;
      this.private_collecting = (json["private_collecting"] as boolean) ?? this.private_collecting;
      this.follow_after_collecting = (json["follow_after_collecting"] as boolean) ?? this.follow_after_collecting;
      this.download_after_collecting = (json["download_after_collecting"] as boolean) ?? this.download_after_collecting;
      this.collecting_when_download = (json["collecting_when_download"] as boolean) ?? this.collecting_when_download;
      this.swiper_browsing = (json["swiper_browsing"] as boolean) ?? this.swiper_browsing;
      this.show_thumbnail = (json["show_thumbnail"] as boolean) ?? this.show_thumbnail;
      this.novel_mode = (json["novel_mode"] as boolean) ?? this.novel_mode;

      console.info("[AppSettings] App配置加载成功");
    } catch (e) {
      console.error("[AppSettings] JSON 解析失败，使用默认配置", e);
    }
  }

  @Monitor('swiper_browsing', 'show_thumbnail', 'rank_modes', 'novel_mode')
  public async save(): Promise<void> {
    try {
      const data: Record<string, Object> = {
        "max_download_count": this.max_download_count,
        "image_preview_quality": this.image_preview_quality,
        "image_detail_quality": this.image_detail_quality,
        "image_view_quality": this.image_view_quality,
        "rank_modes": this.rank_modes,
        "file_name": this.file_name,
        "share_text": this.share_text,
        "show_ai_sign": this.show_ai_sign,
        "show_H": this.show_H,
        "private_collecting": this.private_collecting,
        "follow_after_collecting": this.follow_after_collecting,
        "download_after_collecting": this.download_after_collecting,
        "collecting_when_download": this.collecting_when_download,
        "swiper_browsing": this.swiper_browsing,
        "show_thumbnail": this.show_thumbnail,
        "novel_mode": this.novel_mode
      };
      const jsonStr: string = JSON.stringify(data);
      await preferenceUtil.put(AppConstants.KEY_APP_SETTINGS, jsonStr);
    } catch (error) {
      console.error("[AppSettings] 保存失败:", error);
    }
  }

  public async reset(): Promise<void> {
    try {
      // 重置 App 配置
      this.max_download_count = '5';
      this.image_preview_quality = 'medium';
      this.image_detail_quality = 'large';
      this.image_view_quality = 'original';
      this.rank_modes = []
      this.file_name = FunctionConstants.DEFAULT_SAVE_FORMAT;
      this.share_text = FunctionConstants.DEFAULT_SHARE_FORMAT;
      this.show_ai_sign = true;
      this.show_H = false;
      this.private_collecting = false
      this.follow_after_collecting = false;
      this.download_after_collecting = false;
      this.collecting_when_download = false;
      this.swiper_browsing = true;
      this.show_thumbnail = false;
      this.novel_mode = false

      this.save()
      console.info("[AppSettings] App配置已恢复默认");
    } catch (error) {
      console.error("[AppSettings] 重置失败:", error);
    }
  }

}

export const appSettings: AppSettings = new AppSettings()
