import { request } from "@kit.BasicServicesKit";
import { common } from '@kit.AbilityKit';
import { fileUri, fileIo as fs } from "@kit.CoreFileKit";
import { getDownloadRecordTable, DownloadRecordTable } from "../common/utils/database/impl/DownloadRecordTable";
import DownloadRecordInfo from "../common/entity/DownloadRecordInfo";
import { PixivIllust } from "../services/PixivTypes";
import { createLogger } from "../common/utils/Logger";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { toastUtil } from "../common/utils/ToastUtils";
import { appSettings } from "../common/entity/SettingsModel";
import { ImageUtils } from "../common/utils/ImageUtils";
import { DEFAULT_IMAGE_HOST, NetworkMode, networkModeState } from "../services/direct/NetworkModeState";
import { pixiv } from "../services/PixivService";
import { _PixState } from "../entryability/AppState";
import { downloadNotifier } from "../common/utils/DownloadNotifier";

const logger = createLogger('DownloadsViewModel')

/** 直连下载任务 ID 前缀（区分 request.agent 系统任务与应用内托管任务） */
const DIRECT_TASK_PREFIX = 'direct-';
/** 直连下载分段大小：1MB（单连接限速实测可低至 ~10KB/s，小块降低 90s 传输上限内的超时重试尾部） */
const DIRECT_CHUNK_SIZE = 1024 * 1024;
/** 直连下载分段并发数：限速按连接计，10 连接聚合实测数百 KB/s（停滞靠 30s 看门狗换线） */
const DIRECT_CHUNK_CONCURRENCY = 10;

@ObservedV2
export class DownloadsViewModel {

  @Trace selectedIds: Set<string> = new Set()

  @Trace tasks: DownloadRecordInfo[] = []

  @Trace isEditMode: boolean = false
  @Trace currentPage: number = 0

  private downloadDir = ""
  private context: common.Context | null = null
  // 轮询定时器、系统任务代理缓存、已完成任务去重
  private syncTimer: number | null = null
  private taskCache: Map<string, request.agent.Task> = new Map()
  private completedHandled: Set<string> = new Set()
  // 应用内直连下载：进行中/已取消任务集合（fetchBytes 不支持中断，取消靠标记丢弃结果）
  private directRunning: Set<string> = new Set()
  private directCancelled: Set<string> = new Set()
  // 相册保存串行队列：多个任务相继完成时保存弹窗依次弹出，不互相叠加
  private saveChain: Promise<void> = Promise.resolve()

  // 公共请求头
  private readonly PIXIV_HEADERS: Record<string, string> = {
    "Referer": "https://www.pixiv.net/",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  };

  /** 初始化下载目录 */
  async initDownLoad(context: common.Context) {
    this.context = context
    try {
      this.downloadDir = `${context.filesDir}/Pixiv/Pictures`;
      if (!fs.accessSync(this.downloadDir)) fs.mkdirSync(this.downloadDir);
    } catch (e) {
      logger.error("initDownLoad Error:", e)
    }
  }

  /**
   * V2 计算属性：直接依赖 tasks（增删）、currentPage（切页）以及每条记录的 @Trace status（状态流转），
   * 任何一处变化都会自动重算并驱动 UI 刷新，无需 @Monitor 或手动刷新。
   */
  @Computed
  get displayList(): DownloadRecordInfo[] {
    const statusList: (number[] | null)[] = [
      null, // 0: 所有
      [request.agent.State.RUNNING, request.agent.State.RETRYING], // 1: 下载中
      [request.agent.State.COMPLETED], // 2: 已完成
      [request.agent.State.STOPPED, request.agent.State.FAILED] // 3: 失败
    ];
    const targetStatus = statusList[this.currentPage] ?? null;
    return targetStatus
      ? this.tasks.filter(d => targetStatus.includes(d.status))
      : [...this.tasks];
  }

  /** 切换编辑模式 */
  toggleEditMode() {
    this.isEditMode = !this.isEditMode;
    this.selectedIds.clear();
  }

  /** 切换选中状态 */
  toggleSelect(task_id: string) {
    if (this.selectedIds.has(task_id)) {
      this.selectedIds.delete(task_id);
    } else {
      this.selectedIds.add(task_id);
    }
  }

  /** 切换缩略图显示 */
  toggleThumbnail() {
    appSettings.show_thumbnail = !appSettings.show_thumbnail;
  }

  /** 是否为应用内直连下载任务（非 request.agent 系统任务） */
  private isDirectTaskId(task_id: string): boolean {
    return task_id.startsWith(DIRECT_TASK_PREFIX);
  }

  /** 直连下载通知所需的 UIAbilityContext（授权弹窗要求，能力未就绪时返回 null 静默跳过） */
  private notifierContext(): common.UIAbilityContext | null {
    return _PixState.Context ?? null;
  }

  /** 发布直连下载进度通知（内部去重/节流/静默失败，不阻塞下载主流程） */
  private notifyDirectProgress(record: DownloadRecordInfo, progress: number, receivedBytes: number, totalBytes: number) {
    const ctx = this.notifierContext();
    if (!ctx || !record.filePath) return;
    const fileName = record.filePath.split('/').pop() ?? record.filePath;
    downloadNotifier.notifyProgress(ctx, record.task_id, fileName, receivedBytes, totalBytes, progress);
  }

  /** 直连下载收尾通知（完成/失败） */
  private notifyDirectFinished(record: DownloadRecordInfo, success: boolean) {
    const ctx = this.notifierContext();
    if (!ctx || !record.filePath) return;
    const fileName = record.filePath.split('/').pop() ?? record.filePath;
    downloadNotifier.notifyFinished(ctx, record.task_id, fileName, success);
  }

  /**
   * 该 URL 是否需要应用内直连下载：
   * 图床域名在网络模式下非标准模式时（request.agent 走系统网络栈，SNI 阻断下必死），
   * 由应用内 fetchBytes 直连链路接管；镜像图床/其他域名仍走系统下载。
   */
  private shouldUseDirect(url: string): boolean {
    const hostMatch = url.match(/^https?:\/\/([^\/]+)/);
    if (!hostMatch) return false;
    const host = hostMatch[1];
    const isPximg = host === 'i.pximg.net' || host === 's.pximg.net';
    return isPximg && networkModeState.getModeForHost(host) !== NetworkMode.STANDARD;
  }

  /** 判断是否选中 */
  isSelected(task_id: string): boolean {
    return this.selectedIds.has(task_id); // O(1) 复杂度
  }

