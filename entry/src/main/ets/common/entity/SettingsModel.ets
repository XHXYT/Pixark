import { AppConstants } from "../constants/AppConstants";
import { preferenceUtil } from "../utils/persistence/PreferenceUtil";
import { ConfigurationConstant } from "@kit.AbilityKit";

@ObservedV2
export class AppSettings {

  @Trace language: string = 'zh-CN'
  @Trace main_show: string = '0'
  @Trace color_mode: ConfigurationConstant.ColorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET // number类型

  @Trace download_sum: string = '5'
  @Trace file_name: string = '{id}{p}_{title}_{name}'
  @Trace show_ai_sign: boolean = true
  @Trace show_H: boolean = false
  @Trace follow_after_collecting: boolean = false
  @Trace download_after_collecting: boolean = false
  @Trace collecting_when_download: boolean = false

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
      this.file_name = (json["file_name"] as string) ?? this.file_name;
      this.show_ai_sign = (json["show_ai_sign"] as boolean) ?? this.show_ai_sign;
      this.show_H = (json["show_H"] as boolean) ?? this.show_H;
      this.follow_after_collecting = (json["follow_after_collecting"] as boolean) ?? this.follow_after_collecting;
      this.download_after_collecting = (json["download_after_collecting"] as boolean) ?? this.download_after_collecting;
      this.collecting_when_download = (json["collecting_when_download"] as boolean) ?? this.collecting_when_download;

      console.info("[AppSettings] 配置加载成功");
    } catch (e) {
      console.error("[AppSettings] JSON 解析失败，使用默认配置", e);
    }
  }

  /**
   * 保存逻辑
   * 避免序列化出类内部不可控的元数据
   */
  public async save(): Promise<void> {
    try {
      const data: Record<string, Object> = {
        "language": this.language,
        "main_show": this.main_show,
        "color_mode": this.color_mode,
        "file_name": this.file_name,
        "show_ai_sign": this.show_ai_sign,
        "show_H": this.show_H,
        "follow_after_collecting": this.follow_after_collecting,
        "download_after_collecting": this.download_after_collecting,
        "collecting_when_download": this.collecting_when_download
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
      this.file_name = '{id}{p}_{title}_{name}';
      this.show_ai_sign = true;
      this.show_H = false;
      this.follow_after_collecting = false;
      this.download_after_collecting = false;
      this.collecting_when_download = false;

      // 删除首选项中持久化的 JSON 字符串
      // await preferenceUtil.delete(AppConstants.KEY_APP_SETTINGS);
      console.info("[AppSettings] 配置已恢复默认");
    } catch (error) {
      console.error("[AppSettings] 重置失败:", error);
    }
  }
}

export const appSettings: AppSettings = new AppSettings()
