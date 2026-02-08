import { BreakpointFunction } from "./BreakPointStystem";
import { BreakpointFunction2D, BreakpointType2D } from "./BreakPointSystem2D";

/**首页轮播图显示数量*/
export const HomeBannerDisplayCount = BreakpointFunction<number>({
  ['sm']: 1, ['md']: 2, ['lg']: 3, ['xl']: 3
})

/**首页轮播图前&后边距（前后露出的部分）*/
export const HomeBannerBannerMargin = BreakpointFunction<number>({
  ['sm']: 0, ['md']: 12, ['lg']: 64, ['xl']: 64
})

export const Window_BAR_HEIGHT = 73;

/**Tab栏竖向方式*/
export const TabBarJustifyContent = BreakpointFunction2D<number>({
  ['sm']: {['hsm']: FlexAlign.Start, ['hmd']: FlexAlign.Start, ['hlg']: FlexAlign.Start},
  ['md']: {['hsm']: FlexAlign.Center, ['hmd']: FlexAlign.Start, ['hlg']: FlexAlign.Start},
  ['lg']: {['hsm']: FlexAlign.Center, ['hmd']: FlexAlign.Center, ['hlg']: FlexAlign.Center},
  ['xl']: {['hsm']: FlexAlign.Center, ['hmd']: FlexAlign.Center, ['hlg']: FlexAlign.Center},
})

/**Tab栏横向方式-普通*/
export const TabBarAlignItems = BreakpointFunction2D<number>({
  ['sm']: {['hsm']: ItemAlign.Center, ['hmd']: ItemAlign.Center, ['hlg']: ItemAlign.Center},
  ['md']: {['hsm']: ItemAlign.End, ['hmd']: ItemAlign.Center, ['hlg']: ItemAlign.Center},
  ['lg']: {['hsm']: ItemAlign.Center, ['hmd']: ItemAlign.Center, ['hlg']: ItemAlign.Center},
  ['xl']: {['hsm']: ItemAlign.Center, ['hmd']: ItemAlign.Center, ['hlg']: ItemAlign.Center},
})

/**Tab栏位置*/
export const TabBarPosition = BreakpointFunction2D<number>({
  ['sm']: {['hsm']: BarPosition.End, ['hmd']: BarPosition.End, ['hlg']: BarPosition.End},
  ['md']: {['hsm']: BarPosition.Start, ['hmd']: BarPosition.End, ['hlg']: BarPosition.End},
  ['lg']: {['hsm']: BarPosition.Start, ['hmd']: BarPosition.Start, ['hlg']: BarPosition.Start},
  ['xl']: {['hsm']: BarPosition.Start, ['hmd']: BarPosition.Start, ['hlg']: BarPosition.Start},
})

/**Tab栏方向*/
export const TabBarVertical = BreakpointFunction2D<boolean>({
  ['sm']: {['hsm']: false, ['hmd']: false, ['hlg']: false},
  ['md']: {['hsm']: true, ['hmd']: false, ['hlg']: false},
  ['lg']: {['hsm']: true, ['hmd']: true, ['hlg']: true},
  ['xl']: {['hsm']: true, ['hmd']: true, ['hlg']: true},
})

/**Tab栏宽度*/
export const TabBarWidth = BreakpointFunction2D<string>({
  ['sm']: {['hsm']: '100%', ['hmd']: '100%', ['hlg']: '100%'},
  ['md']: {['hsm']: '77vp', ['hmd']: '100%', ['hlg']: '100%'},
  ['lg']: {['hsm']: '67vp', ['hmd']: '67vp', ['hlg']: '67vp'},
  ['xl']: {['hsm']: '67vp', ['hmd']: '67vp', ['hlg']: '67vp'},
})

/**Tab栏宽度-窗口*/
export const WindowTabBarWidth = BreakpointFunction2D<string>({
  ['sm']: {['hsm']: '100%', ['hmd']: '100%', ['hlg']: '100%'},
  ['md']: {['hsm']: '57vp', ['hmd']: '100%', ['hlg']: '100%'},
  ['lg']: {['hsm']: '57vp', ['hmd']: '57vp', ['hlg']: '57vp'},
  ['xl']: {['hsm']: '57vp', ['hmd']: '57vp', ['hlg']: '57vp'},
})

