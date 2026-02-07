import { UserDetailParams } from "../entity/UserDetailEntity"
import { PixState } from "../entryability/AppState"
import { PixivUser } from "../services/PixivTypes"
import { PixivImageComponent } from "./PixivImage"

@ComponentV2
export struct UserItem {

  @Param @Require user: PixivUser
  @Param isFollow: boolean = false
  @Event onButtonClick: (id: number) => void

  build() {
    // 头像 名称 关注
    Flex({ direction: FlexDirection.Row, alignItems: ItemAlign.Center }) {
      Row({ space: 5 }) {
        PixivImageComponent({
          imageUrl: this.user.profile_image_urls.medium,
          imageWidth: 50, imageHeight: 50,
          imageBorder: { radius: 50 }
        })
        Text(this.user.name)
          .fontSize(12)
          .maxLines(1)
      }
      .onClick(() => {
        const params: UserDetailParams = {
          id: this.user.id,
          user: this.user
        }
        // 跳转详情页
        PixState.pageStack.pushPathByName('user_detail', params, true);
      })
      Blank()
      Button(this.isFollow ? $r('app.string.followed') : $r('app.string.follow'))
        .type(ButtonType.Normal)
        .fontSize(12)
        .height(28)
        .padding({ left: 12, right: 12 })
        .borderRadius(14)
        .fontColor(Color.White)
        .onClick(() => {
          this.onButtonClick(this.user.id)
        })
    }
  }

}