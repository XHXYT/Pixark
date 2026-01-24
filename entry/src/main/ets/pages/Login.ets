
import { PixState } from '../entryability/AppState';

@ComponentV2
export struct Login {

  build() {
    Column() {
      // 图标
      Image($r('app.media.app_icon_round'))
        .height(106)
        .margin({ bottom: 60 })

      // 登录 (跳转到 Web 登录页)
      Button('登录')
        .width('80%')
        .height(50)
        .fontSize(18)
        .margin({ bottom: 20 })
        .onClick(() => {
          // 跳转到 Web 登录页
          PixState.pageStack.pushPathByName('web_login', null);
        })

      // 注册账号 (跳转到注册页)
      Button('注册账号')
        .width('80%')
        .height(50)
        .fontSize(18)
        .margin({ bottom: 20 })
        .onClick(() => {
          // 跳转到注册页
          PixState.pageStack.pushPathByName('register', null);
        })

      // Token 登录 (跳转到 Token 输入页)
      Button('Token 登录')
        .width('80%')
        .height(50)
        .fontSize(18)
        .backgroundColor('#F0F0F0')
        .fontColor('#333333')
        .onClick(() => {
          // 跳转到 Token 登录页
          PixState.pageStack.pushPathByName('token_login', null);
        })
    }
    .width('100%')
    .height('100%')
    .padding({ top: PixState.topRectHeight, bottom: PixState.bottomRectHeight })
    .justifyContent(FlexAlign.Center)
  }
}
