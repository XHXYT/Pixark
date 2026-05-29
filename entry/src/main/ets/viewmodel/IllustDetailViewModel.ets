import { _PixState } from '../entryability/AppState';
import { PixivIllust, PixivImage } from '../services/PixivTypes';
import { createLogger } from '../common/utils/Logger';
import { LongTakeAnimationProperties } from '../common/utils/customtransition/LongTakeAnimationProperties';
import { CustomTransition } from '../common/utils/customtransition/CustomNavigationUtils';
import { homeViewModel } from './HomeViewModel';
import { DetailPageParams, IIllustSwiperProvider } from '../common/entity/IllustDetailEntity';
import { CardUtil } from '../common/utils/CardUtil';
import { toastUtil } from '../common/utils/ToastUtils';
import { downloaderVM } from './DownloadsViewModel';
import { common } from '@kit.AbilityKit';
import { pixiv } from '../services/PixivService';
import { appSettings } from '../common/entity/SettingsModel';
import { ImageUtils } from '../common/utils/ImageUtils';
import { IllustHistoryVM } from './IllustHistoryViewModel';


const logger = createLogger('IllustDetailViewModel')


@ObservedV2
export class IllustDetailViewModel implements IIllustSwiperProvider {

  @Trace detailData: PixivIllust | null = null;
  private nextRelatedUrl: string | null = null
  // 相关图片推荐
  @Trace relatedIllusts: PixivIllust[] = []

  // 推荐加载状态
  @Trace isLoadingMoreRelated: boolean = false;
  // 插画详情加载状态
  @Trace isDetailLoading: boolean = false;
  // 收藏状态
  @Trace isBookmarked: boolean = false
  // 关注状态
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

  // IIllustSwiperProvider 接口
  get illustIds(): number[] {
    return this.relatedIllusts.map(i => i.id);
  }

  get hasMore(): boolean {
    return !!this.nextRelatedUrl;
  }

  get isLoading(): boolean {
    return this.isLoadingMoreRelated;
  }

  async loadMore(): Promise<void> {
    if (this.nextRelatedUrl) {
      await this.loadRelated(undefined, this.nextRelatedUrl);
    }
  }

  async loadIllustDetail(id: number) {
    try {
      logger.debug(`>>> 开始加载插画详情, ID: ${id}`);
      this.detailData = await pixiv.getIllustDetail(id);
      // 同步本地关注状态，确保按钮显示正确
      if (this.detailData && this.detailData.user) {
        this.isFollow = this.detailData.user.is_followed;
      }
      // 数据加载成功后，自动记录历史
      if (this.detailData) {
        IllustHistoryVM.addHistory(
          this.detailData.id.toString(),
          this.detailData.title,
          // 使用详情接口返回的更高质量的图作为历史记录封面
          ImageUtils.getImageUrlByQuality(this.detailData.image_urls, appSettings.image_preview_quality)
        );
      }
      logger.debug(`>>> 详情加载完毕, 图片: ${JSON.stringify(this.imageList.map(image => image.medium))}`);
    } catch (e) {
      logger.error(`!!! 加载详情失败: ${JSON.stringify(e)}`);
    }
  }

  /**
   * 加载相关推荐 (合并首次加载和翻页)
   * @param id 插画ID (首次加载时传入)
   * @param nextUrl 翻页URL (加载更多时传入)
   */
  async loadRelated(id?: number, nextUrl?: string) {
    // 防抖
    if (this.isLoadingMoreRelated) return;
    // 必须至少传一个
    if (!id && !nextUrl) return;

    this.isLoadingMoreRelated = true;
    try {
      // 统一调用改造后的 Service 方法
      const data = await pixiv.getRelatedIllusts(id || 0, nextUrl);
      const newIllusts = data.illusts || [];

      if (nextUrl) {
        // 翻页：去重合并
        const existingIds = new Set(this.relatedIllusts.map(i => i.id));
        const uniqueNew = newIllusts.filter(i => !existingIds.has(i.id));
        this.relatedIllusts = [...this.relatedIllusts, ...uniqueNew];
      } else {
        // 首次加载：直接赋值
        this.relatedIllusts = newIllusts;
      }

      // 保存下一页的 URL
      this.nextRelatedUrl = data.next_url;
    } catch (e) {
      logger.error(`加载推荐失败: ${JSON.stringify(e)}`);
    } finally {
      this.isLoadingMoreRelated = false;
    }
  }

