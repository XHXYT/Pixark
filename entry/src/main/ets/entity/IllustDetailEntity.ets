import { PixivIllust } from "../services/PixivTypes";

export interface DetailPageParams {
  id: number;
  fromId?: string; // 来源卡片 ID
  illust: PixivIllust
}