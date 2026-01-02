import { PixState } from "../entryability/AppState";
import { createLogger } from "../utils/Logger";

const logger = createLogger('SearchPage')

@ComponentV2
export struct SearchPage {

  @Local keyword: string = '';

  build() {
    Row() {
      TextInput({ placeholder: '搜索关键词' })
        .onChange(v => this.keyword = v)
        .layoutWeight(1)
        .margin({ right: 8 });

      Button('搜索')
        .onClick(() => {
          logger.info('Search button clicked. Keyword: ' + this.keyword);
          this.doSearch();
        });
    }
    .margin({ bottom: 12 });
  }

  async doSearch() {
    logger.info('doSearch start.');
    if (!this.keyword) {
      logger.warn('Search keyword is empty.');
      return;
    }
    PixState.isLoading = true;
    try {
      const res = await PixState.pixiv.searchIllust(this.keyword);
      // this.results = res.illusts;
      // logger.info('Search data loaded. Count: ' + this.results.length);
    } catch (e) {
      logger.error('Search process error: ' + JSON.stringify(e));
    } finally {
      PixState.isLoading = false;
    }
  }

}