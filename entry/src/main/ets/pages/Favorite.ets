import { PixState } from "../entryability/AppState";
import { createLogger } from "../utils/Logger";

const logger = createLogger('Favorite')

@ComponentV2
export struct Favorite {

  build() {
    Column() {
      Text($r('app.string.favorite'))
    }
    .size({ width: '100%', height: '100%'})
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }

}