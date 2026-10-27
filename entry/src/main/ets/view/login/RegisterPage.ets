import { webview } from "@kit.ArkWeb";
import { PixState } from "../../entryability/AppState";
import { createLogger } from "../../common/utils/Logger";
import { NaviContainer } from "../../components/NaviContainer";
import { AppConstants } from "../../common/constants/AppConstants";
import { installWebSchemeHandler } from "../../services/direct/WebDirect";

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
      .onControllerAttached(() => {
        try {
          // 直连桥：Pixiv 域名（ECH/COMPAT 模式）接管 WebView 网络层
          installWebSchemeHandler(this.webviewController);
        } catch (error) {
          logger.error(`install scheme handler failed: ${JSON.stringify(error)}`);
        }
      })
      .width('100%')
      .layoutWeight(1)
  }

}
