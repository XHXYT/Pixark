import { Context } from '@kit.AbilityKit';
import BookTagInfo from '../common/entity/BookTagInfo';
import { BookTagTable } from '../common/utils/database/impl/BookTagDao';
import { createLogger } from '../common/utils/Logger';

const logger = createLogger('BookTagStore');

/**
 * 收藏标签（单例）
 *
 * 设计要点（相对 PixEz 的改良）：
 * - 收藏即"常用标签快捷搜索"，半模态按钮直接切换状态，有即时反馈
 * - 收藏时连带保存翻译名，列表中直接可读
 * - 记录使用次数与最近使用时间，常用的自动浮到列表顶部
 * - 点击标签直接发起搜索，无需经过搜索页输入框
 */
export class BookTagStore {
  private static instance: BookTagStore | null = null;

  private db: BookTagTable | null = null;

  public static getInstance(): BookTagStore {
    if (!BookTagStore.instance) {
      BookTagStore.instance = new BookTagStore();
    }
    return BookTagStore.instance;
  }

  /** 初始化（EntryAbility 启动时调用） */
  public init(context: Context): void {
    if (!this.db) {
      this.db = new BookTagTable(context);
      logger.info('book tag db initialized');
    }
  }

  /** 全量列表（按使用次数 + 最近使用排序） */
  public async list(): Promise<BookTagInfo[]> {
    if (!this.db) {
      return [];
    }
    try {
      return await this.db.queryAll();
    } catch (e) {
      const err = e as Error;
      logger.error(`list failed: ${err.message}`);
      return [];
    }
  }

  /** 标签是否已收藏 */
  public async exists(name: string): Promise<boolean> {
    if (!this.db) {
      return false;
    }
    try {
      return await this.db.existsByName(name.trim());
    } catch (e) {
      return false;
    }
  }

  /** 收藏标签（去重；连带保存翻译） */
  public async add(name: string, translation: string): Promise<boolean> {
    if (!this.db) {
      return false;
    }
    const key = name.trim();
    if (!key) {
      return false;
    }
    try {
      if (await this.db.existsByName(key)) {
        return false;
      }
      await this.db.insert(new BookTagInfo(key, translation.trim()));
      return true;
    } catch (e) {
      const err = e as Error;
      logger.error(`add failed: ${err.message}`);
      return false;
    }
  }

  /** 取消收藏 */
  public async remove(name: string): Promise<boolean> {
    if (!this.db) {
      return false;
    }
    try {
      const count = await this.db.deleteByName(name.trim());
      return count > 0;
    } catch (e) {
      const err = e as Error;
      logger.error(`remove failed: ${err.message}`);
      return false;
    }
  }

  /** 记录一次搜索（使用次数 +1，最近使用时间刷新；fire-and-forget） */
  public async touch(name: string): Promise<void> {
    if (!this.db) {
      return;
    }
    try {
      const items = await this.db.queryByName(name.trim());
      if (items.length === 0) {
        return;
      }
      const item = items[0];
      item.useCount = (item.useCount || 0) + 1;
      item.lastUsedAt = new Date().getTime();
      await this.db.update(item);
    } catch (e) {
      const err = e as Error;
      logger.error(`touch failed: ${err.message}`);
    }
  }
}

export const bookTagStore = BookTagStore.getInstance();
