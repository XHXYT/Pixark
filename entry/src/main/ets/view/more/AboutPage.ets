import { CustomItemInfo, ItemActionType, ItemGroupData, makeItemGroups, MenuOption } from "../../common/entity/CusItemInfo"
import { CustomListItem } from "../../components/CusItemBuilder"
import { NaviContainer } from "../../components/NaviContainer"
import { PixState, _PixState } from "../../entryability/AppState"
import { JumpUtil } from "../../common/utils/JumpUtils"
import { toastUtil } from "../../common/utils/ToastUtils"
import { AppConstants } from "../../common/constants/AppConstants"

@Builder
export function AboutPageBuilder() {
  AboutPage()
}


@ComponentV2
struct AboutPage {
  private pageStack: NavPathStack = new NavPathStack()

  private get itemList(): CustomItemInfo[] {
    return [
      // 基本信息组
      new CustomItemInfo({ id: 'info', title: $r('app.string.basic_info'), type: ItemActionType.GROUP }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.info_circle'),
        title: $r('app.string.app_version'),
        type: ItemActionType.TEXT,
        id: 'app_version',
        value: _PixState.appVersion,
        onChange: () => {
          // TODO 点击版本号可以做一些彩蛋
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.parkingsign_circle_badge_a'),
        title: $r('app.string.project_intro'),
        subtitle: 'HarmonyOS 原生轻量级 Pixiv 第三方客户端',
        type: ItemActionType.ROUTER,
        id: 'project_intro',
        onChange: () => {
          toastUtil.showAlertDialog({
            title: $r('app.string.project_intro'),
            message: 'Pixark 是一款为 HarmonyOS 开发的原生轻量级 Pixiv 第三方客户端，旨在为鸿蒙用户提供原生流畅的插画浏览体验。',
            alignment: DialogAlignment.Center,
            primaryButton: { value: 'OK', action: () => {} }
          })
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.arrow_2_circlepath'),
        title: $r('app.string.check_update'),
        type: ItemActionType.ROUTER,
        id: 'check_update',
        subtitle: _PixState.appVersion,
        onChange: () => {
          // TODO: 检查更新逻辑
          toastUtil.showToast({ message: '正在检查更新...' })
        }
      }),

      // 链接组
      new CustomItemInfo({ id: 'links', title: $r('app.string.project_home'), type: ItemActionType.GROUP }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.person'),
        title: $r('app.string.author_home'),
        type: ItemActionType.ROUTER,
        id: 'author_home',
        onChange: () => { JumpUtil.goToWeb(AppConstants.GITHUB_OWNER_URL) }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.star_circle'),
        title: $r('app.string.project_repo'),
        type: ItemActionType.ROUTER,
        id: 'project_repo',
        onChange: () => { JumpUtil.goToWeb(AppConstants.GITHUB_REPO_URL) }
      }),

      // 贡献者组
      new CustomItemInfo({ id: 'contributors', title: $r('app.string.contributors'), type: ItemActionType.GROUP }),
      new CustomItemInfo({
        icon: $rawfile('ya.jfif'),
        title: 'XHXYT',
        subtitle: $r('app.string.project_maintenance'),
        type: ItemActionType.ROUTER,
        id: 'contributor_xhxyt',
        onChange: () => { JumpUtil.goToWeb(AppConstants.GITHUB_OWNER_URL) }
      }),
      new CustomItemInfo({
        icon: $rawfile('kelan_kl.png'),
        title: 'kelanKL',
        subtitle: $r('app.string.icon_drawing'),
        type: ItemActionType.ROUTER,
        id: 'contributor_kelan_kl',
        onChange: () => { JumpUtil.goToWeb('https://github.com/kelanKL') }
      }),
      new CustomItemInfo({
        icon: $rawfile('liluolinder.jfif'),
        title: 'linderSeline',
        subtitle: $r('app.string.project_maintenance'),
        type: ItemActionType.ROUTER,
        id: 'contributor_liluolinder',
        onChange: () => { JumpUtil.goToWeb('https://github.com/liluolinder') }
      }),
      new CustomItemInfo({
        icon: $rawfile('summer_kaze.jfif'),
        title: 'SummerKaze',
        subtitle: $r('app.string.project_maintenance'),
        type: ItemActionType.ROUTER,
        id: 'contributor_summer_kaze',
        onChange: () => { JumpUtil.goToWeb('https://github.com/SummerKaze') }
      }),
      new CustomItemInfo({
        icon: $rawfile('crazypig321.jfif'),
        title: 'crazypig321',
        subtitle: $r('app.string.project_maintenance'),
        type: ItemActionType.ROUTER,
        id: 'contributor_crazypig321',
        onChange: () => { JumpUtil.goToWeb('https://github.com/crazypig321') }
      }),
      // 致谢组
      new CustomItemInfo({ id: 'thanks', title: $r('app.string.thanks'), type: ItemActionType.GROUP }),
      new CustomItemInfo({
        icon: $rawfile('pixez_flutter.png'),
        title: 'Pixez-Flutter',
        subtitle: '优秀开源项目，架构与业务设计参考',
        type: ItemActionType.ROUTER,
        id: 'thanks_pixez_flutter',
        onChange: () => { JumpUtil.goToWeb('https://github.com/Notsfsssf/pixez-flutter') }
      }),
      new CustomItemInfo({
        icon: $rawfile('pixivpy.png'),
        title: 'PixivPy',
        subtitle: 'API协议与签名逻辑参考',
        type: ItemActionType.ROUTER,
        id: 'thanks_pixivpy',
        onChange: () => { JumpUtil.goToWeb('https://github.com/upbit/pixivpy') }
      }),

      // 法律声明组
      new CustomItemInfo({ id: 'legal', title: $r('app.string.legal'), type: ItemActionType.GROUP }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.doc_text_fill'),
        title: $r('app.string.open_source_license'),
        subtitle: 'GPL-3.0',
        type: ItemActionType.ROUTER,
        id: 'license',
        onChange: () => {
          toastUtil.showAlertDialog({
            title: $r('app.string.open_source_license'),
            message: '本项目基于 GNU General Public License v3.0 开源，你可自由使用、修改和分发，但衍生作品需以相同协议开源。',
            alignment: DialogAlignment.Center,
            primaryButton: { value: 'OK', action: () => {} }
          })
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.exclamationmark_shield_fill'),
        title: $r('app.string.disclaimer'),
        type: ItemActionType.ROUTER,
        id: 'disclaimer',
        onChange: () => {
          toastUtil.showAlertDialog({
            title: $r('app.string.disclaimer'),
            message: 'Pixark 是非官方第三方客户端，与 Pixiv Inc. 无任何从属关系。本项目仅供学习交流，请勿用于商业用途。使用本软件所产生的一切风险与责任由使用者自行承担，请遵守 Pixiv 官方服务条款及相关法律法规。',
            alignment: DialogAlignment.Center,
            primaryButton: { value: 'OK', action: () => {} }
          })
        }
      })
    ]
  }