  /** 全选当前页面 */
  selectAllVisible() {
    this.selectedIds.clear();
    this.displayList.forEach(task => this.selectedIds.add(task.task_id));
  }

  /** 取消全选 */
  deselectAll() {
    this.selectedIds.clear();
  }

  /** 获取选中数量 */
  getSelectedCount(): number {
    return this.selectedIds.size;
  }

  editDelete() {
    // 筛选出当前选中的任务对象数组
    const selectedTasks = this.tasks.filter(t => this.selectedIds.has(t.task_id));
    const count = selectedTasks.length;
    // 根据数量动态生成提示文案
    let message = '';
    if (count === 1) {
      // 只选了一个：显示具体作品名
      const title = selectedTasks[0].title || '未知作品';
      message = `确定要删除「${title}」吗？此操作不可恢复。`;
    } else if (count > 1) {
      // 选了多个：显示数量
      message = `确定要删除选中的 ${count} 个任务吗？此操作不可恢复。`;
    }

    // 召唤弹窗
    if (message) {
      toastUtil.showAlertDialog({
        title: '确认删除',
        message: message,
        alignment: DialogAlignment.Center,
        primaryButton: {
          value: '删除',
          fontColor: Color.Red,
          action: async () => {
            await this.batchRemoveSelectedTasks();
          }
        },
        secondaryButton: {
          value: '取消',
          action: () => {}
        }
      })
    }
  }

  /** 多选后批量删除 */
  async batchRemoveSelectedTasks() {
    if (this.selectedIds.size === 0) return;
    // 获取待删除 ID
    const idsToDelete = Array.from(this.selectedIds);
    // 调用底层删除
    await this.batchDeleteTasksByIds(idsToDelete);
    // 清空勾选、退出编辑模式
    this.toggleEditMode();
  }

  async getFileUri(filePath: string | undefined): Promise<string> {
    return filePath ? fileUri.getUriFromPath(filePath) : '';
  }

  /**
   * 轮询兜底：不依赖 request.agent 的事件回调，每秒通过 request.agent.show 同步一次
   * 进行中任务的状态/进度。@Computed 会自动把这些 @Trace 变化传导到 UI。
   * 队列空闲（无进行中任务）时自动停止，新增任务或进入下载管理页时重新拉起。
   */
  startLiveSync() {
    if (this.syncTimer !== null) return;
    this.syncTimer = setInterval(() => {
      this.syncOnce();
    }, 1000);
    this.syncOnce();
  }

  stopLiveSync() {
    if (this.syncTimer !== null) {
      clearInterval(this.syncTimer);
      this.syncTimer = null;
    }
  }

  private syncOnce() {
    // 直连任务由自身回调驱动状态，不参与系统任务轮询（request.agent.show 对 direct- 前缀 ID 必然抛错）
    const active = this.tasks.filter(d =>
      !this.isDirectTaskId(d.task_id) &&
      d.status !== request.agent.State.COMPLETED &&
      d.status !== request.agent.State.FAILED &&
      d.status !== request.agent.State.STOPPED &&
      d.status !== request.agent.State.PAUSED
    );
    if (active.length === 0) {
      this.stopLiveSync();
      return;
    }
    active.forEach(async (record) => {
      try {
        const info = await request.agent.show(record.task_id);
        if (info.progress.state === record.status) {
          // 状态未变化：仅同步下载进度
          if (record.status === request.agent.State.RUNNING ||
            record.status === request.agent.State.RETRYING) {
            if (info.progress.sizes && info.progress.sizes.length > 0) {
              const total = info.progress.sizes[0];
              if (total > 0) {
                record.progress = Math.floor((info.progress.processed / total) * 100);
              }
            }
          }
          return;
        }
        record.status = info.progress.state;
        if (info.progress.state === request.agent.State.COMPLETED) {
          await this.onTaskCompleted(record);
        } else if (info.progress.state === request.agent.State.FAILED ||
          info.progress.state === request.agent.State.STOPPED) {
          await this.persistStatus(record.task_id, info.progress.state);
          this.TryRunNextTask();
        } else {
          await this.persistStatus(record.task_id, info.progress.state);
        }
      } catch (e) {
        // 系统任务已不存在：标记失败，避免成为被永远轮询的幽灵任务（与 fetchSysTask 语义一致）
        record.status = request.agent.State.FAILED;
        this.persistStatus(record.task_id, request.agent.State.FAILED);
      }
    });
  }

  /** 任务完成的统一入口：事件回调与轮询都会走到这里，completedHandled 防止重复保存 */
  private async onTaskCompleted(record: DownloadRecordInfo) {
    record.status = request.agent.State.COMPLETED;
    record.progress = 100;
    if (this.completedHandled.has(record.task_id)) return;
    this.completedHandled.add(record.task_id);
    await this.persistStatus(record.task_id, request.agent.State.COMPLETED);
    // 相册保存弹窗会阻塞等待用户操作：转后台串行执行，
    // 避免占住下载并发额度、卡住排队任务的补位调度（保存取消/失败不影响记录状态，文件留在沙箱可手动保存）
    this.saveChain = this.saveChain.then((): Promise<void> => this.saveImageToGallery(record))
      .catch((e: Error): void => logger.warn(`auto save to gallery failed: ${record.task_id}`, e));
    this.TryRunNextTask();
  }

  private async persistStatus(task_id: string, status: number) {
    if (!this.context) return;
    try {
      await getDownloadRecordTable(this.context).updateStatus(task_id, status);
    } catch (e) {
      logger.warn(`persistStatus failed, tid: ${task_id}`, e);
    }
  }

