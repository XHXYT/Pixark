import { webview } from "@kit.ArkWeb";
import { createLogger } from "../utils/Logger";

const logger = createLogger('Register')

@Builder
export function RegisterPage() {
  RegisterPageComponent()
}

@ComponentV2
struct RegisterPageComponent {

  webviewController: webview.WebviewController = new webview.WebviewController();

  build() {
    Column() {
      Web({ src: 'https://accounts.pixiv.net/signup', controller: this.webviewController })
        .domStorageAccess(true)
        .javaScriptAccess(true)
        .width('100%')
        .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }
}
