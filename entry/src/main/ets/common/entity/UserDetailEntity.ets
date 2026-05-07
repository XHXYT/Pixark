import { PixivUser  } from '../../services/PixivTypes';

export interface UserDetailParams {
  id: number;
  user?: PixivUser ; // 可选参数，用于快速显示
}