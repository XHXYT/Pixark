import { PixivIllust } from "../../services/PixivTypes";

// 定义滑动列表提供者接口
export interface IIllustSwiperProvider {
  illustIds: number[];    // 当前所有插画 ID 列表
  hasMore: boolean;       // 是否还有更多数据
  isLoading: boolean;     // 是否正在加载
  loadMore(): Promise<void>; // 加载下一页
}

export interface DetailPageParams {
  id: number;
  fromId?: string;
  illust?: PixivIllust;
  // Swiper 联动所需参数
  swiperProvider?: IIllustSwiperProvider;
  swiperIndex?: number;
}