import { PixState } from "../entryability/AppState";
import { createLogger } from "../common/utils/Logger";

const logger = createLogger('Rank')

@ComponentV2
export struct Rank {

  build() {
    Column() {
      Text($r('app.string.rank'))
    }
    .size({ width: '100%', height: '100%'})
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }

}