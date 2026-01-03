import { PixState } from '../entryability/AppState';
import { PixivIllust, PixivUser, SpotlightArticle, SpotlightResponse, PixivListResult } from '../services/PixivTypes';
import { createLogger } from '../utils/Logger';
import { BusinessError } from '@kit.BasicServicesKit';

const logger = createLogger('HomeViewModel')

@ObservedV2
class HomeViewModel {

  @Trace spotlightList: SpotlightArticle[] = []; // 亮点列表
  @Trace recommendedUsers: PixivUser[] = [];      // 推荐作者列表
  @Trace recommendedIllusts: PixivIllust[] = [];  // 推荐图片列表

  // 外层 List 的滚动控制器
  listScroller: Scroller = new Scroller();

  // 嵌套滚动配置
  // 决定了外层 List 如何响应内部 WaterFlow 的滚动事件
  get nestedScrollOptions(): NestedScrollOptions {
    return {
      scrollForward: NestedScrollMode.PARENT_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST,
    };
  }

  async loadHomeData() {
    // 开始日志
    logger.debug('>>> 开始加载首页数据...');

    try {
      // 检查登录状态
      if (!PixState.pixiv.isLogin()) {
        logger.warn('>>> 用户未登录，停止加载');
        return;
      }
      logger.debug('>>> 用户已登录，开始并发请求推荐接口');

      // 构建并发任务 (注意：这里不要用 await，否则就变成串行了)
      const tasks: [Promise<SpotlightResponse>, Promise<PixivListResult>] = [
        PixState.pixiv.getSpotlight(),
        PixState.pixiv.getRecommended(true)
      ];

      // 等待所有任务完成
      const results: [SpotlightResponse, PixivListResult] = await Promise.all(tasks);
      logger.debug('>>> 所有接口请求成功返回');

      // 处理亮点数据
      const spotlightData = results[0];
      if (spotlightData.spotlight_articles) {
        this.spotlightList = spotlightData.spotlight_articles;
        logger.debug(`>>> 亮点文章加载完毕，数量: ${this.spotlightList.length}`);
      } else {
        logger.warn('>>> 亮点文章数据为空');
      }

      // 处理推荐图片
      const recData = results[1];
      if (recData.illusts) {
        this.recommendedIllusts = recData.illusts;
        logger.debug(`>>> 推荐插画加载完毕，数量: ${this.recommendedIllusts.length}`);
      }

      // 提取推荐作者逻辑
      const userMap = new Map<number, PixivUser>();
      recData.illusts.forEach(illust => {
        // 取前 10 个推荐作者
        if (!userMap.has(illust.user.id) && userMap.size < 10) {
          userMap.set(illust.user.id, illust.user);
        }
      });

      const extractedUsers = Array.from(userMap.values());
      this.recommendedUsers = extractedUsers;

      // 打印作者信息，确认提取是否正确
      logger.info(`>>> 提取去重后的推荐作者，数量: ${this.recommendedUsers.length}`);
      if (this.recommendedUsers.length > 0) {
        // 打印第一个作者的名字，方便验证
        logger.debug(`>>> 第一个推荐作者 ID: ${this.recommendedUsers[0].id}, 名字: ${this.recommendedUsers[0].name}`);
      }

      logger.debug('>>> 首页数据加载流程全部结束');

    } catch (e) {
      const err = e as BusinessError;
      logger.error(`!!! 加载首页数据失败: code[${err.code}], msg[${err.message}]`);
    }
  }

}

export const homeViewModel =  new HomeViewModel();
