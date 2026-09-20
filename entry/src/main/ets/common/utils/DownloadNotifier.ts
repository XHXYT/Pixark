import { notificationManager } from '@kit.NotificationKit';
import { common } from '@kit.AbilityKit';
import { createLogger } from './Logger';

const logger = createLogger('DownloadNotifier');

/** 下载通知 ID 基数（避开应用内其他通知的 id 空间） */
const NOTIFY_ID_BASE = 1000;
/** 进度通知最小发布间隔（毫秒）：字节级回调频繁，节流避免刷爆通知服务 */
const PROGRESS_THROTTLE_MS = 800;

/** 速度采样点（按任务记录，用于计算瞬时下载速度并 EMA 平滑） */
interface SpeedSample {
  /** 采样时的累计已收字节数 */
  bytes: number;
  /** 采样时间戳（毫秒） */
  at: number;
  /** 平滑后的速度（字节/秒） */
  speed: number;
}

/** 字节数格式化（B/KB/MB/GB） */
function formatBytes(bytes: number): string {
  if (bytes < 1024) {
    return `${bytes}B`;
  }
  if (bytes < 1024 * 1024) {
    return `${(bytes / 1024).toFixed(1)}KB`;
  }
  if (bytes < 1024 * 1024 * 1024) {
    return `${(bytes / 1024 / 1024).toFixed(2)}MB`;
  }
  return `${(bytes / 1024 / 1024 / 1024).toFixed(2)}GB`;
}

/** task_id -> 稳定通知 ID 偏移（djb2 哈希取正，映射到 0..899999） */
function stableIdHash(taskId: string): number {
  let hash = 5381;
  for (let i = 0; i < taskId.length; i++) {
    hash = ((hash << 5) + hash + taskId.charCodeAt(i)) | 0;
  }
  return Math.abs(hash) % 900000;
}

/**
 * 直连下载进度通知器（对齐 request.agent 系统托管下载的通知体验）：
 * - 布局：标题行=完整文件名，副标题行=速度 + 已下载/总大小，进度环=百分比
 * - 进度：downloadTemplate 进度条模板，字节级回调驱动、按百分比去重 + 时间节流 + 速度 EMA 平滑
 * - 串行：同一任务的通知发布排入串行链，保证进度/完成按顺序落通知栏，杜绝乱序覆盖
 * - 收尾：完成时标题行置为「下载完成」并以模板 progressValue=100（文档语义：>=100 进度环消失），
 *   失败/暂停保留模板但进度归零（避免无模板通知的进度环渲染异常）
 * - 守卫：收尾后丢弃滞留的进度发布；任务重启/恢复前须 reset 解除守卫
 * - 授权：首次发布前探测通知开关，未授权弹一次系统授权弹窗，拒绝则静默降级
 */
class DownloadNotifier {
  /** task_id -> 通知 ID */
  private notifyIds: Map<string, number> = new Map();
  /** task_id -> 上次已发布进度（相同百分比不重复 publish） */
  private lastProgress: Map<string, number> = new Map();
  /** task_id -> 上次进度发布时间（节流） */
  private lastPublishAt: Map<string, number> = new Map();
  /** task_id -> 速度采样点（仅在实际发布时采样，节流间隔即采样窗口） */
  private speedSamples: Map<string, SpeedSample> = new Map();
  /** 每任务发布串行链：保证该任务所有通知按入队顺序发布 */
  private chains: Map<string, Promise<void>> = new Map();
  /** 已收尾（完成/失败/暂停）任务集合：同步标记，丢弃之后新入队的进度发布 */
  private finalized: Set<string> = new Set();
  /** 通知授权状态：null 未探测 */
  private authorized: boolean | null = null;
  /** 授权弹窗进行中标记（并发任务启动时避免重复弹窗） */
  private requesting: boolean = false;

  /** 确保通知授权可用：未授权时弹一次系统授权弹窗（每进程仅一次，拒绝后静默降级） */
  async ensureAuthorized(context: common.UIAbilityContext): Promise<boolean> {
    if (this.authorized !== null) return this.authorized;
    if (this.requesting) return false;
    this.requesting = true;
    try {
      this.authorized = await notificationManager.isNotificationEnabled();
      if (!this.authorized) {
        await notificationManager.requestEnableNotification(context);
        this.authorized = true;
        logger.info('notification authorized via dialog');
      }
    } catch (e) {
      // 用户拒绝授权 / 系统拒绝再弹：不影响下载本身，仅无通知
      this.authorized = false;
      logger.warn(`notification not enabled: ${JSON.stringify(e)}`);
    } finally {
      this.requesting = false;
    }
    return this.authorized;
  }

