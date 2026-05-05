import { request } from "@kit.BasicServicesKit";
import { common } from '@kit.AbilityKit';
import { fileUri, fileIo as fs } from "@kit.CoreFileKit";
import { getDownloadRecordTable } from "../utils/database/impl/DownloadRecordTable";
import DownloadRecordInfo from "../entity/DownloadRecordInfo";
import { PixivIllust } from "../services/PixivTypes";
import { createLogger } from "../utils/Logger";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { toastUtil } from "../utils/ToastUtils";

const logger = createLogger('DownloadsViewModel')

@ObservedV2
export class DownloadsViewModel {

  @Trace selectedIds: Set<string> = new Set()
  @Trace tasks: DownloadRecordInfo[] = []

  @Trace isEditMode: boolean = false
  @Trace currentPage: number = 0

  private downloadDir = ""
  private maxTaskCount = 5
  private context: common.Context | null = null

  // 公共请求头
  private readonly PIXIV_HEADERS: Record<string, string> = {
    "Referer": "https://www.pixiv.net/",
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  };

  /** 切换编辑模式 */
  toggleEditMode() {
    this.isEditMode = !this.isEditMode;
    this.selectedIds.clear();
  }

  /** 切换选中状态 */
  toggleSelect(taskId: string) {
    if (this.selectedIds.has(taskId)) {
      this.selectedIds.delete(taskId);
    } else {
      this.selectedIds.add(taskId);
    }
  }

  /** 判断是否选中 */
  isSelected(taskId: string): boolean {
    return this.selectedIds.has(taskId); // O(1) 复杂度
  }

  /** 全选当前页面 */
  selectAllVisible() {
    this.selectedIds.clear();
    this.filterTask().forEach(task => this.selectedIds.add(task.taskId));
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
    const selectedTasks = this.tasks.filter(t => this.selectedIds.has(t.taskId));
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

  /** 批量删除 */
  async batchRemoveSelectedTasks() {
    if (this.selectedIds.size === 0) return;

    const idsToDelete = Array.from(this.selectedIds);
    logger.info(`batchRemoveSelectedTasks: 开始批量删除 ${idsToDelete.length} 个任务`);

    for (const id of idsToDelete) {
      const task = this.tasks.find(d => d.taskId === id);
      if (task) {
        try {
          await this.removeTask(task);
        } catch (e) {
          logger.error(`batchRemove: 删除任务失败 id: ${id}, err:${JSON.stringify(e)}`);
        }
      }
    }
    // 批量删除完毕后，自动退出编辑模式并清空选中集
    // this.toggleEditMode();
  }

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

  async getFileUri(filePath: string | undefined): Promise<string> {
    return filePath ? fileUri.getUriFromPath(filePath) : '';
  }

  filterTask() {
    // 0=所有, 1=下载中, 2=已完成, 3=失败
    const statusList: (number[] | null)[] = [
      null,                                                            // 0: 所有 (不进行过滤)
      [request.agent.State.RUNNING, request.agent.State.RETRYING],    // 1: 下载中
      [request.agent.State.COMPLETED],                                 // 2: 已完成
      [request.agent.State.STOPPED, request.agent.State.FAILED]       // 3: 失败
    ];
    // 获取当前 Tab 对应的状态数组
    const targetStatus = statusList[this.currentPage] ?? null;
    logger.debug(`filterTask 当前分组：${this.currentPage} targetStatus: ${JSON.stringify(targetStatus)}`)
    // 如果是 null (所有) 或者未定义，直接返回全量 tasks
    return targetStatus ? this.tasks.filter(d => targetStatus.includes(d.status)) : this.tasks;
  }

  /** 获取任务列表 */
  async fetchSysTask() {
    if (!this.context) return;
    const db = getDownloadRecordTable(this.context);
    let dbRecords = await db.queryAllDesc();

    const stateTypes = [
      request.agent.State.RUNNING, request.agent.State.FAILED, request.agent.State.PAUSED,
      request.agent.State.COMPLETED, request.agent.State.STOPPED, request.agent.State.RETRYING,
      request.agent.State.WAITING, request.agent.State.INITIALIZED,
    ];
    try {
      const taskIds = (await Promise.all(stateTypes.map(s => request.agent.search({ state: s })))).flat();
      const sysTasks = await Promise.all(taskIds.map(id => request.agent.show(id).catch(() => null)));

      const sysTaskMap = new Map<string, request.agent.TaskInfo>();
      sysTasks.forEach(task => {
        if (task) {
          sysTaskMap.set(task.tid, task);
        }
      });

      this.tasks = dbRecords.map(record => {
        const sysTask = sysTaskMap.get(record.taskId);
        if (sysTask) {
          record.status = sysTask.progress.state;
          if (sysTask.progress.sizes && sysTask.progress.sizes.length > 0) {
            const total = sysTask.progress.sizes[0];
            if (total > 0) {
              record.progress = Math.floor((sysTask.progress.processed / total) * 100);
            }
          }
        } else if (record.status !== request.agent.State.COMPLETED) {
          record.status = request.agent.State.FAILED;
        }
        return record;
      }).sort((a, b) => b.createTime - a.createTime);

      this.tasks.forEach(record => {
        if (record.status !== request.agent.State.COMPLETED &&
          record.status !== request.agent.State.FAILED &&
          record.status !== request.agent.State.STOPPED) {
          this.attachSysTask(record.taskId);
        }
      });
    } catch (e) {
      logger.error("fetchSysTask failed", e);
    }
  }

  private async getSysTask(id: string | undefined): Promise<request.agent.Task | undefined> {
    if (!id || !this.context) return undefined;
    try {
      return await request.agent.getTask(this.context, id);
    } catch (e) {
      return undefined;
    }
  }

  async pauseTask(id: string) {
    (await this.getSysTask(id))?.pause();
  }

  // 恢复任务
  async resumeTask(id: string) {
    const task = await this.getSysTask(id);
    if (task) this.TryRunTask(task, true);
  }

  // 重启任务
  async restartTask(id: string) {
    if (!this.context) return;
    const record = this.tasks.find(d => d.taskId === id);
    if (!record) return;

    const task = await this.getSysTask(id);
    if (task) {
      this.TryRunTask(task);
    } else {
      await this.recreateLostTask(record);
    }
  }

  async removeTask(task: DownloadRecordInfo) {
    if (!this.context) return;
    const db = getDownloadRecordTable(this.context);
    try { await request.agent.remove(task.taskId); } catch (e) { /* ignore */ }
    await this.deleteFile(task.filePath);
    if (task.id) await db.deleteByID(task.id);
    this.tasks = this.tasks.filter(f => f.taskId !== task.taskId);
  }

  async pauseAllTask() {
    const taskIds = await request.agent.search({ state: request.agent.State.RUNNING });
    for (let id of taskIds) {
      const task = await this.getSysTask(id);
      if (task) { this.attachTask(task); await task.pause(); }
    }
  }

  async resumeAllTask() {
    const taskIds = await request.agent.search({ state: request.agent.State.PAUSED });
    for (let id of taskIds) {
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
        await this.restartTask(task.taskId);
      } catch (e) {
        toastUtil.showToast({ message: `任务 ${task.title} 重试失败`})
        // 防止某一个任务重试时抛出异常中断了整个批量循环
        logger.error(`restartAllSysTask: 单个任务重试异常 taskId: ${task.taskId}, err: ${JSON.stringify(e)}`);
      }
    }
  }

