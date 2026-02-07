import { promptAction } from "@kit.ArkUI"
import { AsyncCallback } from "@kit.BasicServicesKit"
import { BusinessError } from "@kit.BasicServicesKit";
import { common, Want } from "@kit.AbilityKit";

class ToastUtils {
  UIContext: UIContext | undefined
  context: common.UIAbilityContext | undefined

  initContext(UIContext: UIContext, context?: common.UIAbilityContext) {
    this.UIContext = UIContext
    this.context = context
  }

  getResourceString(resource: Resource): string {
    if (this.UIContext) {
      try {
        let resourceString = this.UIContext.getHostContext()!.resourceManager.getStringSync(resource.id);
        return resourceString;
      } catch (err) {
        let error = err as BusinessError;
        console.error('getResourceString', `error code=${error.code}, message=${error.message}`);
        return ''
      }
    } else {
      console.error('px2vp UIContext未初始化')
      return ''
    }
  }

  showToast(options: promptAction.ShowToastOptions) {
    try {
      this.UIContext?.getPromptAction().showToast(options)
    } catch (error) {
      console.error(`发送通知失败 code: ${error.code} message: ${error.message}`)
    }
  }

  animateTo(value: AnimateParam, event: () => void) {
    try {
      this.UIContext?.animateTo(value, event)
    } catch (error) {
      console.error(`执行函数失败 code: ${error.code} message: ${error.message}`)
    }
  }

  px2vp(value: number) {
    if (this.UIContext) {
      return this.UIContext.px2vp(value)
    } else {
      console.error('px2vp UIContext未初始化')
      return value
    }
  }

  showDialog(options: promptAction.ShowDialogOptions, callback: AsyncCallback<promptAction.ShowDialogSuccessResponse, void>, key?: string) {
    try {
      this.UIContext?.getPromptAction().showDialog(options, callback)
    } catch (error) {
      let message = (error as BusinessError).message
      let code = (error as BusinessError).code
      console.error(`${key} showDialog error code is ${code}, message is ${message}`)
    }
  }

  restartApp(abilityName: string = 'EntryAbility') {
    if (this.context) {
      const applicationContext = this.context.getApplicationContext();
      const want: Want = {
        bundleName: this.context.applicationInfo.name, // 包名
        abilityName: abilityName     // 指定重启后拉起的Ability
      };
      try {
        applicationContext.restartApp(want); // 关键重启方法
      } catch (error) {
        console.error(`重启失败: ${JSON.stringify(error)}`);
      }
    } else {
      console.error('restartApp context未初始化')
    }
  }

  exitApp() {
    if (this.context) {
      const applicationContext = this.context.getApplicationContext();
      applicationContext.killAllProcesses().catch((err: BusinessError) => {
        console.error(`应用进程关闭失败，name：${err.name} message: ${err.message}`)
      })
    } else {
      console.error('restartApp context未初始化')
    }
  }

}

export const toastUtil = new ToastUtils()