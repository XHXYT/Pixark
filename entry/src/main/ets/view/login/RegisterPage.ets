import { webview } from "@kit.ArkWeb";
import { PixState } from "../../entryability/AppState";
import { createLogger } from "../../common/utils/Logger";
import { NaviContainer } from "../../components/NaviContainer";
import { AppConstants } from "../../common/constants/AppConstants";

const logger = createLogger('Register')

@Builder
export function RegisterPage() {
  RegisterPageComponent()
}

@ComponentV2
struct RegisterPageComponent {

  webviewController: webview.WebviewController = new webview.WebviewController();

  build() {
    NaviContainer({
      title: $r('app.string.register'),
      content: () => {
        this.Content()
      }
    })
  }

  @Builder
  Content() {
    Web({ src: AppConstants.REGISTER_URL, controller: this.webviewController })
      .domStorageAccess(true)
      .javaScriptAccess(true)
      .width('100%')
      .layoutWeight(1)
  }

}