  /** 获取任务列表 */
  async fetchSysTask() {
    if (!this.context) return;
    const db = getDownloadRecordTable(this.context);
    // 从数据库获取记录（普通对象数组）
    let dbRecords = await db.queryAllDesc();
    const stateTypes = [
      request.agent.State.RUNNING,
      request.agent.State.FAILED,
      request.agent.State.PAUSED,
      request.agent.State.COMPLETED,
      request.agent.State.STOPPED,
      request.agent.State.RETRYING,
      request.agent.State.WAITING,
      request.agent.State.INITIALIZED,
    ];

    try {
      // 获取系统侧的所有任务 ID
      const task_ids = (await Promise.all(stateTypes.map(s => request.agent.search({ state: s })))).flat();
      // 获取系统侧任务详情
      const sysTasks = await Promise.all(task_ids.map(id => request.agent.show(id).catch(() => null)));
      // 建立系统任务的映射表 (tid -> TaskInfo)
      const sysTaskMap = new Map<string, request.agent.TaskInfo>();
      sysTasks.forEach(task => {
        if (task) {
          sysTaskMap.set(task.tid, task);
        }
      });

      // 在途直连任务沿用原内存对象：下载闭包持有该引用，重建会切断进度/完成状态的响应式更新
      const runningDirect = new Map<string, DownloadRecordInfo>();
      this.tasks.forEach(t => {
        if (this.isDirectTaskId(t.task_id) && this.directRunning.has(t.task_id)) {
          runningDirect.set(t.task_id, t);
        }
      });

      // 手动将普通对象转换为响应式类实例
      this.tasks = dbRecords.map(rawRecord => {
        // 在途直连任务直接复用（状态为 RUNNING，进度由下载闭包实时驱动）
        const running = runningDirect.get(rawRecord.task_id);
        if (running) {
          return running;
        }
        // A. 创建响应式实例
        const record = new DownloadRecordInfo();
        // B. 逐个属性赋值
        record.id = rawRecord.id;
        record.task_id = rawRecord.task_id;
        record.illust_id = rawRecord.illust_id;
        // 处理旧数据可能没有 page 字段的情况，给个默认值 0
        record.page = rawRecord.page ?? 0;
        record.title = rawRecord.title;
        record.artistName = rawRecord.artistName;
        record.artist_avatar = rawRecord.artist_avatar;
        record.thumbnail = rawRecord.thumbnail;
        record.filePath = rawRecord.filePath;
        record.url = rawRecord.url;
        record.status = rawRecord.status;
        // progress 数据库里没存，初始化为 0，后续用 sysTask 覆盖
        record.progress = rawRecord.progress || 0;
        record.savedToGallery = rawRecord.savedToGallery ?? false;
        record.create_time = rawRecord.create_time;
        // C. 同步系统任务的状态
        const sysTask = sysTaskMap.get(record.task_id);
        if (sysTask) {
          record.status = sysTask.progress.state;
          if (sysTask.progress.sizes && sysTask.progress.sizes.length > 0) {
            const total = sysTask.progress.sizes[0];
            if (total > 0) {
              record.progress = Math.floor((sysTask.progress.processed / total) * 100);
            }
          }
        } else if (this.isDirectTaskId(record.task_id)) {
          // 直连任务系统侧本就无对应任务：未完成的重新入队等待调度（重启恢复）
          if (record.status !== request.agent.State.COMPLETED) {
            record.status = request.agent.State.INITIALIZED;
            record.progress = 0;
          }
        } else if (record.status !== request.agent.State.COMPLETED) {
          // 系统任务不存在且未完成，标记为失败
          record.status = request.agent.State.FAILED;
        }

        return record;
      }).sort((a, b) => b.create_time - a.create_time);

      // 沙箱补删：已保存到相册的记录若沙箱文件仍残留（上次删文件失败/保存中途应用被杀），启动时补删
      this.tasks.forEach(record => {
        if (record.savedToGallery && record.filePath && fs.accessSync(record.filePath)) {
          logger.info(`cleanup residual sandbox file for saved record: ${record.task_id}`);
          this.deleteFile(record.filePath);
        }
      });

      // 对未完成的任务重新挂载监听（直连任务跳过，由自身队列调度）
      this.tasks.forEach(record => {
        if (!this.isDirectTaskId(record.task_id) &&
          record.status !== request.agent.State.COMPLETED &&
          record.status !== request.agent.State.FAILED &&
          record.status !== request.agent.State.STOPPED) {
          this.attachSysTask(record.task_id);
        }
      });

      // 恢复等待中的直连任务（TryRunNextTask 内部含并发上限校验）
      await this.TryRunNextTask();

    } catch (e) {
      logger.error("fetchSysTask failed", e);
    }
    // 拉起轮询兜底：this.tasks 的 @Trace 变化会自动经 @Computed 传导到 UI
    this.startLiveSync();
  }

  /** 检查沙箱文件是否真实存在 */
  isFileInSandbox(filePath: string | undefined): boolean {
    if (!filePath) return false;
    try {
      // accessSync 是微秒级的本地校验，在这里使用不会卡 UI
      return fs.accessSync(filePath);
    } catch (e) {
      return false;
    }
  }

  /** 手动保存到相册 */
  async manualSaveToGallery(record: DownloadRecordInfo) {
    if (!this.isFileInSandbox(record.filePath)) {
      toastUtil.showToast({ message: "文件不存在或已保存" });
      return;
    }
    toastUtil.showToast({ message: `正在导出 ${record.title || '未命名作品'}` })
    // 复用保存逻辑，保存成功后它会自动 deleteFile 删除沙箱文件并置位 savedToGallery
    await this.saveImageToGallery(record);
  }

  async pauseTask(id: string) {
    this.startLiveSync();
    // 直连任务：标记取消，在途请求结束后丢弃结果
    if (this.isDirectTaskId(id)) {
      const record = this.tasks.find(d => d.task_id === id);
      if (record && record.status === request.agent.State.RUNNING) {
        this.directCancelled.add(id);
        record.status = request.agent.State.PAUSED;
        await this.persistStatus(id, request.agent.State.PAUSED);
        // 通知栏置为已暂停（在途请求结束后结果丢弃，不会触发完成通知）
        const pauseCtx = this.notifierContext();
        if (pauseCtx && record.filePath) {
          const pauseFile = record.filePath.split('/').pop() ?? record.filePath;
          downloadNotifier.notifyPaused(pauseCtx, id, pauseFile);
        }
        logger.info(`direct task paused: ${id}（在途请求结束后释放并发额度）`);
      }
      return;
    }
    const task = await this.getSysTask(id);
    if (task) {
      await this.attachTask(task);
      await task.pause();
    }
  }

  // 恢复任务
  async resumeTask(id: string) {
    this.startLiveSync();
    // 直连任务：重新入队（无断点续传，恢复即整包重下）
    if (this.isDirectTaskId(id)) {
      const record = this.tasks.find(d => d.task_id === id);
      if (record && record.status === request.agent.State.PAUSED) {
        // 注意：不可清除 directCancelled——该标志属于仍在收尾的旧运行，
        // 提前清除会让旧运行「复活」继续下载（实测事故：恢复后 UI 卡排队中，旧运行却跑完并弹保存）
        record.status = request.agent.State.INITIALIZED;
        await this.persistStatus(id, request.agent.State.INITIALIZED);
        if (!this.directRunning.has(id)) {
          await this.tryRunDirectTask(record);
        }
        // 在途请求尚未收尾（directRunning 未释放）：保持 INITIALIZED 排队，
        // 旧运行 finally 里的 TryRunNextTask 会自动补位重启本任务
      }
      return;
    }
    const task = await this.getSysTask(id);
    if (task) {
      await this.attachTask(task);
      this.TryRunTask(task, true);
    }
  }