/**Tab栏高度-避让底部*/
export const TabBarAvoidHeight = BreakpointFunction2D<string>({
  ['sm']: {['hsm']: '67vp', ['hmd']: '67vp', ['hlg']: '77vp'},
  ['md']: {['hsm']: '100%', ['hmd']: '77vp', ['hlg']: '77vp'},
  ['lg']: {['hsm']: '100%', ['hmd']: '100%', ['hlg']: '100%'},
  ['xl']: {['hsm']: '100%', ['hmd']: '100%', ['hlg']: '100%'},
})

/**Tab栏高度-不避让底部*/
export const TabBarHeight = BreakpointFunction2D<string>({
  ['sm']: {['hsm']: '57vp', ['hmd']: '57vp', ['hlg']: '57vp'},
  ['md']: {['hsm']: '100%', ['hmd']: '57vp', ['hlg']: '57vp'},
  ['lg']: {['hsm']: '100%', ['hmd']: '100%', ['hlg']: '100%'},
  ['xl']: {['hsm']: '100%', ['hmd']: '100%', ['hlg']: '100%'},
})

/**悬浮Tab栏高度*/
export const FloatTabBarHeight = BreakpointFunction2D<Length>({
  ['sm']: {['hsm']: 60, ['hmd']: 60, ['hlg']: 60},
  ['md']: {['hsm']: '100%', ['hmd']: 'auto', ['hlg']: 'auto'},
  ['lg']: {['hsm']: 'auto', ['hmd']: 'auto', ['hlg']: 'auto'},
  ['xl']: {['hsm']: 'auto', ['hmd']: 'auto', ['hlg']: 'auto'},
})

/**Tab栏字体大小*/
export const TabTitleFontSize = BreakpointFunction2D<number>({
  ['sm']: {['hsm']: 12, ['hmd']: 12, ['hlg']: 12},
  ['md']: {['hsm']: 12, ['hmd']: 14, ['hlg']: 16},
  ['lg']: {['hsm']: 16, ['hmd']: 16, ['hlg']: 16},
  ['xl']: {['hsm']: 16, ['hmd']: 16, ['hlg']: 16},
})

/**Tab栏图标大小*/
export const TabIconFontSize = BreakpointFunction2D<number>({
  ['sm']: {['hsm']: 24, ['hmd']: 24, ['hlg']: 24},
  ['md']: {['hsm']: 24, ['hmd']: 26, ['hlg']: 26},
  ['lg']: {['hsm']: 26, ['hmd']: 26, ['hlg']: 26},
  ['xl']: {['hsm']: 26, ['hmd']: 26, ['hlg']: 26},
})

/**列表行外边距*/
export const ListItemMarginValue = BreakpointFunction2D<number>({
  ['sm']: {['hsm']: 15, ['hmd']: 15, ['hlg']: 15},
  ['md']: {['hsm']: 16, ['hmd']: 16, ['hlg']: 16},
  ['lg']: {['hsm']: 16, ['hmd']: 16, ['hlg']: 16},
  ['xl']: {['hsm']: 16, ['hmd']: 16, ['hlg']: 16},
})

/**页面外边距(更多、设置)*/
export const PageMargin = BreakpointFunction2D<number>({
  ['sm']: {['hsm']: 12, ['hmd']: 15, ['hlg']: 15},
  ['md']: {['hsm']: 15, ['hmd']: 16, ['hlg']: 16},
  ['lg']: {['hsm']: 16, ['hmd']: 16, ['hlg']: 16},
  ['xl']: {['hsm']: 16, ['hmd']: 16, ['hlg']: 16},
})

/**窗口化更多标题字体大小*/
export const WindowModeMoreTitleFontSize = BreakpointFunction2D<number>({
  ['sm']: {['hsm']: 24, ['hmd']: 24, ['hlg']: 24},
  ['md']: {['hsm']: 23, ['hmd']: 27, ['hlg']: 27},
  ['lg']: {['hsm']: 27, ['hmd']: 30, ['hlg']: 30},
  ['xl']: {['hsm']: 30, ['hmd']: 30, ['hlg']: 30},
})

