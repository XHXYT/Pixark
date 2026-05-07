import { PixState, _PixState } from '../entryability/AppState';
import { PixivIllust, PixivImage } from '../services/PixivTypes';
import { createLogger } from '../utils/Logger';
import { LongTakeAnimationProperties } from '../utils/customtransition/LongTakeAnimationProperties';
import { CustomTransition } from '../utils/customtransition/CustomNavigationUtils';
import { homeViewModel } from './HomeViewModel';
import { DetailPageParams } from '../common/entity/IllustDetailEntity';
import { CardUtil } from '../utils/CardUtil';
import { toastUtil } from '../utils/ToastUtils';
import { downloaderVM } from './DownloadsViewModel';
import { common } from '@kit.AbilityKit';

const logger = createLogger('IllustDetailViewModel')

@ObservedV2
export class IllustDetailViewModel {

  @Trace detailData: PixivIllust | null = null;
  private nextRelatedUrl: string | null = null
  // 相关图片推荐
  @Trace relatedIllusts: PixivIllust[] = []

  @Trace isDetailLoading: boolean = false;
  // 关注状态（本地缓存，用于 UI 响应）
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
      // 同步本地关注状态，确保按钮显示正确
      if (this.detailData && this.detailData.user) {
        this.isFollow = this.detailData.user.is_followed;
      }
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

  /**
   * 下载当前图片
   * @param index 如果是多图作品，当前点击的是第几张 (默认为0)
   */
  async downloadCurrentImage(index: number = 0) {
    const context: common.Context = _PixState.Context;
    // const appConfig: APPConfigInfo = Xb_getPersistence(APPConfigInfo)!;
    if (!this.detailData) return;

    // 获取原图 URL
    let originalUrl = this.getOriginalUrl(this.detailData, index)
    if (!originalUrl) {
      toastUtil.showToast({ message: '获取图片地址失败' });
      return;
    }
    logger.debug(`Download 下载链接：${originalUrl}`)
    // 调用全局下载器
    downloaderVM.addTask(context, this.detailData, originalUrl);
  }

  private getOriginalUrl(illust: PixivIllust, index: number = 0): string | null {
    // 多图
    if (illust.meta_pages && illust.meta_pages.length > 0) {
      const page = illust.meta_pages[index];
      if (!page) return null;
      // 优先 original，没有的话回退到 large
      return page.image_urls?.original || page.image_urls?.large || null;
    }
    // 单图
    if (illust.meta_single_page?.original_image_url) {
      return illust.meta_single_page.original_image_url;
    }
    // 兜底：用根 image_urls 的大图
    return illust.image_urls?.large || null;
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
      const id = params.id;
      // 数据处理：如果有传入对象，直接用；否则设为 null 等待加载
      if (params.illust) {
        this.detailData = params.illust;
      } else {
        this.detailData = null; // 确保清空旧数据
      }
      // 同步初始关注状态
      if (this.detailData && this.detailData.user) {
        this.isFollow = this.detailData.user.is_followed;
      }
      // 处理动画
      // 如果有 fromId，说明是从卡片点击进来的，做转场动画
      // 否则（纯ID跳转），直接设置最终状态（无动画直接显示）
      this.handleTransitionReady(ctx, params);
      // 加载数据
      this.isDetailLoading = true;
      this.loadIllustDetail(id).finally(() => {
        this.isDetailLoading = false;
      });
      // 加载推荐
      this.loadRelated(id);
      logger.debug('#onReady 插画详情页接收的params：', JSON.stringify(params))
    } catch (e) {
      logger.error(`#onReady 插画详情页 Navigate onReady catch exception: ${JSON.stringify(e)}`)
    }
  }

  // 关注/取消关注
  async followOrCancel(result: boolean, err?: string) {
    this.isFollow = result;
    if (this.detailData)
    this.detailData.user.is_followed = result;
  }

  // 收藏/取消收藏
  async bookmarkOrCancel() {
    if (!this.detailData) return;
    const illustId = this.detailData.id;
    try {
      if (this.detailData.is_bookmarked) {
        // 取消收藏
        await PixState.pixiv.deleteBookmark(illustId);
        this.detailData.is_bookmarked = false;
      } else {
        // 收藏 (默认公开收藏)
        await PixState.pixiv.addBookmark(illustId, 'public');
        this.detailData.is_bookmarked = true;
      }
    } catch (e) {
      logger.error(`!!! 收藏操作失败: ${JSON.stringify(e)}`);
      toastUtil.showToast({ message: "收藏失败" })
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
