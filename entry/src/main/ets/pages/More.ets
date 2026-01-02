import { PixState } from "../entryability/AppState";
import { createLogger } from "../utils/Logger";

const logger = createLogger('More')

@ComponentV2
export struct More {

  build() {
    Column() {
      Text($r('app.string.more'))
    }
    .size({ width: '100%', height: '100%'})
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }

}