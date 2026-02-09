import { PixState } from "../../entryability/AppState";
import { createLogger } from "../../utils/Logger";

const logger = createLogger('DownloadManager')

@Builder
export function DownloadManagerBuilder() {
  // 路由名称: download_manager
  DownloadManager()
}

@ComponentV2
struct DownloadManager {

  build() {
    NavDestination() {
    }
    .padding({ top: PixState.topRectHeight, bottom: PixState.bottomRectHeight })
    .hideBackButton(true)
    .hideTitleBar(true)
    .hideToolBar(true)
  }
}

