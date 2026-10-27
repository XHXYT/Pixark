import { PixivImageComponent } from "../../components/PixivImage";
import { PixState } from "../../entryability/AppState";
import { SegmentButtonV2Items, SymbolGlyphModifier, TabSegmentButtonV2 } from '@kit.ArkUI';
import { UserDetailViewModel } from "../../viewmodel/UserDetailViewModel";
import { UserDetailParams } from "../../common/entity/UserDetailEntity";
import { DetailPageParams } from "../../common/entity/DetailEntity"; // 用于跳转插画
import { WaterFlowView } from "../../components/WaterFlowView";
import { NaviContainer } from "../../components/NaviContainer";
import { muteFilter } from "../../services/MuteFilter";
import { toastUtil } from "../../common/utils/ToastUtils";


@Builder
export function UserDetailBuilder(name: string, param: Object) {
  UserDetail()
}


@ComponentV2
struct UserDetail {

  @Local scroller: Scroller = new Scroller();
  @Local uDV: UserDetailViewModel =  new UserDetailViewModel()
  @Local showMenu: boolean = false
  @Local userId: number = 0
  /** 该画师已被屏蔽（进入页面时检查） */
  @Local userMuted: boolean = false
  /** 本次浏览中暂时查看被屏蔽画师 */
  @Local tempViewMuted: boolean = false

