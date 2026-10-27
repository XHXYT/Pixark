import { Context } from '@kit.AbilityKit';
import MuteRuleInfo from '../common/entity/MuteRuleInfo';
import { MuteRuleTable } from '../common/utils/database/impl/MuteRuleDao';
import { appSettings } from '../common/entity/SettingsModel';
import { createLogger } from '../common/utils/Logger';
import { PixivIllust, PixivNovel, PixivTag } from './PixivTypes';

const logger = createLogger('MuteFilter');

/** 屏蔽命中原因（用于拦截页展示与解除屏蔽） */
export class MuteReason {
  /** 命中规则类型：'tag' | 'user' | 'illust' */
  kind: string = 'tag';
  /** 命中规则的 target_key */
  key: string = '';
  /** 展示名 */
  name: string = '';

  constructor(kind: string, key: string, name: string) {
    this.kind = kind;
    this.key = key;
    this.name = name;
  }
}

/**
 * 屏蔽过滤器（单例）
 *
 * 设计要点（相对 PixEz 的改良）：
 * - 三类规则（标签/画师/作品）统一一张表，内存中分层索引，过滤 O(n·tags)
 * - 标签规则同时匹配 name 与 translated_name；"re:" 前缀表示正则（大小写不敏感）
 * - 作品屏蔽不影响小说（修复 PixEz 的跨类型副作用）
 * - 过滤不修改原数组（返回新数组），解除屏蔽后重新加载即可恢复
 * - 总开关 appSettings.mute_enabled 关闭时所有规则暂停
 */
export class MuteFilter {
  private static instance: MuteFilter | null = null;

  private db: MuteRuleTable | null = null;
  private tagRules: MuteRuleInfo[] = [];
  private userMap: Map<string, MuteRuleInfo> = new Map();
  private illustMap: Map<string, MuteRuleInfo> = new Map();
  /** 正则编译缓存（target_key -> RegExp；非法正则不缓存 = 永不命中） */
  private regexCache: Map<string, RegExp> = new Map();
  private loaded: boolean = false;
  private loading: Promise<void> | null = null;

  public static getInstance(): MuteFilter {
    if (!MuteFilter.instance) {
      MuteFilter.instance = new MuteFilter();
    }
    return MuteFilter.instance;
  }

  /** 初始化（EntryAbility 启动时调用，传入 Ability context） */
  public init(context: Context): void {
    if (!this.db) {
      this.db = new MuteRuleTable(context);
      logger.info('mute rule db initialized');
    }
  }

  /** 全量加载规则到内存 */
  public async reload(): Promise<void> {
    if (!this.db) {
      return;
    }
    try {
      const rules = await this.db.queryAll();
      this.tagRules = [];
      this.userMap = new Map();
      this.illustMap = new Map();
      this.regexCache = new Map();
      for (const rule of rules) {
        this.indexRule(rule);
      }
      this.loaded = true;
      logger.info(`mute rules loaded: ${rules.length} total, tags=${this.tagRules.length}, users=${this.userMap.size}, illusts=${this.illustMap.size}`);
    } catch (e) {
      const err = e as Error;
      logger.error(`reload failed: ${err.message}`);
    }
  }

  /** 首次使用前确保已加载（fail-open：加载失败不过滤） */
  public async ensureLoaded(): Promise<void> {
    if (this.loaded) {
      return;
    }
    if (!this.loading) {
      this.loading = this.reload().finally(() => {
        this.loading = null;
      });
    }
    await this.loading;
  }

  /** 屏蔽总开关 */
  public isEnabled(): boolean {
    return appSettings.mute_enabled;
  }

  /** 添加规则（去重；成功后更新内存） */
  public async addRule(ruleType: string, targetKey: string, name: string): Promise<boolean> {
    if (!this.db) {
      return false;
    }
    const key = targetKey.trim();
    if (!key) {
      return false;
    }
    try {
      if (await this.db.exists(ruleType, key)) {
        return false;
      }
      const rule = new MuteRuleInfo(ruleType, key, name);
      await this.db.insert(rule);
      this.indexRule(rule);
      logger.info(`rule added: ${ruleType} = ${key}`);
      return true;
    } catch (e) {
      const err = e as Error;
      logger.error(`addRule failed: ${err.message}`);
      return false;
    }
  }