/**列表列数（WaterFlow）*/
export const WaterFlowColumnsTemplate = BreakpointFunction<string>({
  ['sm']: "1fr 1fr",
  ['md']: "1fr 1fr 1fr 1fr",
  ['lg']: "1fr 1fr 1fr 1fr 1fr",
  ['xl']: "1fr 1fr 1fr 1fr 1fr 1fr"
})

/**列表列数（List）*/
export const ListColumnsTemplate = BreakpointFunction<number>({
  ['sm']: 1,
  ['md']: 2,
  ['lg']: 3,
  ['xl']: 4
})

export const GridColumnsTemplate = BreakpointFunction<string>({
  ['sm']: "1fr 1fr 1fr",
  ['md']: "1fr 1fr 1fr",
  ['lg']: "1fr 1fr 1fr 1fr",
  ['xl']: "1fr 1fr 1fr 1fr 1fr 1fr 1fr"
})

/**列表列数（代理页）*/
export const ProxyListLanes = BreakpointFunction2D<number>({
  ['sm']: {['hsm']: 2, ['hmd']: 2, ['hlg']: 2},
  ['md']: {['hsm']: 2, ['hmd']: 3, ['hlg']: 3},
  ['lg']: {['hsm']: 3, ['hmd']: 4, ['hlg']: 4},
  ['xl']: {['hsm']: 4, ['hmd']: 4, ['hlg']: 4},
})

/**列表间距*/
export const ListGutter = BreakpointFunction2D<number>({
  ['sm']: {['hsm']: 8, ['hmd']: 8, ['hlg']: 8},
  ['md']: {['hsm']: 10, ['hmd']: 10, ['hlg']: 10},
  ['lg']: {['hsm']: 15, ['hmd']: 15, ['hlg']: 15},
  ['xl']: {['hsm']: 20, ['hmd']: 20, ['hlg']: 20},
})

/**路由主页列表内边距*/
export const NavigationListPadding = BreakpointFunction2D<number>({
  ['sm']: {['hsm']: 13, ['hmd']: 13, ['hlg']: 13},
  ['md']: {['hsm']: 15, ['hmd']: 15, ['hlg']: 15},
  ['lg']: {['hsm']: 28, ['hmd']: 28, ['hlg']: 28},
  ['xl']: {['hsm']: 36, ['hmd']: 36, ['hlg']: 36},
})

/**内容外边距*/
export const TabContentTitleMargin = BreakpointFunction2D<number>({
  ['sm']: {['hsm']: 13, ['hmd']: 13, ['hlg']: 13},
  ['md']: {['hsm']: 28, ['hmd']: 28, ['hlg']: 28},
  ['lg']: {['hsm']: 36, ['hmd']: 36, ['hlg']: 36},
  ['xl']: {['hsm']: 36, ['hmd']: 36, ['hlg']: 36},
})

/**更多页是否清空路由*/
export const NeedClearMoreStack = BreakpointFunction2D<boolean>({
  ['sm']: {['hsm']: true, ['hmd']: true, ['hlg']: true},
  ['md']: {['hsm']: true, ['hmd']: false, ['hlg']: false},
  ['lg']: {['hsm']: false, ['hmd']: false, ['hlg']: false},
  ['xl']: {['hsm']: false, ['hmd']: false, ['hlg']: false},
})

/**更多页路由是否分栏*/
export const MoreNavMode = BreakpointFunction2D<NavigationMode>({
  ['sm']: {['hsm']: NavigationMode.Stack, ['hmd']: NavigationMode.Stack, ['hlg']: NavigationMode.Stack},
  ['md']: {['hsm']: NavigationMode.Split, ['hmd']: NavigationMode.Split, ['hlg']: NavigationMode.Split},
  ['lg']: {['hsm']: NavigationMode.Split, ['hmd']: NavigationMode.Split, ['hlg']: NavigationMode.Split},
  ['xl']: {['hsm']: NavigationMode.Split, ['hmd']: NavigationMode.Split, ['hlg']: NavigationMode.Split},
})