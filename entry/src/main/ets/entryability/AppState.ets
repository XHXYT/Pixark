
import { PixivUser, UserDetailResponse } from "../services/PixivTypes"
import { common } from "@kit.AbilityKit"
import { window } from "@kit.ArkUI"
import { PageMargin,
  TabBarAvoidHeight,
  TabBarHeight, TabBarVertical, Window_BAR_HEIGHT } from "../common/utils/breakpoint/BreakPoint"
import { createLogger } from "../common/utils/Logger"

const logger = createLogger('PixivState')


@ObservedV2
export class _PixState {

  // 当前登录用户
  @Trace currentUser: PixivUser | null = null
  @Trace currentUserDetail: UserDetailResponse | null = null
  // 登录方式
  @Trace loginMethod: 'password' | 'token' = 'token'
  // refresh token
  @Trace refreshToken: string = ''
  // 是否处于多账号添加模式
  @Trace isAddingAccount: boolean = false
  // 是否初始化
  @Trace isInitializing: boolean = true
  // 加载状态
  @Trace isLoading: boolean = false
  // 是否登录过
  @Trace isLoggedIn: boolean = false

  // 窗口对象
  public static UIContext: UIContext
  public static Context: common.UIAbilityContext
  public static window: window.Window;
  /** @description 窗口高度 -px */
  public static windowWidth_px: number;
  /** @description 窗口高度 -px */
  public static windowHeight_px: number;
  /** @description 状态栏高度 -px */
  public static topAvoidAreaHeight_px: number;
  /** @description 导航栏高度 -px */
  public static navigationIndicatorHeight_px: number;
  /** @description 导航栏高度 */
  @Trace bottomRectHeight: number = 0
  /** @description 状态栏高度 */
  @Trace topRectHeight: number = 0
  /** @description 左侧避让宽度 */
  @Trace leftAvoidWidth: number = 0
  /** @description 右侧避让宽度 */
  @Trace rightAvoidWidth: number = 0
  /** @description 窗口高度 -vp */
  @Trace windowHeight: number = 0
  /** @description 窗口宽度 -vp */
  @Trace windowWidth: number = 0
  /** @description 当前宽度断点 */
  @Trace widthBp: number = 0
  /** @description 当前宽度断点 */
  @Trace heightBp: number = 0
  /** @description 窗口模式 true为PC窗口模式 false为普通窗口模式 */
  @Trace windowMode: boolean = false

  isTest: boolean = false

  @Trace currentTab: number = 0
  // 全局路由
  @Trace pageStack: NavPathStack = new NavPathStack()
  @Trace tabsController: TabsController = new TabsController()
  @Trace transitionEffect: TransitionEffect = TransitionEffect.IDENTITY;
  /** @description 当前主题色(Resource) */
  @Trace CurrentAppThemeColor: Resource = $r('sys.color.icon_emphasize')

  @Computed
  get TabBarVertical() {
    return TabBarVertical(this.widthBp, this.heightBp)
  }

  @Computed
  get PageMarginValue() {
    return PageMargin(this.widthBp, this.heightBp)
  }

  @Computed
  get TabBarHeight(): number | string {
    const isVerticalTab = PixState.TabBarVertical;
    // 窗口模式 + 横向 TabBar (TabBar在底部)
    if (PixState.windowMode && !isVerticalTab) {
      return Window_BAR_HEIGHT;
    }
    // 普通窗口，不避让安全区
    if (PixState.bottomRectHeight === 0) {
      return TabBarHeight(PixState.widthBp, PixState.heightBp);
    }
    // 普通窗口，避让安全区域高度 (沉浸式 + 安全区)
    return TabBarAvoidHeight(PixState.widthBp, PixState.heightBp);
  }

  @Monitor('pageStack')
  onPageStackChange() {
    if (this.currentTab == 3 && this.pageStack.size() <= 1 ) {
      }
  }

}

export const PixState: _PixState = new _PixState()