  /** 删除规则（同步更新内存） */
  public async removeRule(ruleType: string, targetKey: string): Promise<void> {
    if (this.db) {
      try {
        await this.db.deleteByKey(ruleType, targetKey);
      } catch (e) {
        const err = e as Error;
        logger.error(`removeRule failed: ${err.message}`);
        return;
      }
    }
    if (ruleType === 'tag') {
      this.tagRules = this.tagRules.filter((r: MuteRuleInfo) => r.targetKey !== targetKey);
    } else if (ruleType === 'user') {
      this.userMap.delete(targetKey);
    } else if (ruleType === 'illust') {
      this.illustMap.delete(targetKey);
    }
    logger.info(`rule removed: ${ruleType} = ${targetKey}`);
  }

  public getTagRules(): MuteRuleInfo[] {
    return this.tagRules;
  }

  public getUserRules(): MuteRuleInfo[] {
    return Array.from(this.userMap.values());
  }

  public getIllustRules(): MuteRuleInfo[] {
    return Array.from(this.illustMap.values());
  }

  /** 单个标签是否命中标签规则 */
  public matchTag(tag: PixivTag): MuteRuleInfo | null {
    for (const rule of this.tagRules) {
      const key = rule.targetKey;
      if (key.startsWith('re:')) {
        const re = this.compileRegex(key);
        if (re && (re.test(tag.name) || (tag.translated_name ? re.test(tag.translated_name) : false))) {
          return rule;
        }
      } else if (key === tag.name || key === tag.translated_name) {
        return rule;
      }
    }
    return null;
  }

  /** 作品是否被屏蔽（优先级：作品 > 画师 > 标签） */
  public checkIllust(illust: PixivIllust): MuteReason | null {
    if (!this.isEnabled() || !this.loaded) {
      return null;
    }
    const illustRule = this.illustMap.get(String(illust.id));
    if (illustRule) {
      return new MuteReason('illust', illustRule.targetKey, illustRule.name);
    }
    const userReason = this.checkUser(illust.user.id);
    if (userReason) {
      return userReason;
    }
    for (const tag of illust.tags) {
      const tagRule = this.matchTag(tag);
      if (tagRule) {
        return new MuteReason('tag', tagRule.targetKey, tagRule.name);
      }
    }
    return null;
  }

  /** 小说是否被屏蔽（只受 标签/画师 规则影响，作品屏蔽不影响小说） */
  public checkNovel(novel: PixivNovel): MuteReason | null {
    if (!this.isEnabled() || !this.loaded) {
      return null;
    }
    const userReason = this.checkUser(novel.user.id);
    if (userReason) {
      return userReason;
    }
    for (const tag of novel.tags) {
      const tagRule = this.matchTag(tag);
      if (tagRule) {
        return new MuteReason('tag', tagRule.targetKey, tagRule.name);
      }
    }
    return null;
  }

  /** 用户是否被屏蔽 */
  public checkUser(userId: number): MuteReason | null {
    if (!this.isEnabled() || !this.loaded) {
      return null;
    }
    const rule = this.userMap.get(String(userId));
    if (rule) {
      return new MuteReason('user', rule.targetKey, rule.name);
    }
    return null;
  }

  /** 过滤插画列表（返回新数组，不修改原数组） */
  public filterIllusts(list: PixivIllust[]): PixivIllust[] {
    if (!this.isEnabled() || !this.loaded) {
      return list;
    }
    return list.filter((illust: PixivIllust) => this.checkIllust(illust) === null);
  }

  /** 过滤小说列表（返回新数组，不修改原数组） */
  public filterNovels(list: PixivNovel[]): PixivNovel[] {
    if (!this.isEnabled() || !this.loaded) {
      return list;
    }
    return list.filter((novel: PixivNovel) => this.checkNovel(novel) === null);
  }

  /** 编译并缓存 "re:" 正则；非法正则返回 null（永不命中） */
  private compileRegex(key: string): RegExp | null {
    if (this.regexCache.has(key)) {
      return this.regexCache.get(key) ?? null;
    }
    try {
      const re = new RegExp(key.substring(3), 'i');
      this.regexCache.set(key, re);
      return re;
    } catch (e) {
      logger.warn(`invalid regex rule: ${key}`);
      return null;
    }
  }

  /** 把规则放入对应内存索引 */
  private indexRule(rule: MuteRuleInfo): void {
    if (rule.ruleType === 'tag') {
      this.tagRules.push(rule);
    } else if (rule.ruleType === 'user') {
      this.userMap.set(rule.targetKey, rule);
    } else if (rule.ruleType === 'illust') {
      this.illustMap.set(rule.targetKey, rule);
    }
  }
}

/** 全局单例 */
export const muteFilter: MuteFilter = MuteFilter.getInstance();
