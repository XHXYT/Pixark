import UIConstants from "../common/constants/UIConstants"
import { PixState } from "../entryability/AppState"
import { KeyCode } from "@kit.InputKit"


@ComponentV2
export struct NaviContainer {

  @Param title: ResourceStr = ''
  @Param subTitle: ResourceStr = ''

  @Param showMenu: boolean = false
  @Param hideTitleBar: boolean = false

  @Param transitionEffect?: TransitionEffect = undefined

  @BuilderParam menusBuilder?: () => void
  @BuilderParam content: () => void;

  @Param buttons: NavigationMenuItem[] = []

  private pageStack: NavPathStack = new NavPathStack()
    
  @Event onReady: (ctx: NavDestinationContext) => void
  @Event onBackPressed: () => boolean
  @Event onNaviDisAppear: () => void

  build() {
    NavDestination() {
      if (this.menusBuilder) {
        Row().height(1).width('100%')
          .bindContextMenu(this.showMenu!!, this.menusBuilder,
            {
              placement: PixState.widthBp < 2 ? Placement.LeftBottom : Placement.BottomRight,
            })
      }
      Column() {
        this.content()
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Start)
      .alignItems(HorizontalAlign.Center)
    }
    .height('100%')
    .hideToolBar(true)
    .menus(this.buttons)
    .hideTitleBar(this.hideTitleBar)
    .transition(this.transitionEffect)
    .padding(this.hideTitleBar ? undefined : { top: PixState.topRectHeight || 12 })
    .title({ main: this.title, sub: this.subTitle }, { backgroundColor: Color.Transparent })
    .onBackPressed(() => {
      return this.onBackPressed()
    })
    .onKeyEvent((event: KeyEvent) => {
      if (event.type === KeyType.Down) {
        if (event.keyCode === KeyCode.KEYCODE_ESCAPE) {
          if (!this.onBackPressed()) {
            this.pageStack.pop()
          }
        }
      }
    })
    .onReady((ctx: NavDestinationContext) => {
      this.pageStack = ctx.pathStack
      this.onReady(ctx)
    })
    .animation({ duration: UIConstants.AnimationSpeed_300, curve: Curve.Ease })
  }

}