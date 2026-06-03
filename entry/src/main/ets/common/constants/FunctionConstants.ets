import { MenuOption } from '../entity/CusItemInfo'


export class FunctionConstants {

  // 常见 R18 标签黑名单
  static R18_TAG: string[] = ['R-18AI', 'R-18', 'R-18G', '全裸', ]

  // 常见 AI 标签黑名单
  static AI_TAG: string[] = ['AI生成', 'AI-assisted', 'AI-generated', 'NovelAI', 'R-18AI', 'AI作品']

  // 排行榜所有可选项目定义
  static ILLUST_RANK_MODES: Record<string, string> = {
    'day': '日榜',
    'week': '周榜',
    'month': '月榜',
    'day_male': '男性向',
    'day_female': '女性向',
    'week_original': '原创',
    'week_rookie': '新人',
    'day_r18': 'XVIII 日榜',
    'week_r18': 'XVIII 周榜',
    'day_male_r18': 'XVIII 男性向',
    'day_female_r18': 'XVIII 女性向',
  };

  static NOVEL_RANK_MODES: Record<string, string> = {
    'day': '日榜',
    'week': '周榜',
    'day_male': '男性向日榜',
    'day_female': '女性向日榜',
    'week_rookie': '新人周榜',
    'day_r18': 'XVIII 日榜',
    'day_male_r18': 'XVIII 男性向日榜',
    'day_female_r18': 'XVIII 女性向日榜',
    'week_r18': 'XVIII 周榜',
    'week_r18g': 'XVIII G 周榜',
  };

  // 默认文件名模板常量
  static DEFAULT_SAVE_FORMAT = '{illust_id}_p{part}_{title}_{user_name}'

  // 默认分享文本格式
  static DEFAULT_SHARE_FORMAT = '作品：{title}\n画师：{user_name}\n链接：https://www.pixiv.net/artworks/{illust_id}';

  // 图片质量档位菜单
  static IMAGE_QUALITY_MENU: MenuOption[] = [
    new MenuOption('medium', $r('app.string.medium')),
    new MenuOption('large', $r('app.string.large')),
    new MenuOption('original', $r('app.string.original'))
  ]

}
