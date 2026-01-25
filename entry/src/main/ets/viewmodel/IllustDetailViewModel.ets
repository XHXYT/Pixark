import { PixState } from '../entryability/AppState';
import { PixivIllust, PixivImage } from '../services/PixivTypes';
import { createLogger } from '../utils/Logger';
import { LongTakeAnimationProperties } from '../utils/customtransition/LongTakeAnimationProperties';
import { CustomTransition } from '../utils/customtransition/CustomNavigationUtils';
import { homeViewModel } from './HomeViewModel';
import { DetailPageParams } from '../entity/IllustDetailEntity';
import { CardUtil } from '../utils/CardUtil';

const logger = createLogger('IllustDetailViewModel')

@ObservedV2
class IllustDetailViewModel {

  @Trace detailData: PixivIllust | null = null;
  private nextRelatedUrl: string | null = null
  // 相关图片推荐
  @Trace relatedIllusts: PixivIllust[] = []
  @Trace isFollow: boolean = false
  // 当前浏览的大图索引（瀑布流列表索引）
  @Trace currentIndex: number = 0;
  @Trace sharedId: string = ''
  @Trace longTakeAnimationProperties: LongTakeAnimationProperties = new LongTakeAnimationProperties();

  // 图片 URL 数组
  get imageList(): PixivImage[] {
    if (!this.detailData) return [];
    // 检查是否有 meta_pages (多图)
    if (this.detailData.meta_pages && this.detailData.meta_pages.length > 0) {
      return this.detailData.meta_pages.map(page => page.image_urls);
    }
    // 单图情况，取 image_urls.large
    if (this.detailData.image_urls?.large) {
      return [this.detailData.image_urls];
    }
    return [];
  }

  async loadIllustDetail(id: number) {
    try {
      logger.debug(`>>> 开始加载插画详情, ID: ${id}`);
      this.detailData = await PixState.pixiv.getIllustDetail(id);
      logger.debug(`>>> 详情加载完毕, 图片: ${JSON.stringify(this.imageList.map(image => image.medium))}`);
    } catch (e) {
      logger.error(`!!! 加载详情失败: ${JSON.stringify(e)}`);
    }
  }

  async loadRelated(id: number) {
    try {
      const data = await PixState.pixiv.getRelatedIllusts(id);
      this.relatedIllusts = data.illusts;
      this.nextRelatedUrl = data.next_url
    } catch (e) {
      console.error(e);
    }
  }

  // 处理动画初始化逻辑
  handleTransitionReady(ctx: NavDestinationContext, params: DetailPageParams) {
    const fromId = params.fromId as string;
    const pageId = ctx.navDestinationId;
    if (!pageId || !fromId) {
      // 如果没有 fromId，说明不是通过卡片点击进入的，直接设置最终状态
      this.longTakeAnimationProperties.setFinalStatus();
      return;
    }
    this.sharedId = CardUtil.getPostPageImageId(fromId) || fromId;
    // 初始化动画参数
    // 第二个参数：动画结束时的回调 -> 恢复首页卡片显示
    this.longTakeAnimationProperties.init(fromId, () => {
      homeViewModel.restoreIllustVisibility();
    });
    // 注册自定义转场
    CustomTransition.getInstance().registerNavParam(pageId, 2000, (proxy: NavigationTransitionProxy) => {
      // 执行动画
      this.longTakeAnimationProperties.doAnimation(proxy);
    });
  }

  onReady(ctx: NavDestinationContext) {
    // 接收信息
    try {
      const params: DetailPageParams = ctx?.pathInfo?.param as DetailPageParams
      this.detailData = params.illust
      this.handleTransitionReady(ctx, params)
      // 使用插画id加载插画列表
      this.loadIllustDetail(params.id)
      // 使用插画id加载推荐插画
      this.loadRelated(params.id)
      logger.debug('#onReady 插画详情页接收的params：', JSON.stringify(params))
    } catch (e) {
      logger.error(`#onReady 插画详情页 Navigate onReady catch exception: ${JSON.stringify(e)}`)
    }
  }

  async followOrCancel() {
    if (this.isFollow) {
      // 取消关注
      await PixState.pixiv.unfollowUser(this.detailData?.user.id)
      this.isFollow = false
    } else {
      // 关注
      await PixState.pixiv.followUser(this.detailData?.user.id)
      this.isFollow = true
    }
  }

  /**
   * 格式化日期字符串 2026-01-01T00:00:00+09:00 -> 2023-01-01 00:00:00
   */
  formatDate(dateStr: string): string {
    logger.debug(`>>> 初始时间, dateStr: ${JSON.stringify(dateStr)}`);
    if (!dateStr) return '';
    // 将字符串转换为 Date 对象 (会自动处理时区，转换为你设备的本地时间)
    const date = new Date(dateStr);
    // 防止无效日期
    if (isNaN(date.getTime())) return dateStr;
    // 定义补零函数 (例如 5 -> "05")
    const pad = (n: number) => n.toString().padStart(2, '0');
    // 提取各个时间部分
    const year = date.getFullYear();
    // getMonth() 返回 0-11，所以要 +1
    const month = pad(date.getMonth() + 1);
    const day = pad(date.getDate());
    const hours = pad(date.getHours());
    const minutes = pad(date.getMinutes());
    const seconds = pad(date.getSeconds());

    // 拼接返回
    return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
  }

}

export const iDV = new IllustDetailViewModel();
