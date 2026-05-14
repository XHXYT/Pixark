
// 定义构造参数接口
export interface CustomItemInfoParam {
  id: string;
  icon?: ResourceStr;
  symbol?: Resource;
  iconColor?: ResourceColor;
  label?: ResourceStr;
  subtitle?: ResourceStr;
  type: ItemActionType;
  value?: string | boolean | number;
  enabled?: boolean;
  isDanger?: boolean;
  dialogConfig?: DialogConfig;
  sliderConfig?: SliderConfig;
  radioConfig?: RadioConfig;
  menuOptions?: Array<MenuOption>;
  onChange?: (value: string | boolean | number) => void;
  menuDisabled?: (item: MenuOption, index: number) => boolean;
}

/**
 * 自定义列表项信息
 */
@ObservedV2
export class CustomItemInfo {
  // 基础信息
  @Trace id: string = ''; // 唯一标识
  @Trace icon: ResourceStr | undefined = undefined; // 图标
  @Trace symbol: Resource | undefined = undefined;
  @Trace iconColor: ResourceColor = $r('sys.color.ohos_id_color_primary'); // 图标颜色
  @Trace label: ResourceStr = ''; // 主标题
  @Trace subtitle: ResourceStr = ''; // 副标题/描述内容

  // 交互状态
  @Trace type: ItemActionType = ItemActionType.NONE; // 操作类型
  @Trace value: string | boolean | number = ''; // 当前值 (用于 Toggle, Slider, Radio 等)
  @Trace enabled: boolean = true; // 是否启用
  @Trace isDanger: boolean = false; // 是否为危险操作 (用于标红)

  // 复杂配置
  @Trace dialogConfig?: DialogConfig; // 弹窗配置
  @Trace sliderConfig?: SliderConfig; // 滑块配置
  @Trace radioConfig?: RadioConfig; // 单选框配置
  @Trace menuOptions?: Array<MenuOption>; // 菜单选项列表

  // 回调事件
  // 点击及值变化事件 (用于 Toggle, Slider, Radio 变化)
  onChange?: (value: string | boolean | number) => void;
  // 菜单禁用判断
  menuDisabled?: (item: MenuOption, index: number) => boolean;

  /**
   * 构造函数：支持传入部分属性初始化
   */
  constructor(init?: CustomItemInfoParam) {
    if (init) {
      // 逐个属性赋值
      if (init.id !== undefined) this.id = init.id;
      if (init.icon !== undefined) this.icon = init.icon;
      if (init.symbol !== undefined) this.symbol = init.symbol;
      if (init.iconColor !== undefined) this.iconColor = init.iconColor;
      if (init.label !== undefined) this.label = init.label;
      if (init.subtitle !== undefined) this.subtitle = init.subtitle;

      if (init.type !== undefined) this.type = init.type;
      if (init.value !== undefined) this.value = init.value;
      if (init.enabled !== undefined) this.enabled = init.enabled;
      if (init.isDanger !== undefined) this.isDanger = init.isDanger;

      if (init.dialogConfig !== undefined) this.dialogConfig = init.dialogConfig;
      if (init.sliderConfig !== undefined) this.sliderConfig = init.sliderConfig;
      if (init.radioConfig !== undefined) this.radioConfig = init.radioConfig;
      if (init.menuOptions !== undefined) this.menuOptions = init.menuOptions;

      if (init.onChange !== undefined) this.onChange = init.onChange;
      if (init.menuDisabled !== undefined) this.menuDisabled = init.menuDisabled;
    }
  }

  setId(id: string): CustomItemInfo {
    this.id = id;
    return this;
  }

  setLabel(label: ResourceStr): CustomItemInfo {
    this.label = label;
    return this;
  }

  setType(type: ItemActionType): CustomItemInfo {
    this.type = type;
    return this;
  }

  setValue(value: string | boolean | number): CustomItemInfo {
    this.value = value;
    return this;
  }

}


//  枚举定义
/**
 * 列表项交互类型枚举
 */
export enum ItemActionType {
  MENU = 'Menu', // 菜单选择
  TOGGLE = 'Toggle', // 开关
  DIALOG = 'Dialog', // 弹窗
  COLOR = 'Color', // 颜色选择
  ROUTER = 'Router', // 跳转
  ROUTER_BLANK = 'Router_Blank', // 跳转(不含箭头)
  TEXT = 'Text', // 纯文本展示
  INPUT = 'Input', // 输入框
  BUTTON = 'Button', // 按钮
  RADIO = 'Radio', // 单选
  CHECK = 'Check', // 多选
  SLIDER = 'Slider', // 滑块
  GROUP = 'Group', // 分组头
  NONE = 'None' // 无操作
}

// 子配置类
@ObservedV2
export class RadioConfig {
  @Trace value: string = '';
  @Trace group: string = '';

  constructor(value: string, group: string) {
    this.value = value;
    this.group = group;
  }
}

@ObservedV2
export class DialogConfig {
  @Trace width?: Dimension;
  @Trace buttons?: ResourceStr[];

  onWillAppear?: () => void;
  onClick?: (button: ResourceStr, index: number, dialog: CustomDialogController | undefined) => void;

  constructor(init?: Partial<DialogConfig>) {
    if (init) {
      this.width = init.width;
      this.buttons = init.buttons;
      this.onWillAppear = init.onWillAppear;
      this.onClick = init.onClick;
    }
  }
}

@ObservedV2
export class SliderConfig {
  @Trace min: number = 0;
  @Trace max: number = 100;
  @Trace step: number = 1;
  @Trace unit?: string;
  @Trace showControl: boolean = false;

  constructor(init?: SliderConfig) {
    if (init) {
      this.min = init.min;
      this.max = init.max;
      this.step = init.step;
      this.unit = init.unit;
      this.showControl = init.showControl;
    }
  }
}

@ObservedV2
export class MenuOption {
  @Trace label?: ResourceStr;
  @Trace value: string;
  @Trace symbolIcon?: SymbolGlyphModifier;

  constructor(value: string, label?: ResourceStr) {
    this.value = value;
    this.label = label;
  }
}

// 分组数据结构
export interface ItemGroupData {
  group?: CustomItemInfo; // 分组头部信息
  items: CustomItemInfo[] // 分组内的子项
}

/**
 * 工具函数：将扁平数组转换为分组数组
 */
export function makeItemGroups(data: CustomItemInfo[]): ItemGroupData[] {
  return data.reduce((result: ItemGroupData[], item: CustomItemInfo) => {
    if (item.type === ItemActionType.GROUP) {
      // 遇到 GROUP 类型，开启一个新的分组
      result.push({ group: item, items: [] });
    } else if (result.length > 0) {
      // 否则添加到最后一个分组的 items 中
      result[result.length - 1].items.push(item);
    } else {
      // 处理第一个元素不是 GROUP 的情况
      result.push({ group: undefined, items: [item] });
    }
    return result;
  }, []);
}