  // 重启任务
  async restartTask(id: string) {
    if (!this.context) return;
    this.startLiveSync();
    const record = this.tasks.find(d => d.task_id === id);
    if (!record) {
      toastUtil.showToast({ message: `未查询到下载记录` })
      return;
    }
    toastUtil.showToast({ message: `开始重试「${record.title}」任务` })
    // 直连任务：清掉旧文件重新整包下载
    if (this.isDirectTaskId(id)) {
      if (this.directRunning.has(id)) return; // 在途任务不可重启
      this.directCancelled.delete(id);
      await this.deleteFile(record.filePath);
      record.status = request.agent.State.INITIALIZED;
      record.progress = 0;
      await this.persistStatus(id, request.agent.State.INITIALIZED);
      await this.tryRunDirectTask(record);
      return;
    }
    const task = await this.getSysTask(id);
    if (task) {
      await this.attachTask(task);
      this.TryRunTask(task);
    } else {
      await this.recreateLostTask(record);
    }
  }

  async deleteOneTask(task: DownloadRecordInfo) {
    await this.removeTask(task)
  }

  async pauseAllTask() {
    this.startLiveSync();
    // 直连任务逐个暂停
    const directRunningIds = this.tasks
      .filter(d => this.isDirectTaskId(d.task_id) && d.status === request.agent.State.RUNNING)
      .map(d => d.task_id);
    for (let id of directRunningIds) {
      await this.pauseTask(id);
    }
    const task_ids = await request.agent.search({ state: request.agent.State.RUNNING });
    for (let id of task_ids) {
      const task = await this.getSysTask(id);
      if (task) { this.attachTask(task); await task.pause(); }
    }
  }

  async resumeAllTask() {
    this.startLiveSync();
    // 直连任务逐个恢复
    const pausedDirect = this.tasks
      .filter(d => this.isDirectTaskId(d.task_id) && d.status === request.agent.State.PAUSED)
      .map(d => d.task_id);
    for (let id of pausedDirect) {
      await this.resumeTask(id);
    }
    const task_ids = await request.agent.search({ state: request.agent.State.PAUSED });
    for (let id of task_ids) {
      const task = await this.getSysTask(id);
      if (task) {
        this.attachTask(task);
        await this.TryRunTask(task, true);
        await new Promise<void>(res => setTimeout(res, 100));
      }
    }
  }

  async restartAllTask() {
    // 找出本地内存中所有处于 失败 或 停止 状态的任务
    const failedTasks = this.tasks.filter(d =>
    d.status === request.agent.State.FAILED ||
      d.status === request.agent.State.STOPPED
    );
    if (failedTasks.length === 0) return;

    logger.debug(`restartAllSysTask: 发现 ${failedTasks.length} 个失败/停止任务，开始批量重试`);
    // 遍历并直接调用单个重试逻辑
    for (const task of failedTasks) {
      try {
        // 复用完善后的单个重试方法
        await this.restartTask(task.task_id);
      } catch (e) {
        toastUtil.showToast({ message: `任务 ${task.title} 重试失败`})
        // 防止某一个任务重试时抛出异常中断了整个批量循环
        logger.error(`restartAllSysTask: 单个任务重试异常 task_id: ${task.task_id}, err: ${JSON.stringify(e)}`);
      }
    }
  }

  /** 清空所有已完成的任务 */
  async clearAllCompletedTasks() {
    // 筛选已完成任务
    const completedTasks = this.tasks.filter(d => d.status === request.agent.State.COMPLETED);
    if (completedTasks.length === 0) {
      logger.warn("clearAllCompletedTasks: 没有已完成的任务需要清理");
      return;
    }
    // 提取 ID
    const ids = completedTasks.map(task => task.task_id);
    // 调用底层删除
    await this.batchDeleteTasksByIds(ids);
  }

  async attachSysTask(id: string) {
    const task = await this.getSysTask(id);
    if (task) this.attachTask(task);
  }

  /**
   * 添加 Pixiv 图片下载任务
   * 基于数据库 + (illust_id + page) 查重, 兼容无page数据查重逻辑
   */
  async addTask(context: common.Context, illustInfo: PixivIllust, url: string) {
    if (!this.context) this.context = context;
    const db = getDownloadRecordTable(this.context);

    // 提取当前图片的分 P 索引
    const pageIndex = this.getPageFromUrl(url);

    // 查询数据库中该 PID 的所有记录
    const records = await db.queryByIllustId(illustInfo.id);

    // 在结果中筛选：寻找“完全匹配”或“旧数据兼容匹配”
    const existingRecord = records.find(record => {
      // 情况 A: 完全匹配 (page 一致)
      if (record.page === pageIndex) {
        return true;
      }
      // 情况 B: 兼容旧数据 (数据库里没有 page 字段，或 page 为 null/undefined)
      // 此时认为它是历史数据，为了防止重复，只要 PID 对上了就拦截
      if (record.page === null || record.page === undefined) {
        return true;
      }
      return false;
    });

    // 如果存在记录，进行拦截提示
    if (existingRecord) {
      // 根据是否为旧数据，优化提示语
      const isOldRecord = existingRecord.page === null || existingRecord.page === undefined;
      const statusMsg = existingRecord.status === request.agent.State.COMPLETED
        ? (isOldRecord ? '该作品已有历史下载记录' : '该图片已下载过')
        : '该图片已在下载列表中';
      const shouldContinue = await new Promise<boolean>((resolve) => {
        toastUtil.showAlertDialog({
          title: '重复提示',
          message: `${statusMsg}：「${existingRecord.title || '未命名'}」，是否重新下载？`,
          alignment: DialogAlignment.Center,
          primaryButton: {
            value: '重新下载',
            action: () => resolve(true)
          },
          secondaryButton: {
            value: '取消',
            action: () => resolve(false)
          }
        });
      });

      if (!shouldContinue) return; // 用户取消

      // 执行清理逻辑 (如果是旧数据，清理掉；如果是精确匹配，也清理掉)
      try {
        await request.agent.remove(existingRecord.task_id);
      } catch (e) { /* 忽略任务不存在（含 direct- 前缀的应用内任务） */ }
      // 在途直连任务同步标记取消，防止完成后写入已删除的记录
      if (this.isDirectTaskId(existingRecord.task_id) && this.directRunning.has(existingRecord.task_id)) {
        this.directCancelled.add(existingRecord.task_id);
      }
      await this.deleteFile(existingRecord.filePath);
      if (existingRecord.id) await db.deleteByID(existingRecord.id);
      // 同步内存
      this.tasks = this.tasks.filter(t => t.task_id !== existingRecord.task_id);
    }

    // 无重复或用户选择重新下载，执行下载
    await this._createDownloadTask(context, illustInfo, url, pageIndex);
  }