  /**
   * 下载当前图片
   * @param index 如果是多图作品，当前点击的是第几张 (默认为0)
   */
  async downloadCurrentImage(index: number = 0) {
    const context: common.Context = _PixState.Context;
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

  // 详情页图片 URL 列表 (受 image_detail_quality 控制)
  get detailImageUrls(): string[] {
    return this.imageList.map(img => ImageUtils.getImageUrlByQuality(img, appSettings.image_detail_quality));
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
      // 同步初始关注&收藏状态
      if (this.detailData && this.detailData.user) {
        this.isFollow = this.detailData.user.is_followed;
        this.isBookmarked = this.detailData.is_bookmarked
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

  // 关注/取消关注 (本地状态同步)
  async followOrCancel(result: boolean, err?: string) {
    this.isFollow = result;
    if (this.detailData)
    this.detailData.user.is_followed = result;
  }

  // 收藏/取消收藏
  async bookmarkOrCancel(isBookmark?: boolean) {
    if (!this.detailData) return;
    const illust_id = this.detailData.id;

    // 确定目标状态：传了参数就以参数为准，没传就取反当前状态
    const targetBookmark = isBookmark ?? !this.detailData.is_bookmarked;
    // 防抖优化：如果目标状态和当前状态一致，说明无需操作，直接返回
    if (targetBookmark === this.detailData.is_bookmarked) return;
      try {
      if (targetBookmark) {
        // === 执行收藏 ===
        await pixiv.addBookmark(illust_id, appSettings.private_collecting ? 'private' : 'public');
        this.detailData.is_bookmarked = true;
        // 本地状态赋值
        this.isBookmarked = true
        toastUtil.showToast({ message: $r('app.string.bookmarked', this.detailData.title) })
        // 收藏后关注画师
        if (appSettings.follow_after_collecting && !this.detailData.user.is_followed) {
          try {
            await pixiv.followUser(this.detailData.user.id, appSettings.private_collecting ? 'private' : 'public');
            this.detailData.user.is_followed = true;
            this.isFollow = true;
          } catch (followErr) {
            logger.error(`自动关注失败: ${JSON.stringify(followErr)}`);
          }
        }
        // 收藏后自动下载
        if (appSettings.download_after_collecting) {
          this.downloadAllImages(); // 调用批量下载方法
        }
      } else {
        // === 执行取消收藏 ===
        await pixiv.deleteBookmark(illust_id);
        this.detailData.is_bookmarked = false;
        // 本地状态赋值
        this.isBookmarked = false
        toastUtil.showToast({ message: $r('app.string.not_bookmarked', this.detailData.title) })
      }
    } catch (e) {
      logger.error(`!!! 收藏操作失败: ${JSON.stringify(e)}`);
      toastUtil.showToast({ message: "收藏失败" });
    }
  }

  /**
   * 下载当前插画的所有图片 (处理单图和多图)
   */
  private async downloadAllImages() {
    if (!this.detailData) return;
    const context: common.Context = _PixState.Context;
    // 利用已有的 imageList 获取总页数
    const totalPages = this.imageList.length;
    if (totalPages === 0) return;

    for (let i = 0; i < totalPages; i++) {
      const originalUrl = this.getOriginalUrl(this.detailData, i);
      if (originalUrl) {
        // 循环调用全局下载器，将每一页都加入队列
        downloaderVM.addTask(context, this.detailData, originalUrl);
      }
    }
    toastUtil.showToast({ message: `已加入下载队列 (共${totalPages}张)` });
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
