import { moreVM } from '../viewmodel/MoreViewModel';
import { PixivImageComponent } from '../components/PixivImage';
import { PixState } from '../entryability/AppState';
import { toastUtil } from '../common/utils/ToastUtils';
import { CustomItemInfo, ItemActionType,
  ItemGroupData,
  makeItemGroups } from '../common/entity/CusItemInfo';
import { UserDetailParams } from '../common/entity/UserDetailEntity';
import { maskEmail } from '../common/utils/MaskEmail';
import { CustomListItem } from '../components/CusItemBuilder';
import { appSettings } from '../common/entity/SettingsModel';


@ComponentV2
export struct More {

  private pageStack: NavPathStack = new NavPathStack()

  private get itemList(): CustomItemInfo[] {
    return [
      // 账户
      new CustomItemInfo({ id: 'account', title: $r('app.string.account'), type: ItemActionType.GROUP }),
      // 账户信息
      new CustomItemInfo({
        symbol: $r('sys.symbol.person_crop_circle_fill'),
        title: $r('app.string.account_info'),
        type: ItemActionType.ROUTER_BLANK,
        id: 'account_info',
        onChange: () => {
          this.pushTo('account_info')
        }
      }),
      // 数据
      new CustomItemInfo({ id: 'data', title: $r('app.string.data'), type: ItemActionType.GROUP }),
      // 历史记录
      new CustomItemInfo({
        symbol: $r('sys.symbol.arrow_counterclockwise_clock'),
        title: $r('app.string.history'),
        type: ItemActionType.ROUTER_BLANK,
        id: 'illust_history',
        onChange: () => {
          this.pushTo('illust_history')
        }
      }),
      // 偏好设置
      new CustomItemInfo({
        symbol: $r('sys.symbol.gearshape_fill'),
        title: $r('app.string.preference'),
        type: ItemActionType.ROUTER_BLANK,
        id: 'settings',
        onChange: () => {
          this.pushTo('user_settings')
        }
      }),
      // 下载管理
      new CustomItemInfo({
        symbol: $r('sys.symbol.arrow_down_circle'),
        title: $r('app.string.download_manage'),
        type: ItemActionType.ROUTER_BLANK,
        id: 'download_manager',
        onChange: () => {
          this.pushTo('download_manager');
        }
      }),
      // 应用数据
      new CustomItemInfo({
        symbol: $r('sys.symbol.folder_circle'),
        title: $r('app.string.app_data'),
        type: ItemActionType.ROUTER_BLANK,
        id: 'app_data',
        onChange: () => {
          this.pushTo('app_data');
        }
      }),
      // 功能
      new CustomItemInfo({ id: 'function', title: $r('app.string.function'), type: ItemActionType.GROUP }),
      // 小说
      new CustomItemInfo({
        symbol: $r('sys.symbol.list_book'),
        title: appSettings.novel_mode ? $r('app.string.illust') : $r('app.string.novel'),
        type: ItemActionType.ROUTER_BLANK,
        id: 'novel_mode',
        onChange: () => {
          moreVM.switchMode()
        }
      }),
      // 关于
      new CustomItemInfo({ id: 'about', title: $r('app.string.about'), type: ItemActionType.GROUP }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.info_circle'),
        title:$r('app.string.about'),
        type: ItemActionType.ROUTER_BLANK,
        id: 'about',
        onChange: () => {
          this.pushTo('about');
        }
      }),
      new CustomItemInfo({
        id: 'other_1',
        title: '',
        type: ItemActionType.GROUP
      }),
      // 退出登录
      new CustomItemInfo({
        symbol: $r('sys.symbol.arrow_left_circle'),
        title:$r('app.string.logout'),
        type: ItemActionType.ROUTER_BLANK,
        id: 'exit_account',
        onChange: () => {
          this.showLogoutDialog()
        },
        isDanger: true
      }),
    ];
  }

  build() {
    if (PixState.widthBp > 1) {
      Navigation(this.pageStack) {
        this.Content()
      }
      .size({ width: '100%', height: '100%' })
      .navBarWidth(300)
      .hideTitleBar(true)
      .hideToolBar(true)
    } else {
      this.Content()
    }
  }
  
  @Builder
  Content() {
    Column() {
      Column({ space: 20 }) {
        // 用户信息卡片
        this.UserProfileHeader()
        // 功能列表
        List({ space: 12 }) {
          ForEach(makeItemGroups(this.itemList), (group: ItemGroupData) => {
            ListItemGroup({
              // 如果分组项有 title 则渲染头部，否则不渲染
              header: group.group?.title ? this.GroupHeader(group.group.title) : undefined
            }) {
              ForEach(group.items, (item: CustomItemInfo) => {
                ListItem() {
                  CustomListItem({
                    item: item,
                    itemPadding: { left: 6, bottom: 8, top: 8 }
                  })
                }
              })
            }
          })
        }
        .width('100%')
        .backgroundColor(Color.Transparent)
      }
      .width('100%')
      .padding({ left: PixState.PageMarginValue, right: PixState.PageMarginValue, bottom: 40 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_primary'))
  }

  @Builder
  UserProfileHeader() {
    Row({ space: 16 }) {
      // 头像
      Stack() {
        PixivImageComponent({
          imageUrl: moreVM.avatarUrl,
          imageWidth: 64,
          imageHeight: 64,
          imageBorder: { radius: 32 } // 圆形
        })
          .hitTestBehavior(HitTestMode.Block)
          .onClick(() => {
            if (moreVM.currentUser) {
              const params: UserDetailParams = { id: moreVM.currentUser.id };
              this.pushTo('user_detail', params)
            } else {
              toastUtil.showToast({ message: '请先登录' });
            }
          })
        // 如果未登录，画个半透明遮罩提示点击
        if (!moreVM.isLogin) {
          Text($r('app.string.login'))
            .fontColor(Color.White)
            .fontSize(14)
        }
      }
      // 信息
      Column({ space: 4 }) {
        Text(moreVM.displayName)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        if (moreVM.isLogin) {
          Row({ space: 5 }) {
            Text(moreVM.emailPrivacy ? maskEmail(moreVM.email) : moreVM.email)
              // 不得不说，自带的隐私属性真用不来
              .fontColor($r('sys.color.font_tertiary'))
              .fontSize(14)
              .opacity(0.8)
            Text(!moreVM.emailPrivacy ? $r('app.string.hide') : $r('app.string.show'))
              .fontSize(14)
              .fontColor($r('sys.color.icon_emphasize'))
              .onClick(() => {
                moreVM.emailPrivacy = !moreVM.emailPrivacy
              })
          }
        } else {
          Text('点击登录账号')
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
      if (moreVM.isLogin && PixState.widthBp < 2) {
        SymbolGlyph($r('sys.symbol.chevron_forward'))
          .fontSize(18)
          .fontColor([$r('sys.color.font_tertiary')])
      }
    }
    .margin({ top: 10 })
    .borderRadius(16)
    .width('100%')
    .padding(20)
    .shadow({
      radius: 10,
      color: '#1A000000',
      offsetY: 2
    })
    .onClick(() => {
      this.pushTo('user_accounts')
    })
  }

  @Builder
  GroupHeader(title: ResourceStr) {
    Text(title)
      .fontSize(14)
      .width('100%')
      .padding({ left: 2 })
      .fontColor($r('sys.color.font_secondary'))
  }

  // 退出登录确认弹窗
  showLogoutDialog() {
    toastUtil.showDialog({
      title: $r('app.string.tips'),
      message: $r('app.string.confirm_logout'),
      buttons: [
        { text: $r('app.string.cancel'), color: $r('sys.color.font_secondary') },
        { text: $r('app.string.exit'), color: $r('sys.color.ohos_id_color_warning') }
      ]
    }, (err, data) => {
      if (data?.index === 1) {
        moreVM.handleLogout();
      }
    });
  }

  pushTo(name: string, params?: UserDetailParams) {
    if (PixState.widthBp > 1) {
      this.pageStack.replacePathByName(name, params, true);
    } else {
      // 全屏路由
      PixState.pageStack.pushPathByName(name, params, true);
    }
  }

}
