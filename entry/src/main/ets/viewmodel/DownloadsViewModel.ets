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
  @Trace tasks: DownloadRecordInfo[] = []
  @Trace currentPage: number = 0
  private downloadDir = ""
  private maxTaskCount = 3
  private context: common.Context | null = null

  // 公共请求头
  private readonly HTTP_HEADERS: Record<string, string> = {
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

  async getFileUri(filePath: string | undefined): Promise<string> {
    return filePath ? fileUri.getUriFromPath(filePath) : '';
  }

  filterTask() {
    const statusMap: Record<string, number[]> = {
      "downloading": [request.agent.State.RUNNING, request.agent.State.RETRYING],
      "completed": [request.agent.State.COMPLETED],
      "error": [request.agent.State.STOPPED, request.agent.State.FAILED]
    };
    const targetStatus = statusMap[this.currentPage || ''];
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

  async pauseSysTask(id: string) {
    (await this.getSysTask(id))?.pause();
  }

  async resumeSysTask(id: string) {
    const task = await this.getSysTask(id);
    if (task) this.TryRunTask(task, true);
  }

  async restartSysTask(id: string) {
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

  // 独立的丢失任务重建方法
  private async recreateLostTask(record: DownloadRecordInfo) {
    if (!record.url || !this.context) {
      record.status = request.agent.State.FAILED;
      return;
    }
    logger.info(`restartSysTask: 系统任务丢失, 使用链接重建: ${record.url}`);

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
      logger.error(`restartSysTask: 重建失败. ${JSON.stringify(e)}`);
      record.status = request.agent.State.FAILED;
    }
  }

  async pauseAllSysTask() {
    const taskIds = await request.agent.search({ state: request.agent.State.RUNNING });
    for (let id of taskIds) {
      const task = await this.getSysTask(id);
      if (task) { this.attachTask(task); await task.pause(); }
    }
  }

  async resumeAllSysTask(context: common.Context) {
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

  async restartAllSysTask() {
    const states = [request.agent.State.FAILED, request.agent.State.STOPPED];
    const taskIds = (await Promise.all(states.map(s => request.agent.search({ state: s })))).flat();
    for (let id of taskIds) {
      const task = await this.getSysTask(id);
      if (task) { this.attachTask(task); await this.TryRunTask(task); }
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

  async removeTask(task: DownloadRecordInfo) {
    if (!this.context) return;
    const db = getDownloadRecordTable(this.context);
    try { await request.agent.remove(task.taskId); } catch (e) { /* ignore */ }
    await this.deleteFile(task.filePath);
    if (task.id) await db.deleteByID(task.id);
    this.tasks = this.tasks.filter(f => f.taskId !== task.taskId);
  }

  async attachSysTask(id: string) {
    const task = await this.getSysTask(id);
    if (task) this.attachTask(task);
  }

  async attachTask(task: request.agent.Task) {
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

  async TryRunNextTask() {
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

  async TryRunTask(task: request.agent.Task, resume: boolean = false) {
    const running = await request.agent.search({ state: request.agent.State.RUNNING });
    if (running.length < this.maxTaskCount) {
      resume ? await task.resume() : await task.start();
      return true;
    }
    return false;
  }

  unAttackTask(task: request.agent.Task) {
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
      headers: this.HTTP_HEADERS,
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