  private tabItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: $r('app.string.works') },
    { text: $r('app.string.collection') },
    { text: $r('app.string.details') },
  ]);

  build() {
    NaviContainer({
      title: this.uDV.userData?.user.name,
      content: () => {
        if (this.userMuted && !this.tempViewMuted) {
          this.MuteOverlay()
        } else {
          this.Content()
        }
      },
      onReady: (ctx: NavDestinationContext) => {
        const params: UserDetailParams = ctx?.pathInfo?.param as UserDetailParams
        this.userId = params.id
        // 进入画师主页前检查屏蔽状态
        this.userMuted = !!muteFilter.checkUser(params.id)
        this.tempViewMuted = false
        this.uDV.onReady(ctx, params)
      },
      onBackPressed: () => {
        return false
      },
      showMenu: this.showMenu,
      buttons: this.userButtons(),
      menusBuilder: () => { this.UserMenu() }
    })
  }

  // 标题栏按钮：屏蔽菜单入口
  private userButtons(): NavigationMenuItem[] {
    return [
      {
        value: '',
        symbolIcon: new SymbolGlyphModifier($r('sys.symbol.dot_grid_2x2')),
        action: () => {
          this.showMenu = !this.showMenu
        }
      }
    ]
  }

  // 屏蔽菜单
  @Builder
  UserMenu() {
    Menu() {
      MenuItem({ content: $r('app.string.mute_this_artist') })
        .onClick(() => {
          this.showMenu = false
          this.muteThisArtist()
        })
      MenuItem({ content: $r('app.string.mute_settings') })
        .onClick(() => {
          this.showMenu = false
          PixState.pushPage('mute_settings', null, true)
        })
    }
  }

  /** 屏蔽当前画师（当前页保持可见） */
  private muteThisArtist(): void {
    if (!this.userId) {
      return
    }
    const name = this.uDV.userData?.user.name || this.uDV.preUserData?.name || ''
    muteFilter.addRule('user', String(this.userId), name).then((ok: boolean) => {
      toastUtil.showToast({ message: ok ? $r('app.string.mute_added') : $r('app.string.mute_add_failed') })
    })
  }

  /** 被屏蔽画师的拦截页 */
  @Builder
  MuteOverlay() {
    Column({ space: 16 }) {
      SymbolGlyph($r('sys.symbol.eye_slash'))
        .fontSize(64)
        .fontColor([$r('sys.color.font_tertiary')])
      Text($r('app.string.mute_blocked_user'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text(this.uDV.userData?.user.name || this.uDV.preUserData?.name || String(this.userId))
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
      Row({ space: 12 }) {
        Button($r('app.string.mute_temp_view'))
          .backgroundColor($r('sys.color.comp_background_tertiary'))
          .fontColor($r('sys.color.font_primary'))
          .onClick(() => {
            this.tempViewMuted = true
          })
        Button($r('app.string.mute_unblock'))
          .backgroundColor(PixState.currentThemeColor)
          .onClick(() => {
            muteFilter.removeRule('user', String(this.userId)).then(() => {
              this.userMuted = false
              toastUtil.showToast({ message: $r('app.string.mute_removed') })
            })
          })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.background_primary'))
  }

  @Builder
  Content() {
    // 主内容滚动区域
    List() {
      // 顶部背景 & 用户信息卡片
      ListItem() {
        this.UserHeader()
      }
      // 内容主题
      ListItem() {
        Column() {
          // 作品 收藏 详情分段按钮
          Row() {
            TabSegmentButtonV2({
              items: this.tabItems,
              selectedIndex: this.uDV.tabIndex,
              onItemClicked: (tab) => {
                this.uDV.handleTabChange(tab)
              }
            })
          }
          .width('100%')
          .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
          .margin({ top: 20, bottom: 10 })
          // 内容区域
          if (this.uDV.tabIndex === 0 || this.uDV.tabIndex === 1) {
            // 作品 / 收藏
            WaterFlowView({
              contentEndOffset: PixState.bottomRectHeight === 0 ? PixState.PageMarginValue : PixState.bottomRectHeight,
              nestedScroll: this.uDV.nestedScrollOptions,
              clipContent: false, // 嵌套非自滚：关闭裁剪让边缘卡片阴影画进留白
              illustList: this.uDV.currentIllustList,
              onCardClick: (illust) => {
                this.uDV.handleIllustClick(illust)
              },
              onReachEnd: () => {
                this.uDV.loadMoreCurrentData()
              }
            })
          } else if (this.uDV.tabIndex === 2) {
            // 详细信息
            this.UserDetailList()
          }
        }
        .width('100%')
      }
    }
    .backgroundColor($r('sys.color.background_primary'))
    .contentStartOffset(PixState.topRectHeight + 56)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%').height('100%')
    .align(Alignment.TopStart)
    .scrollBar(BarState.Off)
  }

  @Builder
  UserHeader() {
    Column() {
      // 背景图
      Stack({ alignContent: Alignment.Bottom }) {
        if (this.uDV.userData?.profile?.background_image_url) {
          PixivImageComponent({
            imageUrl: this.uDV.userData.profile.background_image_url,
            imageObjectFit: ImageFit.Cover,
            imageBorder: { radius: 0 }
          })
            .width('100%')
            .height(200)
        } else {
          // 如果没有背景图（或者还在加载详情），显示灰色占位
          Row()
            .width('100%')
            .height(200)
            .backgroundColor($r('sys.color.font_on_fourth'))
        }
        // TODO 渐变模糊遮罩
      }
      .width('100%')

      // 信息内容
      Column({ space: 12 }) {
        // 头像：优先取 userData.user，取不到则取 preUserData
        PixivImageComponent({
          imageUrl: this.uDV.userData?.user.profile_image_urls.medium || this.uDV.preUserData?.profile_image_urls.medium || '',
          imageWidth: 80, imageHeight: 80,
          imageBorder: { radius: 40 }
        })
        // 名字
        Text(this.uDV.userData?.user.name || this.uDV.preUserData?.name || '')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        // ID
        Text(`ID: ${this.uDV.userData?.user.id || this.uDV.preUserData?.id || ''}`)
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
        // 简介
        Text(this.uDV.userData?.user.comment || (this.uDV.isDetailLoading ? $r('app.string.loading_info') : $r('app.string.no_comment')))
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 4 })
        // 关注按钮
        Button(this.uDV.isFollow ? $r('app.string.unfollow') : $r('app.string.follow'))
          .backgroundColor(this.uDV.isFollow ? '#F0F0F0' : '#0096fa')
          .fontColor(this.uDV.isFollow ? $r('sys.color.font_primary') : Color.White)
          .padding({ left: 20, right: 20 })
          .type(ButtonType.Normal)
          .fontSize(14)
          .height(36)
          .borderRadius(18)
          .onClick(() => {
            this.uDV.followOrCancel()
          })
        // 统计数据
        Row() {
          Column({ space: 4 }) {
            Text($r('app.string.follow'))
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))
            Text(`${this.uDV.userData?.profile?.total_follow_users ?? '--'}`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)
          Column({ space: 4 }) {
            Text($r('app.string.works'))
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))
            Text(`${this.uDV.userData?.profile?.total_illusts ?? '--'}`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)
          Column({ space: 4 }) {
                       Text($r('app.string.collection'))
              .fontSize(12)
              .fontColor($r('sys.color.font_tertiary'))
            Text(`${this.uDV.userData?.profile?.total_illust_bookmarks_public ?? '--'}`)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
          }
          .layoutWeight(1)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
      .margin({ top: -40 })
      .zIndex(2)
    }
    .width('100%')
  }

  @Builder
  UserDetailList() {
    List({ space: 1 }) {
      // 简介
      ListItem() {
        this.InfoRow($r('app.string.comment'), this.uDV.userData?.user.comment || '~')
      }
      ListItem() {
        this.InfoRow('ID', `${this.uDV.userData?.user?.id}` || $r('app.string.unknown'))
      }
      ListItem() {
        this.InfoRow($r('app.string.created_date'), this.uDV.userData?.user?.created_date || $r('app.string.unknown'))
      }
      ListItem() {
        this.InfoRow($r('app.string.gender'), this.uDV.userData?.profile?.gender || $r('app.string.unknown'))
      }
      ListItem() {
        this.InfoRow($r('app.string.region'), this.uDV.userData?.profile?.region || $r('app.string.unknown'))
      }
      // 生日
      if (this.uDV.userData?.profile?.birth) {
        ListItem() {
          this.InfoRow($r('app.string.birthday'), this.uDV.userData.profile.birth)
        }
      }
      // 个人网站
      if (this.uDV.userData?.profile?.webpage) {
        ListItem() {
          this.InfoRow($r('app.string.website'), this.uDV.userData.profile.webpage)
        }
      }
      // Twitter (品牌名通常不翻译，或者你可以加个 "Twitter" 的 key)
      if (this.uDV.userData?.profile?.twitter_account) {
        ListItem() {
          this.InfoRow('Twitter', this.uDV.userData.profile.twitter_account)
        }
      }
      // 工作区 PC
      if (this.uDV.userData?.workspace?.pc) {
        ListItem() {
          this.InfoRow($r('app.string.pc_model'), this.uDV.userData.workspace.pc)
        }
      }
      // 显示器
      if (this.uDV.userData?.workspace?.monitor) {
        ListItem() {
          this.InfoRow($r('app.string.monitor'), this.uDV.userData.workspace.monitor)
        }
      }
      // 绘图软件
      if (this.uDV.userData?.workspace?.tool) {
        ListItem() {
          this.InfoRow($r('app.string.tool'), this.uDV.userData.workspace.tool)
        }
      }
      // 数位板
      if (this.uDV.userData?.workspace?.tablet) {
        ListItem() {
          this.InfoRow($r('app.string.tablet'), this.uDV.userData.workspace.tablet)
        }
      }

    }
    .width('100%')
    .borderRadius(12)
    .margin({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
  }

  @Builder
  InfoRow(title: ResourceStr, value: ResourceStr) {
    Row() {
      Text(title)
        .fontColor($r('sys.color.font_tertiary'))
        .fontSize(14)
        .width(100)
      Text(value)
        .fontColor($r('sys.color.font_primary'))
        .fontSize(14)
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

}
