import { PixivService } from "../services/PixivService"
import { PixivIllust } from "../services/PixivTypes"

@ObservedV2
class _PixState {
  // Pixiv
  @Trace pixiv = new PixivService()
  // 登录方式
  @Trace loginMethod: 'password' | 'token' = 'token'
  // refresh token
  @Trace refreshToken: string = ''
  // 加载状态
  @Trace isLoading: boolean = false
  // 是否登录
  @Trace isLoggedIn: boolean = false
  @Trace illustRecommends: PixivIllust[] = []

  /** @description 导航栏高度 */
  @Trace bottomRectHeight: number = 0
  /** @description 状态栏高度 */
  @Trace topRectHeight: number = 0
  /** @description 左侧避让宽度 */
  @Trace leftAvoidWidth: number = 0
  /** @description 右侧避让宽度 */
  @Trace rightAvoidWidth: number = 0
  /** @description 窗口高度 */
  @Trace windowHeight: number = 0
  /** @description 窗口宽度 */
  @Trace windowWidth: number = 0
  /** @description 当前宽度断点 */
  @Trace widthBp: number = 0
  /** @description 当前宽度断点 */
  @Trace heightBp: number = 0
  /** @description 窗口模式 true为PC窗口模式 false为普通窗口模式 */
  @Trace windowMode: boolean = false

  /** @description 当前主题色(Resource) */
  @Trace CurrentAppThemeColor: Resource = $r('sys.color.icon_emphasize')

}

export const PixState: _PixState = new _PixState()