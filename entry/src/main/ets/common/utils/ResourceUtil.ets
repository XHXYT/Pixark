import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';

/**
 * 资源工具类 (统一管理字符串、颜色资源的解析)
 */
export class _ResourceUtils {
  private context?: common.UIAbilityContext;

  /**
   * 初始化工具类，必须在 初始化 中调用
   * @param context UIAbilityContext
   */
  init(context: common.UIAbilityContext) {
    this.context = context;
  }

  /**
   * 获取检查上下文是否就绪
   */
  private ensureContext(): common.UIAbilityContext {
    if (!this.context) {
      throw new Error('[ResourceUtils] Context 未初始化，请先调用 init() 方法');
    }
    return this.context;
  }

  /**
   * 将 Resource | string | number | undefined 转换为可读的字符串
   * @param resource 资源、字符串、数值
   * @returns 解析后的字符串，失败返回空字符串 ""
   */
  getString(resource: Resource | string | number | undefined): string {
    if (!resource) return '';
    if (typeof resource === 'string') return resource;
    if (typeof resource === 'number') return resource.toString()

    const ctx = this.ensureContext();

    if (!resource.id) return '';
    try {
      return ctx.resourceManager.getStringSync(resource.id);
    } catch (error) {
      console.error(`[ResourceUtils] getStringSync failed, error: ${JSON.stringify(error)}`);
      return '';
    }
  }

  /**
   * 将 ResourceColor 转换为 #AARRGGBB 格式的字符串
   * @param color 颜色资源 (支持 string, number, Resource)
   * @returns #AARRGGBB 格式的颜色字符串，失败返回空字符串 ""
   */
  parseColor(color: ResourceColor): string {
    if (!color) return '';

    const ctx = this.ensureContext();
    let decimal: number = 0;

    if (typeof color === 'string') {
      return color;
    } else if (typeof color === 'number') {
      decimal = color;
    } else if (color.id) {
      try {
        decimal = ctx.resourceManager.getColorSync(color.id);
      } catch (error) {
        const err = error as BusinessError;
        console.error(`[ResourceUtils] getColorSync failed, error code: ${err.code}, message: ${err.message}`);
        return '';
      }
    } else {
      return '';
    }

    // 将十进制颜色值转换为 #AARRGGBB
    const a = (decimal >> 24) & 0xFF;
    const r = (decimal >> 16) & 0xFF;
    const g = (decimal >> 8) & 0xFF;
    const b = decimal & 0xFF;
    const toHex = (c: number) => c.toString(16).padStart(2, '0');

    return `#${toHex(a)}${toHex(r)}${toHex(g)}${toHex(b)}`;
  }
}


export const ResourceUtils = new _ResourceUtils();
