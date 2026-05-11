import { NaviContainer } from '../components/NaviContainer';
import { PixState } from '../entryability/AppState';


@Builder
export function LoginBuilder() {
  Login()
}

@ComponentV2
export struct Login {

  private pageStack?: NavPathStack = undefined

  build() {
    NaviContainer({
      hideTitleBar: !PixState.isAddingAccount,
      content: () => {
        this.Content()
      },
      onReady: (ctx) => {
        if (ctx.pathStack) {
          this.pageStack = ctx.pathStack
        } else {
          this.pageStack = PixState.pageStack
        }
      }
    })
  }

  @Builder
  Content() {
    Column() {
      // 图标
      Image($r('app.media.app_icon_round'))
        .height(106)
        .margin({ bottom: 60 })

      // 登录 (跳转到 Web 登录页)
      Button(PixState.isAddingAccount ? $r('app.string.add_an_account') : $r('app.string.login'))
        .width('80%')
        .height(50)
        .fontSize(18)
        .margin({ bottom: 20 })
        .onClick(() => {
          // 跳转到 Web 登录页
          this.pageStack?.pushPathByName('web_login', null);
        })

      // 注册账号 (跳转到注册页)
      if (!PixState.isAddingAccount) {
        Button($r('app.string.register_account'))
          .width('80%')
          .height(50)
          .fontSize(18)
          .margin({ bottom: 20 })
          .onClick(() => {
            this.pageStack?.pushPathByName('register', null);
          })
      }

      // Token 登录 (跳转到 Token 输入页)
      Button($r('app.string.token_login'))
        .width('80%')
        .height(50)
        .fontSize(18)
        .backgroundColor('#F0F0F0')
        .fontColor('#333333')
        .onClick(() => {
          // 跳转到 Token 登录页
          this.pageStack?.pushPathByName('token_login', null);
        })
    }
    .padding({ top: PixState.topRectHeight, bottom: PixState.bottomRectHeight })
    .justifyContent(FlexAlign.Center)
    .layoutWeight(1)
  }

}