  build() {
    NaviContainer({
      title: $r('app.string.about'),
      content: () => { this.Content() },
      onReady: (ctx) => { this.pageStack = ctx.pathStack },
      onBackPressed: () => false,
      onNaviDisAppear: () => {}
    })
  }

  @Builder
  Content() {
    Column() {
      List({ space: 16 }) {
        // 顶部应用图标 Header
        ListItem() {
          this.AppHeader()
        }
        // 渲染分组列表
        ForEach(makeItemGroups(this.itemList), (group: ItemGroupData) => {
          ListItemGroup({ header: group.group?.title ? this.GroupHeader(group.group.title) : undefined }) {
            ForEach(group.items, (item: CustomItemInfo) => {
              ListItem() {
                CustomListItem({ item: item, itemPadding: { left: 16, right: 16, top: 12, bottom: 12 } })
              }
            })
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .contentEndOffset(PixState.bottomRectHeight || 28)
    }
    .width('100%')
    .height('100%')
    .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue })
  }

  /**
   * 顶部应用图标与名称
   */
  @Builder
  AppHeader() {
    Column({ space: 12 }) {
      Image($r('app.media.app_icon'))
        .width(80)
        .height(80)
        .borderRadius(20)
        .margin({ top: 12 })

      Image($r('app.media.pixark_art'))
        .width(186)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 16, bottom: 16 })
  }

  /**
   * 分组标题
   */
  @Builder
  GroupHeader(title: ResourceStr) {
    Text(title)
      .fontSize(14)
      .width('100%')
      .padding({ left: 4, top: 8, bottom: 4 })
      .fontColor($r('sys.color.font_secondary'))
  }

}
