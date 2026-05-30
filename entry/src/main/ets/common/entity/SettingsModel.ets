import { AppConstants } from "../constants/AppConstants";
import { preferenceUtil } from "../utils/persistence/PreferenceUtil";
import { ConfigurationConstant } from "@kit.AbilityKit";
import { FunctionConstants } from "../constants/FunctionConstants";

@ObservedV2
export class AppSettings {

  @Trace language: string = 'zh-CN'
  @Trace main_show: string = '0'
  @Trace color_mode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET // number类型

  @Trace max_download_count: string = '5'
  @Trace image_preview_quality: string = 'medium'
  @Trace image_detail_quality: string = 'large'
  @Trace image_view_quality: string = 'original'
  @Trace rank_modes: string[] = []  // 排行榜已选项目 (存储 mode 的 key 数组，如 ['day', 'week', 'day_male'])
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

  constructor() {}

  /**
   * 加载逻辑
   * 使用 ?? 运算符：如果 JSON 里没有这个字段（老版本），就保留类定义里的默认值
   */
  public async load(): Promise<void> {
    try {
      const jsonStr: string = await preferenceUtil.get<string>(AppConstants.KEY_APP_SETTINGS, "");
      if (!jsonStr) return;
      const json: Record<string, Object> = JSON.parse(jsonStr);

      // 基础类型直接赋值
      this.language = (json["language"] as string) ?? this.language;
      this.main_show = (json["main_show"] as string) ?? this.main_show;
      this.color_mode = (json["color_mode"] as number) ?? this.color_mode;

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

      console.info("[AppSettings] 配置加载成功");
    } catch (e) {
      console.error("[AppSettings] JSON 解析失败，使用默认配置", e);
    }
  }

  /**
   * 保存逻辑
   * 避免序列化出类内部不可控的元数据
   */
  @Monitor('swiper_browsing', 'show_thumbnail', 'rank_modes')
  public async save(): Promise<void> {
    try {
      const data: Record<string, Object> = {
        "language": this.language,
        "main_show": this.main_show,
        "color_mode": this.color_mode,
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
        "show_thumbnail": this.show_thumbnail
      };
      const jsonStr: string = JSON.stringify(data);
      await preferenceUtil.put(AppConstants.KEY_APP_SETTINGS, jsonStr);
    } catch (error) {
      console.error("[AppSettings] 保存失败:", error);
    }
  }

  /**
   * 重置配置：恢复默认值并删除磁盘缓存
   */
  public async reset(): Promise<void> {
    try {
      // 手动将内存中的每一项恢复为类定义的默认值
      // （修改 @Trace 变量会自动触发相关 UI 组件刷新）
      this.language = 'zh-CN';
      this.main_show = '0'
      this.color_mode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;

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

      this.save()
      console.info("[AppSettings] 配置已恢复默认");
    } catch (error) {
      console.error("[AppSettings] 重置失败:", error);
    }
  }
}

export const appSettings: AppSettings = new AppSettings()
