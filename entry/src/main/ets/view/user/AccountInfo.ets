import { CustomItemInfo, ItemActionType } from '../../common/entity/CusItemInfo';
import { NaviContainer } from '../../components/NaviContainer';
import { PixState } from '../../entryability/AppState';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import { CustomListItem } from '../../components/CusItemBuilder';
import { pixiv } from '../../services/PixivService';
import { toastUtil } from '../../common/utils/ToastUtils';
import { clipboard } from '../../common/utils/ClipBoardUtil';


@Builder
export function AccountInfoBuilder() {
  AccountInfo()
}

@ComponentV2
export struct AccountInfo {
  @Local currentPassword: string = '';
  @Local newPassword: string = '';
  @Local mailAddress: string = PixState.currentUser?.mail_address || '';
  @Local isRefreshing: boolean = false;

  build() {
    NaviContainer({
      title: $r('app.string.account_info'),
      content: () => {
        this.Content()
      },
      buttons: [{
        value: '',
        symbolIcon: new SymbolGlyphModifier($r('sys.symbol.save')),
        action: () => {
          this.saveAction()
        }
      }],
      onReady: (ctx) => {
      }
    })
  }

  // 保存操作：调用修改密码/邮箱 API
  private async saveAction() {
    // 校验：当前密码必填
    if (!this.currentPassword) {
      toastUtil.showToast({ message: '请输入当前密码以验证身份' });
      return;
    }
    // 校验：邮箱格式 (如果已填写)
    if (this.mailAddress && !this.mailAddress.includes('@')) {
      toastUtil.showToast({ message: '邮箱格式不正确' });
      return;
    }

    this.isRefreshing = true;
    try {
      // 调用 API
      const success = await pixiv.editAccount(
        this.currentPassword,
        this.mailAddress,    // 传修改后的邮箱
        this.newPassword || undefined // 如果没填新密码则不传
      );

      if (success) {
        toastUtil.showToast({ message: '修改成功' });
        // 更新本地全局状态
        if (PixState.currentUser) {
          PixState.currentUser.mail_address = this.mailAddress;
        }
        // 修改成功后清空密码框
        this.currentPassword = '';
        this.newPassword = '';
      }
    } catch (error) {
      // 捕获 API 返回的验证错误 (如密码错误)
      toastUtil.showToast({ message: `修改失败: ${error}` });
    } finally {
      this.isRefreshing = false;
    }
  }

  private get itemList(): CustomItemInfo[] {
    const currentUser = PixState.currentUser;
    const activeAccount = pixiv?.getActiveAccount();
    // 判断是否是邮箱授权登录 (如果不是，则自动填入旧密码)
    const isMailAuthorized = activeAccount?.isMailAuthorized === 1;
    const savedPassword = isMailAuthorized ? '' : (activeAccount?.passWord || '');

    return [
      // 账号 ID (只读)
      new CustomItemInfo({
        id: 'account',
        title: $r('app.string.account'),
        type: ItemActionType.INPUT,
        enabled: false,
        value: currentUser?.account || activeAccount?.userId || ''
      }),

      // 旧密码 (必填验证身份)
      new CustomItemInfo({
        title: $r('app.string.old_password'),
        type: ItemActionType.INPUT,
        id: 'old_password',
        value: savedPassword, // 如果本地有保存则自动填入
        subtitle: '修改信息需验证当前密码',
        onChange: (value: string | boolean | number) => {
          this.currentPassword = value as string;
        }
      }),

      // 新密码 (可选)
      new CustomItemInfo({
        title: $r('app.string.new_password'),
        type: ItemActionType.INPUT,
        id: 'new_password',
        value: '',
        subtitle: '不修改请留空',
        onChange: (value: string | boolean | number) => {
          this.newPassword = value as string;
        }
      }),

      // 邮箱地址 (可编辑)
      new CustomItemInfo({
        title: $r('app.string.mail_address'),
        type: ItemActionType.INPUT,
        id: 'mail_address',
        value: this.mailAddress,
        onChange: (value: string | boolean | number) => {
          this.mailAddress = value as string;
        }
      }),

      // 导出 Token (仅当邮箱授权登录时显示，参考 PixEz 逻辑)
      new CustomItemInfo({
        title: '导出 Token',
        type: ItemActionType.TEXT,
        id: 'export_token',
        value: activeAccount?.refreshToken ? '点击复制' : '未登录',
        enabled: isMailAuthorized, // 根据 PixEz 逻辑，仅邮箱登录可导出
        onChange: (value: string | boolean | number) => {
          if (activeAccount?.refreshToken) {
            clipboard.copyData(activeAccount.refreshToken);
            toastUtil.showToast({ message: 'Refresh Token 已复制到剪贴板' });
          }
        }
      }),

      // 注销账号 (高危操作，标红)
      new CustomItemInfo({
        title: '注销账号',
        type: ItemActionType.ROUTER,
        id: 'account_deletion',
        isDanger: true,
        subtitle: '将跳转至注销页面',
        onChange: (value: string | boolean | number) => {
          // 这里参考 PixEz，跳转到注销网页或弹出确认框
          toastUtil.showToast({ message: '功能开发中：注销账号' });
        }
      })
    ]
  }

  @Builder
  Content() {
    List() {
      Repeat<CustomItemInfo>(this.itemList)
        .each((ri: RepeatItem<CustomItemInfo>) => {
          ListItem() {
            CustomListItem({
              item: ri.item,
              itemPadding: { left: 16, right: 16, top: 8, bottom: 8 }
            })
          }
        })
        .key((item: CustomItemInfo) => item.id)
    }
    .width('100%')
  }

}
