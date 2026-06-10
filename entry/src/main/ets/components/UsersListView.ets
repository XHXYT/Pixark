import { PixState } from "../entryability/AppState"
import { PixivIllust, UserPreview } from "../services/PixivTypes"
import { ListColumnsTemplate } from "../common/utils/breakpoint/BreakPoint"
import { createLogger } from "../common/utils/Logger"
import { PixivImageComponent } from "./PixivImage"
import { ConfigurationConstant } from "@kit.AbilityKit"
import { UserItem } from "./UserItem"
import { appSettings, UISettings } from "../common/entity/SettingsModel"


const logger = createLogger('UserListView')

/**
 * 用户列表视图
 */
@ComponentV2
export struct UserListView {

  @Param contentEndOffset: number = 0
  @Param userPres: UserPreview[] = []
  @Param nestedScroll: NestedScrollOptions | undefined = undefined
  @Param isFollow: boolean = false
  @Event onButtonClick: (result: boolean, err?: string) => void
  @Event onImageClick: (illust: PixivIllust) => void
  @Event onReachEnd: () => void

  build() {
    List({ space: 10 }) {
      ForEach(this.userPres, (userPre: UserPreview) => {
        ListItem() {
          Column() {
            // 作品展示
            Flex({ direction: FlexDirection.Row }) {
              PixivImageComponent({
                imageUrl: userPre.illusts?.[0]?.image_urls?.square_medium || '',
                imageObjectFit: ImageFit.Auto,
                imageAspectRatio: 1,
                needClick: true,
                onImageClick: () => {
                  if (!userPre.illusts?.[0]) return
                  this.onImageClick(userPre.illusts?.[0])
                }
              })
              PixivImageComponent({
                imageUrl: userPre.illusts?.[1]?.image_urls?.square_medium || '',
                imageObjectFit: ImageFit.Auto,
                imageAspectRatio: 1,
                needClick: true,
                onImageClick: () => {
                  if (!userPre.illusts?.[1]) return
                  this.onImageClick(userPre.illusts?.[1])
                }
              })
              PixivImageComponent({
                imageUrl: userPre.illusts?.[2]?.image_urls?.square_medium || '',
                imageObjectFit: ImageFit.Auto,
                imageAspectRatio: 1,
                needClick: true,
                onImageClick: () => {
                  if (!userPre.illusts?.[2]) return
                  this.onImageClick(userPre.illusts?.[2])
                }
              })
            }
            // 头像 名称 关注
            UserItem({
              user: userPre.user,
              isFollow: userPre.user.is_followed,
              onButtonClick: (result: boolean, err?: string) => {
                this.onButtonClick(result, err)
              }
            })
            .padding(5)
          }
        }
        .clip(true)
        .borderRadius(16)
        .backgroundColor($r('sys.color.comp_background_tertiary'))
        .shadow({ radius: 16, color: UISettings.color_mode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? '#000000' : '#aaaaaa', offsetX: 6, offsetY: 6 })
        .margin(({
          left: PixState.PageMarginValue,
          right: PixState.PageMarginValue
        }))
      }, (userPre: UserPreview) => `${userPre.user.id}${userPre.user.name}`)
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .nestedScroll(this.nestedScroll)
    .lanes(ListColumnsTemplate(PixState.widthBp), 5)
    .contentEndOffset(PixState.bottomRectHeight + this.contentEndOffset)
    .onReachEnd(() => {
      logger.debug('滚动到列表底部，开始加载更多');
      this.onReachEnd()
    })
  }

}