  private async getSysTask(id: string | undefined): Promise<request.agent.Task | undefined> {
    if (!id || !this.context) return undefined;
    const cached = this.taskCache.get(id);
    if (cached) return cached;
    try {
      const task = await request.agent.getTask(this.context, id);
      // 缓存代理对象，同时避免事件回调随临时代理被回收而丢失
      this.taskCache.set(id, task);
      return task;
    } catch (e) {
      return undefined;
    }
  }

  // 丢失任务重建
  private async recreateLostTask(record: DownloadRecordInfo) {
    if (!record.url || !this.context) {
      record.status = request.agent.State.FAILED;
      return;
    }
    logger.info(`restartTask: 系统任务丢失, 使用链接重建: ${record.url}`);

    try {
      const db = getDownloadRecordTable(this.context);
      const fileName = record.filePath ? record.filePath.substring(record.filePath.lastIndexOf('/') + 1) : `pixiv_${Date.now()}`;
      const filePath = record.filePath || `${this.downloadDir}/${fileName}`;

      const newTask = await request.agent.create(this.context, this.getTaskConfig(record.url, fileName, filePath));

      record.task_id = newTask.tid;
      record.status = request.agent.State.INITIALIZED;
      record.progress = 0;
      await db.update(record);

      await this.attachTask(newTask);
      await this.TryRunTask(newTask);
    } catch (e) {
      logger.error(`restartTask: 重建失败. ${JSON.stringify(e)}`);
      record.status = request.agent.State.FAILED;
    }
  }

  private async attachTask(task: request.agent.Task) {
    if (!this.context) return;
    this.taskCache.set(task.tid, task);

    try {
      this.unAttackTask(task);

      task.on('progress', (progress) => {
        const target = this.tasks.find(d => d.task_id === task.tid);
        if (target && progress.sizes && progress.sizes.length > 0) {
          const total = progress.sizes[0];
          if (total > 0) target.progress = Math.floor((progress.processed / total) * 100);
        }
      });

      task.on('completed', async () => {
        const target = this.tasks.find(d => d.task_id === task.tid);
        if (target) await this.onTaskCompleted(target);
        this.TryRunNextTask();
      });

      task.on('pause', () => {
        const target = this.tasks.find(d => d.task_id === task.tid);
        if (target) target.status = request.agent.State.PAUSED;
        this.persistStatus(task.tid, request.agent.State.PAUSED);
        this.TryRunNextTask();
      });

      task.on('resume', () => {
        const target = this.tasks.find(d => d.task_id === task.tid);
        if (target) target.status = request.agent.State.RUNNING;
        this.persistStatus(task.tid, request.agent.State.RUNNING);
      });

      task.on('failed', async () => {
        const target = this.tasks.find(d => d.task_id === task.tid);
        if (target) target.status = request.agent.State.FAILED;
        await this.persistStatus(task.tid, request.agent.State.FAILED);
        this.TryRunNextTask();
      });

      task.on('remove', () => {
        this.taskCache.delete(task.tid);
        this.tasks = this.tasks.filter(d => d.task_id !== task.tid);
        this.TryRunNextTask();
      });
    } catch (e) {
      // 事件注册失败（如任务模式限制），状态同步由 startLiveSync 轮询兜底
      logger.warn(`attachTask: 注册事件监听失败, tid: ${task.tid}`, e);
    }
  }

  private async TryRunNextTask() {
    // 直连任务优先补位（tryRunDirectTask 内部含并发上限校验，满了自然跳过）
    const waitingDirect = this.tasks.filter(d =>
      this.isDirectTaskId(d.task_id) && d.status === request.agent.State.INITIALIZED);
    for (const record of waitingDirect) {
      await this.tryRunDirectTask(record);
    }
    const waiting = await request.agent.search({ state: request.agent.State.INITIALIZED });
    if (waiting.length === 0) return;
    const sysTask = await this.getSysTask(waiting.pop());
    if (sysTask) {
      await this.attachTask(sysTask);
      await this.TryRunTask(sysTask);
    }
  }

  private async TryRunTask(task: request.agent.Task, resume: boolean = false) {
    const running = await request.agent.search({ state: request.agent.State.RUNNING });
    if (running.length < Number(appSettings.max_download_count)) {
      resume ? await task.resume() : await task.start();
      // request.agent 没有 start 事件，启动成功后需手动同步记录状态，@Computed 会自动刷新列表
      const target = this.tasks.find(d => d.task_id === task.tid);
      if (target) target.status = request.agent.State.RUNNING;
      return true;
    }
    return false;
  }

  private unAttackTask(task: request.agent.Task) {
    task.off('progress'); task.off('completed'); task.off('failed');
    task.off('pause'); task.off('resume'); task.off('remove');
  }

