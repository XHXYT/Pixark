import { moreVM } from '../viewmodel/MoreViewModel';
import { PixivImageComponent } from '../components/PixivImage';
import { PixState } from '../entryability/AppState';
import { toastUtil } from '../utils/ToastUtils';
import { MoreItem } from '../entity/MoreItemEntity';
import { UserDetailParams } from '../entity/UserDetailEntity';
import { maskEmail } from '../utils/MaskEmail';


@ComponentV2
export struct More {

  // 构建菜单数据
  private get menuList(): MoreItem[] {
    return [
      {
        symbol: $r('sys.symbol.person_crop_circle_fill'),
        label: $r('app.string.account_info'),
        name: 'account',
        action: () => {
          // TODO 多账号切换页
        }
      },
      {
        symbol: $r('sys.symbol.arrow_counterclockwise_clock'),
        label: $r('app.string.history'),
        name: 'illust_history',
        action: () => {
          toastUtil.showToast({ message: '历史记录功能开发中' })
        }
      },
      {
        symbol: $r('sys.symbol.gearshape_fill'),
        label: $r('app.string.preference'),
        name: 'settings',
        action: () => {
          toastUtil.showToast({ message: '偏好设置功能开发中' })
        }
      },
      {
        symbol: $r('sys.symbol.arrow_down_circle'),
        label: $r('app.string.download_manage'),
        name: 'download_manager',
        action: () => {

        }
      },
      {
        symbol: $r('sys.symbol.folder_circle'),
        label: $r('app.string.app_data'),
        name: 'app_data',
        action: () => {
          toastUtil.showToast({ message: '应用数据功能开发中' })
        }
      },
    ];
  }

  build() {
    Column() {
      Column({ space: 20 }) {
        // 用户信息卡片
        this.UserProfileHeader()
        // 功能列表
        List({ space: 12 }) {
          // 常规功能
          ListItemGroup({ header: this.GroupHeader('功能') }) {
            ForEach(this.menuList, (item: MoreItem) => {
              ListItem() {
                this.MoreItemView(item)
              }
            })
          }
          // 关于
          ListItemGroup({ header: this.GroupHeader('其他') }) {
            ListItem() {
              this.MoreItemView({
                symbol: $r('sys.symbol.info_circle'),
                label: $r('app.string.about'),
                name: 'about',
                action: () => {
                  toastUtil.showToast({ message: '关于功能开发中' })
                }
              })
            }
          }
          // 退出登录
          ListItemGroup() {
            ListItem() {
              this.MoreItemView({
                symbol: $r('sys.symbol.arrow_left_circle'),
                label: $r('app.string.logout'),
                name: 'exit_account',
                action: () => {
                  this.showLogoutDialog()
                },
                isDanger: true
              })
            }
          }
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
      if (moreVM.currentUser) {
        const params: UserDetailParams = { id: moreVM.currentUser.id };
        PixState.pageStack.pushPathByName('user_detail', params, true);
      } else {
        toastUtil.showToast({ message: '请先登录' });
      }
    })
  }

  @Builder
  GroupHeader(title: string) {
    Text(title)
      .fontSize(14)
      .width('100%')
      .padding({ left: 2 })
      .fontColor($r('sys.color.font_secondary'))
  }

  @Builder
  MoreItemView(item: MoreItem) {
    Row({ space: 12 }) {
      // 图标
      SymbolGlyph(item.symbol)
        .fontSize(22)
        .fontColor([item.isDanger ? Color.Red : $r('sys.color.icon_emphasize')])
      // 标题
      Text(item.label)
        .fontSize(16)
        .fontColor(item.isDanger ? Color.Red : $r('sys.color.font_primary'))
        .layoutWeight(1)
      // 箭头
      SymbolGlyph($r('sys.symbol.chevron_forward'))
        .fontSize(18)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .padding({top: 14, bottom: 14 })
    .onClick(() => {
      item.action();
      // TODO
      if (item.name == 'download_manager') {
        PixState.pageStack.pushPathByName(item.name, undefined, true);
      }
    })
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
}