  /** 通知 ID 由 task_id 哈希推导（跨会话稳定）：应用被杀后通知栏残留的旧通知
   *  会在新一轮发布时被同一 ID 覆盖，避免孤儿通知永远冻结在旧进度 */
  private getNotifyId(taskId: string): number {
    const existing = this.notifyIds.get(taskId);
    if (existing !== undefined) return existing;
    const id = NOTIFY_ID_BASE + stableIdHash(taskId);
    this.notifyIds.set(taskId, id);
    return id;
  }

  /** 任务通知状态重置（重启/恢复下载前调用：解除收尾守卫，允许新一轮进度发布） */
  reset(taskId: string): void {
    this.finalized.delete(taskId);
    this.lastProgress.delete(taskId);
    this.lastPublishAt.delete(taskId);
    this.speedSamples.delete(taskId);
  }

  /** 入队串行发布；任务通知被撤销（id 已释放）后队内任务全部跳过 */
  private enqueue(taskId: string, job: () => Promise<void>): void {
    const prev = this.chains.get(taskId);
    const next = prev ? prev.then(job) : job();
    this.chains.set(taskId, next);
  }

  /** 任务通知是否已被撤销（removeTask 后队内滞留任务不应再发布） */
  private isRevoked(taskId: string): boolean {
    return this.notifyIds.get(taskId) === undefined;
  }

