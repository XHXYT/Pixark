import { TabBuild } from "../entity/IndexEntity";
import { PixState } from "../entryability/AppState";
import { createLogger } from "../utils/Logger";

const logger = createLogger('Favorite')

@ComponentV2
export struct Favorite {

  build() {
    Column() {

    }
    .size({ width: '100%', height: '100%'})
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
  }

  getTabList(): TabBuild[] {
    const tabList: TabBuild[] = [
      { name: $r('app.string.trend') },
      { name: $r('app.string.collection') },
      // { name: $r('app.string.search') },
      { name: $r('app.string.followed') },
    ]
    return tabList
  }

}