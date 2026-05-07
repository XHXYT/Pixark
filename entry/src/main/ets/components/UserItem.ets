import { UserDetailParams } from "../common/entity/UserDetailEntity"
import { PixState } from "../entryability/AppState"
import { PixivUser } from "../services/PixivTypes"
import { createLogger } from "../utils/Logger"
import { toastUtil } from "../utils/ToastUtils"
import { PixivImageComponent } from "./PixivImage"

const logger = createLogger('UserItem')

@ComponentV2
export struct UserItem {

  @Param @Require user: PixivUser
  @Param isFollow: boolean = false

  @Event onButtonClick: (result: boolean, err?: string) => void

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
        this.push()
      })
      Blank().onClick(() => {
        this.push()
      })
      Button(this.isFollow ? $r('app.string.followed') : $r('app.string.follow'))
        .type(ButtonType.Normal)
        .fontSize(12)
        .height(28)
        .padding({ left: 12, right: 12 })
        .borderRadius(14)
        .fontColor(Color.White)
        .onClick(async () => {
          if (this.isFollow) {
            // 取消关注
            if (!this.user.id) {
              toastUtil.showToast({ message: "用户ID不存在" })
              return
            }
            try {
              await PixState.pixiv.unfollowUser(this.user.id, 'public')
              this.user.is_followed = false
              toastUtil.showToast({ message: $r('app.string.unfollow_success', this.user.name) })
              this.onButtonClick(false)
            } catch (err) {
              toastUtil.showToast({ message: $r('app.string.unfollow_fail') })
              logger.error(`!!! 取关操作失败: ${JSON.stringify(err)}`);
              this.onButtonClick(true, err.message)
            }
          } else {
            // 关注
            if (!this.user.id) {
              toastUtil.showToast({ message: "用户ID不存在" })
              return
            }
            try {
              await PixState.pixiv.followUser(this.user.id, 'public')
              this.user.is_followed = true
              toastUtil.showToast({ message: $r('app.string.follow_success', this.user.name) })
              this.onButtonClick(true)
            } catch (err) {
              toastUtil.showToast({ message: $r('app.string.follow_fail') })
              logger.error(`!!! 关注操作失败: ${JSON.stringify(err)}`);
              this.onButtonClick(false, err.message)
            }
          }
        })
    }
  }

  push() {
    const params: UserDetailParams = {
      id: this.user.id,
      user: this.user
    }
    // 跳转详情页
    PixState.pageStack.pushPathByName('user_detail', params, true);
  }

}