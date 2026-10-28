import { PixivUser  } from '../../services/PixivTypes';

export interface UserDetailParams {
  id: number;
  user?: PixivUser ; // 可选参数，用于快速显示
  /** 进页默认展示的作品类型（从插画/漫画详情进入时带当前作品类型） */
  worksType?: 'illust' | 'manga';
}