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


@ComponentV2
export struct More {

  private pageStack: NavPathStack = new NavPathStack()

  private get itemList(): CustomItemInfo[] {
    return [
      // 功能
      new CustomItemInfo({
        id: 'function',
        label: '功能',
        type: ItemActionType.GROUP
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.person_crop_circle_fill'),
        label: $r('app.string.account_info'),
        type: ItemActionType.ROUTER_BLANK,
        id: 'account_info',
        onChange: (value) => {
          this.pushTo('account_info')
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.arrow_counterclockwise_clock'),
        label: $r('app.string.history'),
        type: ItemActionType.ROUTER_BLANK,
        id: 'illust_history',
        onChange: (value) => {
          toastUtil.showToast({ message: '历史记录功能开发中' })
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.gearshape_fill'),
        label: $r('app.string.preference'),
        type: ItemActionType.ROUTER_BLANK,
        id: 'settings',
        onChange: (value) => {
          toastUtil.showToast({ message: '偏好设置功能开发中' })
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.arrow_down_circle'),
        label: $r('app.string.download_manage'),
        type: ItemActionType.ROUTER_BLANK,
        id: 'download_manager',
        onChange: (value) => {
          this.pushTo('download_manager');
        }
      }),
      new CustomItemInfo({
        symbol: $r('sys.symbol.folder_circle'),
        label: $r('app.string.app_data'),
        type: ItemActionType.ROUTER_BLANK,
        id: 'app_data',
        onChange: (value) => {
          toastUtil.showToast({ message: '应用数据功能开发中' })
        }
      }),
      // 其他
      new CustomItemInfo({
        id: 'other',
        label: '其他',
        type: ItemActionType.GROUP
      }),
      // 关于
      new CustomItemInfo({
        symbol: $r('sys.symbol.info_circle'),
        label:$r('app.string.about'),
        type: ItemActionType.ROUTER_BLANK,
        id: 'about',
        onChange: (value) => {
          toastUtil.showToast({ message: '关于功能开发中' })
        }
      }),
      new CustomItemInfo({
        id: 'other_1',
        label: '',
        type: ItemActionType.GROUP
      }),
      // 退出登录
      new CustomItemInfo({
        symbol: $r('sys.symbol.arrow_left_circle'),
        label:$r('app.string.logout'),
        type: ItemActionType.ROUTER_BLANK,
        id: 'exit_account',
        onChange: (value) => {
          this.showLogoutDialog()
        },
        isDanger: true
      }),
    ];
  }

  build() {
    Column() {
      Column({ space: 20 }) {
        // 用户信息卡片
        this.UserProfileHeader()
        // 功能列表
        List({ space: 12 }) {
          ForEach(makeItemGroups(this.itemList), (group: ItemGroupData) => {
            ListItemGroup({
              // 如果分组项有 label 则渲染头部，否则不渲染
              header: group.group?.label ? this.GroupHeader(group.group.label) : undefined
            }) {
              ForEach(group.items, (item: CustomItemInfo) => {
                ListItem() {
                  // this.MoreItemView(item)
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
      if (moreVM.isLogin) {
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
      title: '提示',
      message: $r('app.string.confirm_logout').toString(),
      buttons: [
        { text: $r('app.string.cancel'), color: '#999999' },
        { text: '退出', color: '#FF0000' }
      ]
    }, (err, data) => {
      if (data?.index === 1) {
        moreVM.handleLogout();
      }
    });
  }

  pushTo(name: string, params?: UserDetailParams) {
    if (PixState.widthBp > 1) {
      this.pageStack.pushPathByName(name, params, true);
    } else {
      // 全屏路由
      PixState.pageStack.pushPathByName(name, params, true);
    }
  }

}
