import { common, Want, wantConstant } from "@kit.AbilityKit"

/**
 * 跳转工具类（隐式Want跳转、邮件等）
 */
export class JumpUtil {
  // 私有静态变量，存储外部传入的 UIAbilityContext
  private static context: common.UIAbilityContext | null = null;

  /**
   * 初始化工具类，注入 UIAbilityContext
   *
   * @param context UIAbilityContext
   */
  static init(context: common.UIAbilityContext): void {
    JumpUtil.context = context;
  }

  /**
   * 获取 Context，如果未初始化则抛出错误提示
   */
  private static getContext(): common.UIAbilityContext {
    if (!JumpUtil.context) {
      throw new Error("[JumpUtil] Context 未初始化，请先调用 JumpUtil.init(context)");
    }
    return JumpUtil.context;
  }

  /**
   * 隐式 Want 跳转网站
   *
   * @param url 要跳转的网址
   */
  static async goToWeb(url: string): Promise<void> {
    try {
      let want: Want = {
        // 如果希望仅在特定包中隐式查询，请取消下面的注释行
        // bundleName: "com.example.myapplication",
        action: "ohos.want.action.viewData",
        entities: ["entity.system.browsable"],
        uri: url,
      }
      await JumpUtil.getContext().startAbility(want);
      console.info(`[JumpUtil] goToWeb succeed: ${url}`);
    } catch (error) {
      console.error(`[JumpUtil] goToWeb failed: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 拉起邮件类应用（mailto方式）
   *
   * @param address 填写示例：mailto:xfz347@gmail.com?subject=反馈&body=你的内容...
   */
  static async handleMailto(address: string): Promise<void> {
    try {
      let want: Want = {
        action: 'ohos.want.action.sendToData',
        uri: address,
      }
      await JumpUtil.getContext().startAbility(want);
      console.info(`[JumpUtil] handleMailto succeed: ${address}`);
    } catch (error) {
      console.error(`[JumpUtil] handleMailto failed: ${JSON.stringify(error)}`);
    }
  }

  /**
   * 拉起邮件类应用（Want方式，支持更丰富的参数）
   *
   * @param email 收件人邮箱
   * @param subject 邮件主题
   * @param content 邮件正文
   */
  static handleMail(email: string, subject: string, content: string): void {
    let wantParam: Record<string, Object> = {
      'sceneType': 1,
      // 收件人邮箱地址，多值以逗号分隔，对数组内容使用encodeURI()方法进行url编码
      'email': [encodeURI(email)],
      // 抄收人邮箱地址，多值以逗号分隔
      // 'cc': [encodeURI('xxx@example.com'),encodeURI('xxx@example.com')],
      // 密送人邮箱地址，多值以逗号分隔
      // 'bcc': [encodeURI('xxx@example.com'),encodeURI('xxx@example.com')],
      // 邮件主题，对内容使用encodeURI()方法进行url编码
      'subject': encodeURI(subject),
      // 邮件正文，对内容使用encodeURI()方法进行url编码
      'body': encodeURI(content),
      // 附件uri，多值以逗号分隔
      // 'ability.params.stream': [encodeURI('附件uri1'),encodeURI('附件uri2')],
      'ability.want.params.uriPermissionFlag': wantConstant.Flags.FLAG_AUTH_READ_URI_PERMISSION
    };

    let abilityStartCallback: common.AbilityStartCallback = {
      onError: (code: number, name: string, message: string) => {
        console.error(`[JumpUtil] handleMail onError code: ${code} name: ${name} message: ${message}`);
      },
      onResult: (result) => {
        console.info(`[JumpUtil] handleMail onResult result: ${JSON.stringify(result)}`);
      }
    }

    JumpUtil.getContext().startAbilityByType("mail", wantParam, abilityStartCallback, (err) => {
      if (err) {
        console.error(`[JumpUtil] handleMail startAbilityByType fail, err: ${JSON.stringify(err)}`);
      } else {
        console.info(`[JumpUtil] handleMail startAbilityByType success`);
      }
    });
  }

}