  /** 将沙箱文件保存到系统相册 */
  private async saveImageToGallery(record: DownloadRecordInfo) {
    const localPath = record.filePath;
    const title = record.title || '未命名作品';
    if (!localPath || !this.context) return;

    try {
      // 文件存在性校验
      logger.info(`[SaveDebug] 准备保存. 路径: ${localPath}`);
      const isExist = fs.accessSync(localPath);
      logger.info(`[SaveDebug] 文件是否存在: ${isExist}`);
      if (!isExist) return;
      // 解析文件名参数
      const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.context);
      const fileName = localPath.substring(localPath.lastIndexOf('/') + 1);
      const dotIndex = fileName.lastIndexOf('.');
      let safeTitle = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
      const extension = dotIndex > 0 ? fileName.substring(dotIndex + 1) : 'jpg';
      logger.info(`[SaveDebug] 文件名: ${fileName}, 标题: ${safeTitle}, 后缀: ${extension}`);
      safeTitle = safeTitle.replace(/\./g, '_');
      // 生成 URI
      const srcUri = fileUri.getUriFromPath(localPath);
      logger.info(`[SaveDebug] >>> 生成的系统 URI: ${srcUri} <<<`);
      // 调起保存弹窗
      logger.info(`[SaveDebug] 准备调起 showAssetsCreationDialog...`);
      let desFileUris = await phAccessHelper.showAssetsCreationDialog(
        [srcUri],
        [{ title: safeTitle, fileNameExtension: extension, photoType: photoAccessHelper.PhotoType.IMAGE, subtype: photoAccessHelper.PhotoSubtype.DEFAULT }]
      );
      logger.info(`[SaveDebug] 弹窗返回结果: ${JSON.stringify(desFileUris)}`);
      // 拷贝逻辑
      if (desFileUris && desFileUris.length > 0) {
        const destUri = desFileUris[0];
        logger.info(`[SaveDebug] 目标相册 URI: ${destUri}, 开始拷贝...`);
        const srcFd = fs.openSync(localPath, fs.OpenMode.READ_ONLY);
        const destFd = await fs.open(destUri, fs.OpenMode.WRITE_ONLY);
        await fs.copyFile(srcFd.fd, destFd.fd);
        fs.closeSync(srcFd);
        await fs.close(destFd.fd);
        logger.info(`[SaveDebug] 拷贝成功，准备删除沙箱文件`);
        // 先持久化已保存标记再删文件：即使删除失败/应用被杀，下次启动也会按标记补删沙箱文件
        if (this.context) {
          try {
            await getDownloadRecordTable(this.context).updateSavedToGallery(record.task_id, true);
          } catch (e) {
            logger.warn(`persist savedToGallery failed: ${record.task_id}`, e);
          }
        }
        record.savedToGallery = true;
        await this.deleteFile(localPath);
        toastUtil.showToast({ message: $r('app.string.save_success', title) });
      } else {
        // 用户点击取消，或者弹窗莫名返回空数组
        logger.warn(`[SaveDebug] 弹窗返回为空，大概率是用户取消了保存`);
      }
    } catch (e) {
      // 抛异常，非用户取消
      logger.error(`[SaveDebug] ❌ 发生异常！错误码: ${e.code}, 错误信息: ${e.message}`);
      logger.error(`[SaveDebug] 完整错误堆栈: ${JSON.stringify(e)}`);
    }
  }

  private async removeTask(task: DownloadRecordInfo) {
    if (!this.context) return;
    const db = getDownloadRecordTable(this.context);
    // 在途直连任务：标记取消，结果到达后丢弃
    if (this.isDirectTaskId(task.task_id) && this.directRunning.has(task.task_id)) {
      this.directCancelled.add(task.task_id);
    }
    // 直连任务：撤销通知栏通知（系统任务的通知由 request.agent 自行管理）
    if (this.isDirectTaskId(task.task_id)) {
      await downloadNotifier.cancel(task.task_id);
    }
    this.taskCache.delete(task.task_id);
    try { await request.agent.remove(task.task_id); } catch (e) { /* ignore */ }
    await this.deleteFile(task.filePath);
    if (task.id) await db.deleteByID(task.id);
    this.tasks = this.tasks.filter(f => f.task_id !== task.task_id);
  }

  private async deleteFile(filePath: string | undefined) {
    if (!filePath) return;
    try {
      if (fs.accessSync(filePath)) await fs.unlink(filePath);
    } catch (e) {
      logger.warn("Delete file failed", e);
    }
  }

  /**
   * 从 URL 中提取分 P 索引
   * 例如: https://.../xxx_p0.jpg -> 0, https://.../xxx_p12.jpg -> 12
   */
  private getPageFromUrl(url: string): number {
    const pageMatch = url.match(/_p(\d+)/);
    return pageMatch ? parseInt(pageMatch[1]) : 0;
  }

  /**
   * @param ids 待删除的任务ID列表
   * 底层辅助函数：根据 任务ID 列表批量删除任务
   * 负责删文件、删数据库、更新内存列表
   */
  private async batchDeleteTasksByIds(ids: string[]) {
    if (ids.length === 0) return;

    logger.info(`batchDeleteTasksByIds: 开始批量删除 ${ids.length} 个任务`);

    for (const id of ids) {
      const task = this.tasks.find(d => d.task_id === id);
      if (task) {
        try {
          // 复用单条删除（里面包含了删系统任务、删文件、删DB、更新 this.tasks）
          await this.removeTask(task);
        } catch (e) {
          logger.error(`batchDeleteTasksByIds: 删除任务失败 id: ${id}, err:${JSON.stringify(e)}`);
        }
      }
    }
  }

  /** 提取公共的下载任务配置 */
  private getTaskConfig(url: string, fileName: string, filePath: string): request.agent.Config {
    return {
      action: request.agent.Action.DOWNLOAD,
      url: url,
      title: fileName,
      saveas: filePath,
      headers: this.PIXIV_HEADERS,
      retry: true,
      gauge: true,
      mode: request.agent.Mode.BACKGROUND,
      overwrite: true,
    };
  }

  /**
   * 执行实际的下载任务创建逻辑
   * 混合路由：直连域名（网络模式非标准）走应用内下载，其余走 request.agent 系统下载
   */
  private async _createDownloadTask(context: common.Context, illustInfo: PixivIllust, rawUrl: string, pageIndex: number) {
    if (!this.downloadDir) await this.initDownLoad(context);
    const db = getDownloadRecordTable(context);
    // 配置了自定义图床源时改写 URL（request.agent 走系统网络，镜像图床不受 SNI 阻断影响）
    const url = appSettings.picture_source === DEFAULT_IMAGE_HOST
      ? rawUrl : ImageUtils.rewriteImageUrl(rawUrl, appSettings.picture_source);
    const fileName = this._generateSafeFileName(illustInfo, url);
    const filePath = `${this.downloadDir}/${fileName}`;

    try {
      if (this.shouldUseDirect(url)) {
        await this._createDirectTask(db, illustInfo, url, pageIndex, filePath);
        return;
      }

      let task = await request.agent.create(context, this.getTaskConfig(url, fileName, filePath));

      const record = new DownloadRecordInfo();
      record.task_id = task.tid;
      record.illust_id = illustInfo.id;
      record.page = pageIndex; // 保存分P索引到数据库，下次启动才能正确查重
      record.title = illustInfo.title;
      record.artistName = illustInfo.user?.name;
      record.artist_avatar = illustInfo.user?.profile_image_urls?.medium;
      record.thumbnail = illustInfo.image_urls?.medium || illustInfo.image_urls?.large;
      record.filePath = filePath;
      record.url = url;
      record.status = request.agent.State.INITIALIZED;
      record.create_time = Date.now();

      await db.insert(record);

      // 插入到内存列表头部，@Trace 数组变化会自动传导给 @Computed displayList
      this.tasks.unshift(record);
      toastUtil.showToast({ message: $r('app.string.download_now', illustInfo.title) });

      await this.attachTask(task);
      await this.TryRunTask(task);
      // 拉起轮询兜底，确保事件回调异常时状态依然能及时同步
      this.startLiveSync();
    } catch (e) {
      logger.error("Add Task Error", e);
    }
  }

  /**
   * 创建应用内直连下载任务（request.agent 无法注入 SNI-less/ECH 参数，直连域名由应用接管）
   * 复用同一套 DownloadRecordInfo 记录与状态枚举，UI/数据库无感知
   */
  private async _createDirectTask(
    db: DownloadRecordTable,
    illustInfo: PixivIllust,
    url: string,
    pageIndex: number,
    filePath: string
  ) {
    const record = new DownloadRecordInfo();
    record.task_id = `${DIRECT_TASK_PREFIX}${Date.now()}-${Math.floor(Math.random() * 100000)}`;
    record.illust_id = illustInfo.id;
    record.page = pageIndex;
    record.title = illustInfo.title;
    record.artistName = illustInfo.user?.name;
    record.artist_avatar = illustInfo.user?.profile_image_urls?.medium;
    record.thumbnail = illustInfo.image_urls?.medium || illustInfo.image_urls?.large;
    record.filePath = filePath;
    record.url = url;
    record.status = request.agent.State.INITIALIZED;
    record.progress = 0;
    record.create_time = Date.now();

    await db.insert(record);
    this.tasks.unshift(record);
    toastUtil.showToast({ message: $r('app.string.download_now', illustInfo.title) });
    logger.info(`direct download task created: ${record.task_id} -> ${url}`);

    await this.tryRunDirectTask(record);
    this.startLiveSync();
  }

  /**
   * 尝试启动直连任务：并发额度与系统下载任务共享（max_download_count）
   * 有空位时立即启动（不 await 下载完成），否则留在 INITIALIZED 等待补位调度
   */
  private async tryRunDirectTask(record: DownloadRecordInfo): Promise<boolean> {
    if (this.directRunning.has(record.task_id)) return false;
    if (!record.url || !record.filePath) return false;
    const sysRunning = await request.agent
      .search({ state: request.agent.State.RUNNING })
      .catch((): string[] => []);
    if (this.directRunning.size + sysRunning.length >= Number(appSettings.max_download_count)) {
      return false;
    }
    this.directRunning.add(record.task_id);
    record.status = request.agent.State.RUNNING;
    // 直连恢复/重启即整包重下：进度必须归零，否则残留高进度会挡住 pct > record.progress 守卫，
    // 造成 UI 与通知双双卡死（实测事故：暂停于 99% 后恢复，进度全程不再更新）
    record.progress = 0;
    // 重置通知状态（重启/恢复场景解除收尾守卫）并发布 0% 进度（首次触发通知授权弹窗；被拒后静默降级）
    downloadNotifier.reset(record.task_id);
    this.notifyDirectProgress(record, 0, 0, -1);
    this.runDirectDownload(record); // 后台执行，结束时自行收尾并触发补位
    return true;
  }

  /**
   * 直连下载执行体：
   * 先探测总大小（Range: bytes=0-0），超过分段阈值走 Range 分段并发下载
   * （GFW 对该链路按单连接限速 ~40KB/s，多连接聚合带宽且分块失败可独立重试），
   * 小文件/探测失败则单请求全量拉取。
   */
  private async runDirectDownload(record: DownloadRecordInfo) {
    const taskId = record.task_id;
    const downloadReferer = 'https://www.pixiv.net/';
    try {
      // 1. 探测总大小（Content-Range: bytes 0-0/TOTAL）
      let totalSize = -1;
      try {
        const probe = await pixiv.fetchRange(record.url, 0, 0, downloadReferer, undefined,
          (): boolean => this.directCancelled.has(taskId));
        if (this.directCancelled.has(taskId)) {
          logger.info(`direct download cancelled, discard result: ${taskId}`);
          return;
        }
        totalSize = probe.totalSize;
        logger.info(`direct download probe: ${taskId}, total ${totalSize} bytes`);
      } catch (e) {
        logger.warn(`direct download probe failed, fallback to single fetch: ${taskId}`, e);
      }

      // 2. 按大小分流
      if (totalSize > DIRECT_CHUNK_SIZE) {
        await this.runChunkedDirectDownload(record, totalSize, downloadReferer);
      } else {
        // 小文件或探测失败：开放区间一次性拉取（bytes=0-，兼容忽略 Range 的服务器）
        const res = await pixiv.fetchRange(record.url, 0, -1, downloadReferer, (received: number): void => {
          // 字节级进度：单请求路径没有分块完成事件，靠接收回调驱动进度
          if (totalSize > 0) {
            const pct = Math.min(99, Math.floor((received / totalSize) * 100));
            if (pct > record.progress) {
              record.progress = pct;
              this.notifyDirectProgress(record, pct, received, totalSize);
            }
          }
        }, (): boolean => this.directCancelled.has(taskId));
        if (this.directCancelled.has(taskId)) {
          logger.info(`direct download cancelled, discard result: ${taskId}`);
          return;
        }
        if (res.body.byteLength === 0) {
          throw new Error('empty response body');
        }
        this.writeDirectFile(record.filePath, res.body);
        logger.info(`direct download finished(single): ${taskId}, ${res.body.byteLength} bytes`);
      }

      if (this.directCancelled.has(taskId)) {
        logger.info(`direct download cancelled, discard result: ${taskId}`);
        return;
      }
      // 通知栏先行置为已完成：文件已落盘即算下载完成，
      // onTaskCompleted 内的相册保存弹窗会阻塞等待用户操作，不应拖住通知
      this.notifyDirectFinished(record, true);
      await this.onTaskCompleted(record);
    } catch (e) {
      if (!this.directCancelled.has(taskId)) {
        record.status = request.agent.State.FAILED;
        await this.persistStatus(taskId, request.agent.State.FAILED);
        logger.error(`direct download failed: ${taskId}`, e);
        toastUtil.showToast({ message: `「${record.title || '未命名'}」下载失败` });
        this.notifyDirectFinished(record, false);
      }
    } finally {
      this.directRunning.delete(taskId);
      this.directCancelled.delete(taskId);
      this.TryRunNextTask();
    }
  }

  /**
   * Range 分段并发下载：多个 worker 从共享游标领取分块，按偏移写盘，
   * 单块失败独立重试 3 次，任一块最终失败则整体失败（JS 单线程，游标自增无竞态）。
   * 进度为字节级：已完成分块 + 各 worker 在途已收字节聚合（destination 流式回调驱动），
   * 单调递增防止在途回调乱序导致进度回退。
   */
  private async runChunkedDirectDownload(record: DownloadRecordInfo, totalSize: number, referer: string) {
    const taskId = record.task_id;
    const chunkCount = Math.ceil(totalSize / DIRECT_CHUNK_SIZE);
    const fd = fs.openSync(record.filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    let nextChunk = 0;
    let doneBytes = 0;
    let failed = false;
    let firstError: Error | undefined = undefined;
    // 各 worker 当前在途分块的已收字节数（重试时清零重计）
    const inFlight: number[] = new Array<number>(DIRECT_CHUNK_CONCURRENCY).fill(0);
    const refreshProgress = (): void => {
      let inflight = 0;
      for (let i = 0; i < inFlight.length; i++) {
        inflight += inFlight[i];
      }
      const received = doneBytes + inflight;
      const pct = Math.min(99, Math.floor((received / totalSize) * 100));
      if (pct > record.progress) {
        record.progress = pct;
        this.notifyDirectProgress(record, pct, received, totalSize);
      }
    };

    const worker = async (w: number): Promise<void> => {
      while (!failed) {
        if (this.directCancelled.has(taskId)) {
          return;
        }
        const idx = nextChunk;
        nextChunk += 1;
        if (idx >= chunkCount) {
          return;
        }

        const start = idx * DIRECT_CHUNK_SIZE;
        const end = Math.min(start + DIRECT_CHUNK_SIZE, totalSize) - 1;
        const expect = end - start + 1;
        // 分块级重试（链路 RST 是常态，小块重试代价低）
        for (let attempt = 0; attempt <= 2; attempt++) {
          if (this.directCancelled.has(taskId)) {
            return;
          }
          try {
            inFlight[w] = 0;
            const res = await pixiv.fetchRange(record.url, start, end, referer, (received: number): void => {
              if (received > 0) {
                inFlight[w] = received;
                refreshProgress();
              }
            }, (): boolean => this.directCancelled.has(taskId), w);
            if (this.directCancelled.has(taskId)) {
              return;
            }
            if (res.body.byteLength !== expect) {
              throw new Error(`chunk ${idx} size mismatch: ${res.body.byteLength} != ${expect}`);
            }
            fs.writeSync(fd.fd, res.body, { offset: start, length: expect });
            inFlight[w] = 0;
            doneBytes += expect;
            refreshProgress();
            break;
          } catch (e) {
            if (this.directCancelled.has(taskId)) {
              return;
            }
            inFlight[w] = 0;
            if (attempt === 2) {
              failed = true;
              firstError = e instanceof Error ? e : new Error(JSON.stringify(e));
              logger.error(`direct chunk ${idx} failed after retries: ${taskId}`, e);
              return;
            }
            logger.warn(`direct chunk ${idx} attempt ${attempt} failed, retrying: ${taskId}`);
            await new Promise<void>((resolve) => setTimeout(resolve, 1000 * (attempt + 1)));
          }
        }
      }
    };

    try {
      const workers: Promise<void>[] = [];
      for (let w = 0; w < DIRECT_CHUNK_CONCURRENCY; w++) {
        workers.push(worker(w));
      }
      await Promise.all(workers);
    } finally {
      fs.closeSync(fd);
    }

    if (failed) {
      throw firstError ?? new Error('chunked download failed');
    }
    record.progress = 100;
    logger.info(`direct download finished(chunked): ${taskId}, ${totalSize} bytes, ${chunkCount} chunks`);
  }

  /** 整包写盘（小文件路径复用） */
  private writeDirectFile(filePath: string, bytes: ArrayBuffer) {
    const fd = fs.openSync(filePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
    try {
      fs.writeSync(fd.fd, bytes);
    } finally {
      fs.closeSync(fd);
    }
  }

  /** 生成文件名 */
  private _generateSafeFileName(illustInfo: PixivIllust, url: string): string {
    // 获取后缀名
    const extension = url.split('.').pop() || 'jpg';
    // 只提取页码数字部分（如 _p0 → "0"，_p12 → "12"）
    const pageMatch = url.match(/_p(\d+)/);

    // 提取并安全化各个字段
    const safeIllustId = `${illustInfo.id}`;
    const safePart = pageMatch ? pageMatch[1] : '0'; // 纯数字，单图默认 "0"
    const safeUid = `${illustInfo.user?.id || '0'}`;

    // 安全过滤：去除非法字符和点号，保留空格
    const safeTitle = (illustInfo.title || 'Untitled')
      .replace(/[\\/:*?"<>|.]+/g, '_')
      .trim()
      .replace(/\s+/g, ' ')
      .replace(/^_|_$/g, '');
    const safeUserName = (illustInfo.user?.name || 'Pixiv')
      .replace(/[\\/:*?"<>|.]+/g, '_')
      .trim()
      .replace(/\s+/g, ' ')
      .replace(/^_|_$/g, '');

    // 读取模板，为空则使用默认模板
    const template = appSettings.file_name.trim() || '{illust_id}_p{part}_{title}_{user_name}';

    // 执行占位符替换
    let fileName = template
      .replace(/{illust_id}/g, safeIllustId)
      .replace(/{part}/g, safePart)
      .replace(/{title}/g, safeTitle)
      .replace(/{user_name}/g, safeUserName)
      .replace(/{uid}/g, safeUid);

    // 兜底防错（防止用户在设置页瞎填一堆非法字符导致替换完为空）
    if (!fileName || fileName.trim() === '') {
      fileName = `pixiv_${safeIllustId}_p${safePart}`;
    }

    return `${fileName}.${extension}`;
  }

}

export const downloaderVM = new DownloadsViewModel();
