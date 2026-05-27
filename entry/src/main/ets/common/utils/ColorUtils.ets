

class Color {

  private  context: Context | null = null

  init(context: Context) {
    this.context = context
  }

  /**
   * 获取禁用变灰颜色
   */
  public getUnableColor(color: ResourceColor) {
    return this.getColorWithAlpha(color, 0x33); // 透明度固定为 0x33
  }

  /**
   * 获取指定透明度的颜色值
   * @returns number
   */
  public getColorWithAlpha(color: ResourceColor, alpha: number): number {
    const baseColor = this.getNormalColor(color);
    const clampedAlpha = Math.max(0, Math.min(255, alpha));
    const rgb = baseColor & 0x00FFFFFF;
    return (clampedAlpha << 24) | rgb;
  }

  /**
   * 将十六进制颜色字符串解析为数字
   * @private
   */
  private parseColorString(colorStr: string): number | null {
    if (colorStr.startsWith('#')) {
      const hex = colorStr.slice(1);
      if (hex.length === 8) { // #AARRGGBB
        return parseInt(hex, 16);
      } else if (hex.length === 6) { // #RRGGBB，默认不透明
        return 0xFF000000 | parseInt(hex, 16);
      }
    }
    return null;
  }

  /**
   * 获取指定透明度的颜色值
   * @param color 基础颜色
   * @param alphaPercent 透明度百分比，取值范围 0-100（0为全透明，100为完全不透明）
   * @returns string
   */
  public getColorWithAlphaString(color: ResourceColor, alphaPercent: number): string {
    const baseColor = this.getNormalColor(color);

    // 将百分比限制在 0 - 100 之间
    const clampedPercent = Math.max(0, Math.min(100, alphaPercent));
    // 将百分比 (0-100) 转换为 255 制式 (0-255)，并四舍五入取整
    const alpha255 = Math.round((clampedPercent / 100) * 255);

    // 截取后24位，去掉原本可能存在的透明度
    const rgb = baseColor & 0x00FFFFFF;

    // 拼接成一个新的 32 位颜色数值（Number类型）
    const argbNumber = (alpha255 << 24) | rgb;

    // 转换为十六进制字符串，并补齐8位
    let hexString = argbNumber.toString(16).padStart(8, '0');

    // 加上 # 号前缀，符合标准的颜色字符串格式
    return `#${hexString}`;
  }


  /**
   * 获取一个标准的、未经修改的颜色值
   * @returns number
   */
  private getNormalColor(color: ResourceColor): number {
    if (!this.context) {
      console.error(`颜色工具没有初始化`);
      throw new Error('颜色工具没有初始化');
    }
    if (typeof color === 'number') return color;
    if (typeof color === 'string') {
      const parsed = this.parseColorString(color);
      if (parsed !== null) return parsed;
      throw new Error(`无法解析的颜色字符串: ${color}`);
    }
    // 处理资源对象
    try {
      return this.context.resourceManager.getColorSync(color.id);
    } catch (error) {
      console.error(`getColorSync错误，message: ${error.message}`);
      throw new Error(`getColorSync错误，message: ${error.message}`);
    }
  }

}

export const ColorUtils = new Color()