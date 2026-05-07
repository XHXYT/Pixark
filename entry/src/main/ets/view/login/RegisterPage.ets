import { webview } from "@kit.ArkWeb";
import { PixState } from "../../entryability/AppState";
import { createLogger } from "../../utils/Logger";

const logger = createLogger('Register')

@Builder
export function RegisterPage() {
  RegisterPageComponent()
}

@ComponentV2
struct RegisterPageComponent {

  webviewController: webview.WebviewController = new webview.WebviewController();

  build() {
    NavDestination() {
      Web({ src: 'https://accounts.pixiv.net/signup', controller: this.webviewController })
        .domStorageAccess(true)
        .javaScriptAccess(true)
        .width('100%')
        .layoutWeight(1)
    }
    .padding({ top: PixState.topRectHeight, bottom: PixState.bottomRectHeight })
    .hideToolBar(true)
    .title('注册')
  }
}