  /** 清空所有已完成的任务 */
  async clearAllCompletedTasks() {
    // 筛选出所有已完成的任务
    const completedTasks = this.tasks.filter(d => d.status === request.agent.State.COMPLETED);

    if (completedTasks.length === 0) {
      logger.info("clearAllCompletedTasks: 没有已完成的任务需要清理");
      return;
    }

    logger.info(`clearAllCompletedTasks: 开始清空 ${completedTasks.length} 个已完成任务`);

    // 遍历复用单条删除逻辑
    for (const task of completedTasks) {
      try {
        await this.removeTask(task);
      } catch (e) {
        // 防止某个任务删除异常（比如文件被强占）中断整个循环
        logger.error(`clearAllCompletedTasks: 清理任务异常 taskId: ${task.taskId}, err: ${JSON.stringify(e)}`);
      }
    }
  }

  async deleteFile(filePath: string | undefined) {
    if (!filePath) return;
    try {
      if (fs.accessSync(filePath)) await fs.unlink(filePath);
    } catch (e) {
      logger.warn("Delete file failed", e);
    }
  }

  async attachSysTask(id: string) {
    const task = await this.getSysTask(id);
    if (task) this.attachTask(task);
  }

  /** 添加 Pixiv 图片下载任务 */
  async addTask(context: common.Context, illustInfo: PixivIllust, url: string, customFileName?: string) {
    if (!this.downloadDir) await this.initDownLoad(context);
    const db = getDownloadRecordTable(context);

    const fileName = this._generateSafeFileName(illustInfo, url, customFileName);
    const filePath = `${this.downloadDir}/${fileName}`;

    try {
      let task = await request.agent.create(context, this.getTaskConfig(url, fileName, filePath));

      const record = new DownloadRecordInfo();
      record.taskId = task.tid;
      record.illustId = illustInfo.id;
      record.title = illustInfo.title;
      record.artistName = illustInfo.user?.name;
      record.artistAvatar = illustInfo.user?.profile_image_urls?.medium;
      record.thumbnail = illustInfo.image_urls?.medium || illustInfo.image_urls?.large;
      record.filePath = filePath;
      record.url = url;
      record.status = request.agent.State.INITIALIZED;
      record.createTime = Date.now();

      await db.insert(record);
      this.tasks.unshift(record);

      // Toast 副作用放在业务逻辑层
      toastUtil.showToast({ message: $r('app.string.download_now', illustInfo.title) });

      await this.attachTask(task);
      await this.TryRunTask(task);
    } catch (e) {
      logger.error("Add Task Error", e);
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

      record.taskId = newTask.tid;
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
    this.unAttackTask(task);
    const db = getDownloadRecordTable(this.context);

    task.on('progress', (progress) => {
      const target = this.tasks.find(d => d.taskId === task.tid);
      if (target && progress.sizes && progress.sizes.length > 0) {
        const total = progress.sizes[0];
        if (total > 0) target.progress = Math.floor((progress.processed / total) * 100);
      }
    });

    task.on('completed', async () => {
      const target = this.tasks.find(d => d.taskId === task.tid);
      if (target) {
        target.status = request.agent.State.COMPLETED;
        target.progress = 100;
        await db.updateStatus(task.tid, request.agent.State.COMPLETED);
        await this.saveImageToGallery(target.filePath, target.title);
      }
      this.TryRunNextTask();
    });

    task.on('pause', () => {
      const target = this.tasks.find(d => d.taskId === task.tid);
      if (target) target.status = request.agent.State.PAUSED;
      db.updateStatus(task.tid, request.agent.State.PAUSED);
      this.TryRunNextTask();
    });

    task.on('resume', () => {
      const target = this.tasks.find(d => d.taskId === task.tid);
      if (target) target.status = request.agent.State.RUNNING;
      db.updateStatus(task.tid, request.agent.State.RUNNING);
    });

    task.on('failed', async () => {
      const target = this.tasks.find(d => d.taskId === task.tid);
      if (target) target.status = request.agent.State.FAILED;
      await db.updateStatus(task.tid, request.agent.State.FAILED);
      this.TryRunNextTask();
    });

    task.on('remove', () => {
      this.tasks = this.tasks.filter(d => d.taskId !== task.tid);
      this.TryRunNextTask();
    });
  }

  private async TryRunNextTask() {
    const waiting = await request.agent.search({ state: request.agent.State.INITIALIZED });
    if (waiting.length === 0) return;
    const sysTask = await this.getSysTask(waiting.pop());
    if (sysTask) {
      const started = await this.TryRunTask(sysTask);
      if (started) {
        const target = this.tasks.find(d => d.taskId === sysTask.tid);
        if (target) target.status = request.agent.State.RUNNING;
      }
    }
  }

  private async TryRunTask(task: request.agent.Task, resume: boolean = false) {
    const running = await request.agent.search({ state: request.agent.State.RUNNING });
    if (running.length < this.maxTaskCount) {
      resume ? await task.resume() : await task.start();
      return true;
    }
    return false;
  }

  private unAttackTask(task: request.agent.Task) {
    task.off('progress'); task.off('completed'); task.off('failed');
    task.off('pause'); task.off('resume'); task.off('remove');
  }

  /** 将沙箱文件保存到系统相册 */
  private async saveImageToGallery(localPath: string, title: string) {
    if (!localPath || !this.context) return;
    try {
      const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.context);
      const fileName = localPath.substring(localPath.lastIndexOf('/') + 1);
      const dotIndex = fileName.lastIndexOf('.');
      const safeTitle = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
      const extension = dotIndex > 0 ? fileName.substring(dotIndex + 1) : 'jpg';

      let desFileUris = await phAccessHelper.showAssetsCreationDialog(
        [fileUri.getUriFromPath(localPath)],
        [{ title: safeTitle, fileNameExtension: extension, photoType: photoAccessHelper.PhotoType.IMAGE, subtype: photoAccessHelper.PhotoSubtype.DEFAULT }]
      );

      if (desFileUris && desFileUris.length > 0) {
        const destUri = desFileUris[0];
        const srcFd = fs.openSync(localPath, fs.OpenMode.READ_ONLY);
        const destFd = await fs.open(destUri, fs.OpenMode.WRITE_ONLY);
        await fs.copyFile(srcFd.fd, destFd.fd);
        fs.closeSync(srcFd);
        await fs.close(destFd.fd);

        await this.deleteFile(localPath);
        toastUtil.showToast({ message: $r('app.string.save_success', title) });
      }
    } catch (e) {
      logger.warn('Save to gallery failed or cancelled', e);
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

  /** 纯函数：仅负责生成文件名 */
  private _generateSafeFileName(illustInfo: PixivIllust, url: string, customFileName?: string): string {
    if (customFileName) return customFileName;
    const extension = url.split('.').pop() || 'jpg';
    const pageMatch = url.match(/(_p\d+)/);
    const pageStr = pageMatch ? `${illustInfo.id}${pageMatch[0]}` : `${illustInfo.id}`;

    const safeArtist = (illustInfo.user?.name || 'Pixiv').replace(/[\\/:*?"<>|]/g, '');
    const safeTitle = (illustInfo.title || 'Untitled').replace(/[\\/:*?"<>|]/g, '');

    return `${pageStr}_${safeTitle}_${safeArtist}.${extension}`;
  }

}

export const downloaderVM = new DownloadsViewModel();