  /**
   * 发布/更新下载进度通知
   * - 标题行=fileName（完整文件名），副标题行=速度 + 已下载/总大小，进度环=progress(0-100)
   * - 同一任务相同百分比去重 + 最小间隔节流；0% 强制发布（重启/恢复时刷新旧状态）
   * - 速度按发布间隔采样（字节增量/时间增量）并 EMA 平滑，仅在通过节流后采样
   */
  async notifyProgress(
    context: common.UIAbilityContext,
    taskId: string,
    fileName: string,
    receivedBytes: number,
    totalBytes: number,
    progress: number
  ): Promise<void> {
    if (this.finalized.has(taskId)) return;
    const last = this.lastProgress.get(taskId);
    if (last !== undefined && last === progress && progress !== 0) return;
    const lastAt = this.lastPublishAt.get(taskId);
    if (progress !== 0 && lastAt !== undefined && Date.now() - lastAt < PROGRESS_THROTTLE_MS) return;
    if (!(await this.ensureAuthorized(context))) return;
    const id = this.getNotifyId(taskId);

    // 速度采样：字节增量 / 时间增量，EMA 平滑瞬时波动；0% 强制发布视为新一轮开始，清零重计
    const now = Date.now();
    let speedBps = 0;
    const sample = this.speedSamples.get(taskId);
    if (progress !== 0 && sample && receivedBytes > sample.bytes) {
      if (sample.bytes > 0) {
        const elapsed = now - sample.at;
        if (elapsed > 0) {
          const instant = (receivedBytes - sample.bytes) * 1000 / elapsed;
          speedBps = sample.speed > 0 ? Math.round(sample.speed * 0.4 + instant * 0.6) : Math.round(instant);
        } else {
          speedBps = sample.speed;
        }
      }
      // sample.bytes === 0：首个有数据样本只记基线（前序窗口含探针/握手死区，跨窗算速会严重低估）
    }
    this.speedSamples.set(taskId, { bytes: receivedBytes, at: now, speed: speedBps });

    // 副标题行：速度 + 已下载/总大小（总大小未知时只显示速度 + 已下载）
    let subtitle: string;
    if (totalBytes > 0) {
      subtitle = speedBps > 0
        ? `${formatBytes(speedBps)}/s ${formatBytes(receivedBytes)}/${formatBytes(totalBytes)}`
        : `${formatBytes(receivedBytes)}/${formatBytes(totalBytes)}`;
    } else {
      subtitle = speedBps > 0
        ? `${formatBytes(speedBps)}/s ${formatBytes(receivedBytes)}`
        : formatBytes(receivedBytes);
    }

    const templateData: Record<string, Object> = {
      title: fileName,
      fileName: subtitle,
      progressValue: progress
    };
    const request: notificationManager.NotificationRequest = {
      id: id,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: fileName,
          text: '下载中',
          additionalText: `${progress}%`
        }
      },
      template: {
        name: 'downloadTemplate',
        data: templateData
      }
    };
    this.enqueue(taskId, async (): Promise<void> => {
      if (this.isRevoked(taskId) || this.finalized.has(taskId)) return;
      try {
        await notificationManager.publish(request);
        this.lastProgress.set(taskId, progress);
        this.lastPublishAt.set(taskId, Date.now());
      } catch (e) {
        logger.warn(`publish progress notification failed: ${taskId}, ${JSON.stringify(e)}`);
      }
    });
  }

  /**
   * 下载收尾通知（复用同一条通知位）：
   * - 完成：标题行置为「下载完成」，副标题行保留完整文件名，
   *   以模板 progressValue=100 收尾（文档语义：>=100 进度环消失，系统自动渲染完成样式）
   * - 失败：标题行保留完整文件名 + 文本标记下载失败，模板进度归零（模板无失败语义）
   */
  async notifyFinished(
    context: common.UIAbilityContext,
    taskId: string,
    fileName: string,
    success: boolean
  ): Promise<void> {
    this.finalized.add(taskId);
    this.lastProgress.delete(taskId);
    this.lastPublishAt.delete(taskId);
    this.speedSamples.delete(taskId);
    if (!(await this.ensureAuthorized(context))) return;
    const id = this.getNotifyId(taskId);
    const titleText = success ? '下载完成' : fileName;
    const templateData: Record<string, Object> = {
      title: titleText,
      fileName: fileName,
      progressValue: success ? 100 : 0
    };
    const request: notificationManager.NotificationRequest = {
      id: id,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: titleText,
          text: success ? '下载完成' : '下载失败',
          additionalText: success ? fileName : 'Pixark'
        }
      },
      template: {
        name: 'downloadTemplate',
        data: templateData
      }
    };
    this.enqueue(taskId, async (): Promise<void> => {
      if (this.isRevoked(taskId)) return;
      try {
        await notificationManager.publish(request);
      } catch (e) {
        logger.warn(`publish finished notification failed: ${taskId}, ${JSON.stringify(e)}`);
      }
    });
  }

  /** 下载暂停通知（在途请求结束后结果会被丢弃，通知先行置为已暂停）；标题行=「已暂停」，副标题行保留完整文件名 */
  async notifyPaused(
    context: common.UIAbilityContext,
    taskId: string,
    fileName: string
  ): Promise<void> {
    this.finalized.add(taskId);
    this.lastProgress.delete(taskId);
    this.lastPublishAt.delete(taskId);
    this.speedSamples.delete(taskId);
    if (!(await this.ensureAuthorized(context))) return;
    const id = this.getNotifyId(taskId);
    const templateData: Record<string, Object> = {
      title: '已暂停',
      fileName: fileName,
      progressValue: 0
    };
    const request: notificationManager.NotificationRequest = {
      id: id,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: '已暂停',
          text: '已暂停',
          additionalText: fileName
        }
      },
      template: {
        name: 'downloadTemplate',
        data: templateData
      }
    };
    this.enqueue(taskId, async (): Promise<void> => {
      if (this.isRevoked(taskId)) return;
      try {
        await notificationManager.publish(request);
      } catch (e) {
        logger.warn(`publish paused notification failed: ${taskId}, ${JSON.stringify(e)}`);
      }
    });
  }

  /** 撤销通知并释放全部状态（任务被删除时调用） */
  async cancel(taskId: string): Promise<void> {
    const id = this.notifyIds.get(taskId);
    this.notifyIds.delete(taskId);
    this.lastProgress.delete(taskId);
    this.lastPublishAt.delete(taskId);
    this.speedSamples.delete(taskId);
    this.finalized.delete(taskId);
    this.chains.delete(taskId);
    if (id === undefined) return;
    try {
      await notificationManager.cancel(id);
    } catch (e) {
      logger.warn(`cancel notification failed: ${taskId}, ${JSON.stringify(e)}`);
    }
  }
}

export const downloadNotifier = new DownloadNotifier();
