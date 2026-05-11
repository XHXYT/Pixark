import { AppConstants } from "../constants/AppConstants";
import { preferenceUtil } from "../utils/persistence/PreferenceUtil";


@ObservedV2
export class AppSettings {

  @Trace file_name: string = '{id}{p}_{title}_{name}'

  constructor() {}

  /**
   * 加载逻辑：绝对类型安全
   * 使用 ?? 运算符：如果 JSON 里没有这个字段（老版本），就保留类定义里的默认值
   */
  public async load(): Promise<void> {
    try {
      const jsonStr: string = await preferenceUtil.get<string>(AppConstants.KEY_APP_SETTINGS, "");
      if (!jsonStr) return;

      const json: Record<string, Object> = JSON.parse(jsonStr);

      // 基础类型直接赋值
      this.file_name = (json["file_name"] as string) ?? this.file_name;

      console.info("[AppSettings] 配置加载成功");
    } catch (e) {
      console.error("[AppSettings] JSON 解析失败，使用默认配置", e);
    }
  }

  /**
   * 保存逻辑：不依赖 JSON.stringify(this)
   * 避免序列化出类内部不可控的元数据
   */
  public async save(): Promise<void> {
    try {
      const data: Record<string, Object> = {
        "file_name": this.file_name,

      };
      const jsonStr: string = JSON.stringify(data);
      await preferenceUtil.put(AppConstants.KEY_APP_SETTINGS, jsonStr);
    } catch (error) {
      console.error("[AppSettings] 保存失败:", error);
    }
  }

  /**
   * 清空配置：恢复默认值并删除磁盘缓存
   */
  public async clear(): Promise<void> {
    try {
      // 手动将内存中的每一项恢复为类定义的默认值
      // （修改 @Trace 变量会自动触发相关 UI 组件刷新）
      this.file_name = '{id}{p}_{title}_{name}';

      // 删除首选项中持久化的 JSON 字符串
      await preferenceUtil.delete(AppConstants.KEY_APP_SETTINGS);

      console.info("[AppSettings] 配置已清空并恢复默认");
    } catch (error) {
      console.error("[AppSettings] 清空失败:", error);
    }
  }

}

export const appSettings: AppSettings = new AppSettings()