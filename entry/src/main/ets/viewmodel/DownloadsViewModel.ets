import { request } from "@kit.BasicServicesKit";
import { common } from '@kit.AbilityKit';
import { fileUri, fileIo as fs } from "@kit.CoreFileKit";
import { getDownloadRecordTable } from "../utils/database/impl/DownloadRecordTable";
import DownloadRecordInfo from "../entity/DownloadRecordInfo";
import { PixivIllust } from "../services/PixivTypes";
import { createLogger } from "../utils/Logger";
import { photoAccessHelper } from "@kit.MediaLibraryKit";
import { toastUtil } from "../utils/ToastUtils";
import { getPersistence } from "../utils/persistence/Persistence";
import { AppSettings } from "../utils/persistence/SettingsModel";

const logger = createLogger('DownloadsViewModel')


@ObservedV2
export class DownloadsViewModel {
  @Trace tasks: DownloadRecordInfo[] = []
  @Trace currentPage: number = 0
  private downloadDir = ""
  private maxTaskCount = 3
  private context: common.Context | null = null

  @Trace appConfig: AppSettings = getPersistence(AppSettings, () => new AppSettings())!

  /**
   * 初始化下载目录
   */
  async initDownLoad(context: common.Context) {
    this.context = context
    try {
      this.downloadDir = `${context.filesDir}/Pixiv/Pictures`;
      if (!fs.accessSync(this.downloadDir)) {
        fs.mkdirSync(this.downloadDir);
      }
    } catch (e) {
      logger.error("initDownLoad Error:", e)
    }
  }

  async getFileUri(filePath: string | undefined): Promise<string> {
    if (!filePath) return '';
    return fileUri.getUriFromPath(filePath);
  }

  filterTask() {
    const statusMap: Record<string, number[]> = {
      "downloading": [request.agent.State.RUNNING, request.agent.State.RETRYING],
      "completed": [request.agent.State.COMPLETED],
      "error": [request.agent.State.STOPPED, request.agent.State.FAILED]
    };
    const targetStatus = statusMap[this.currentPage || ''];
    if (targetStatus) {
      return this.tasks.filter(d => targetStatus.includes(d.status));
    }
    return this.tasks;
  }

  /**
   * 获取任务列表：先从数据库读取元数据，再从系统服务同步状态
   */
  async fetchSysTask() {
    if (!this.context) return
    const context = this.context
    const db = getDownloadRecordTable(context);
    // 从数据库加载所有记录
    let dbRecords = await db.queryAllDesc();

    // 从系统服务获取真实状态
    const sysTaskMap = new Map<string, request.agent.TaskInfo>();
    const types = [
      request.agent.State.RUNNING, request.agent.State.FAILED, request.agent.State.PAUSED,
      request.agent.State.COMPLETED, request.agent.State.STOPPED, request.agent.State.RETRYING,
      request.agent.State.WAITING, request.agent.State.INITIALIZED,
    ];

    try {
      const taskIds = await Promise.all(types.map((s) => request.agent.search({ state: s })));
      const flatIds = taskIds.flat();

      // 批量获取系统任务详情
      const sysTasks = await Promise.all(flatIds.map(id => request.agent.show(id).catch(() => null)));

      sysTasks.forEach(task => {
        if (task) sysTaskMap.set(task.tid, task);
      });

      // 合并数据：数据库记录 + 系统实时状态
      this.tasks = dbRecords.map(record => {
        const sysTask = sysTaskMap.get(record.taskId);
        if (sysTask) {
          record.status = sysTask.progress.state;
          // 如果在运行中，可以尝试计算进度百分比
          if (sysTask.progress.sizes && sysTask.progress.sizes.length > 0) {
            const total = sysTask.progress.sizes[0];
            if(total > 0) record.progress = Math.floor((sysTask.progress.processed / total) * 100);
          }
        } else {
          // 系统里没有，但数据库里有，说明任务丢失或已完成被清理
          if (record.status !== request.agent.State.COMPLETED) {
            record.status = request.agent.State.FAILED; // 标记为失败
          }
        }
        return record;
      }).sort((a, b) => b.createTime - a.createTime);

      // 重新挂载监听
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

  async getSysTask(id: string | undefined): Promise<request.agent.Task | undefined> {
    if (!id) return;
    if (!this.context) return
    try {
      return await request.agent.getTask(this.context, id);
    } catch (e) {
      return;
    }
  }

  async pauseSysTask(id: string) {
    const task = await this.getSysTask(id);
    task?.pause();
  }

  async resumeSysTask(id: string) {
    const task = await this.getSysTask(id);
    if (task) this.TryRunTask(task, true);
  }

  async restartSysTask(id: string) {
    const task = await this.getSysTask(id);
    if (task) this.TryRunTask(task);
  }

  async pauseAllSysTask() {
    const taskIds = await request.agent.search({ state: request.agent.State.RUNNING });
    for (let id of taskIds) {
      const result = await this.getSysTask(id);
      if (result) {
        this.attachTask(result);
        await result.pause();
      }
    }
  }

  async resumeAllSysTask(context: common.Context) {
    const taskIds = await request.agent.search({ state: request.agent.State.PAUSED });
    for (let id of taskIds) {
      const result = await this.getSysTask(id);
      if (result) {
        this.attachTask(result);
        await this.TryRunTask(result, true);
        await new Promise<void>((res) => setTimeout(res, 100));
      }
    }
  }

  async restartAllSysTask() {
    const taskIds = await Promise.all([
      request.agent.State.FAILED, request.agent.State.STOPPED
    ].map((s) => request.agent.search({ state: s })));

    for (let ids of taskIds) {
      for (let id of ids) {
        const result = await this.getSysTask(id);
        if (result) {
          this.attachTask(result);
          await this.TryRunTask(result);
        }
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

  async removeTask(task: DownloadRecordInfo) {
    if (!this.context) return
    const db = getDownloadRecordTable(this.context);
    // 删除系统任务
    try { await request.agent.remove(task.taskId); } catch (e) {}
    // 删除本地文件
    await this.deleteFile(task.filePath);
    // 删除数据库记录
    if (task.id) await db.deleteByID(task.id);
    // 更新内存列表
    this.tasks = this.tasks.filter(f => f.taskId !== task.taskId);
  }

  async attachSysTask(id: string) {
    const task = await this.getSysTask(id);
    if (task) this.attachTask(task);
  }

  async attachTask(task: request.agent.Task) {
    if (!this.context) return

    this.unAttackTask(task);
    const db = getDownloadRecordTable(this.context);

    task.on('progress', (progress) => {
      let target = this.tasks.find(d => d.taskId === task.tid);
      if (target) {
        if (progress.sizes && progress.sizes.length > 0) {
          const total = progress.sizes[0];
          if(total > 0) target.progress = Math.floor((progress.processed / total) * 100);
        }
      }
    });

    task.on('completed', async (progress) => {
      let target = this.tasks.find(d => d.taskId === task.tid);
      if (target) {
        target.status = request.agent.State.COMPLETED;
        target.progress = 100;
        await db.updateStatus(task.tid, request.agent.State.COMPLETED);
        // 保存到系统相册
        await this.saveImageToGallery(target.filePath, target.title);
      }
      this.TryRunNextTask();
    });

    task.on('pause', (progress) => {
      let target = this.tasks.find(d => d.taskId === task.tid);
      if (target) target.status = request.agent.State.PAUSED;
      db.updateStatus(task.tid, request.agent.State.PAUSED);
      this.TryRunNextTask();
    });

    task.on('resume', (progress) => {
      let target = this.tasks.find(d => d.taskId === task.tid);
      if (target) target.status = request.agent.State.RUNNING;
      db.updateStatus(task.tid, request.agent.State.RUNNING);
    });

    task.on('failed', async (progress) => {
      let target = this.tasks.find(d => d.taskId === task.tid);
      if (target) target.status = request.agent.State.FAILED;
      await db.updateStatus(task.tid, request.agent.State.FAILED);
      this.TryRunNextTask();
    });

    task.on('remove', (progress) => {
      // 通常由 removeTask 主动触发，这里仅做内存移除
      this.tasks = this.tasks.filter(d => d.taskId !== task.tid);
      this.TryRunNextTask();
    });
  }

  /**
   * 添加 Pixiv 图片下载任务
   */
  async addTask(context: common.Context, illustInfo: PixivIllust, url: string, customFileName?: string) {
    if (!this.downloadDir) await this.initDownLoad(context);
    const db = getDownloadRecordTable(context);

    const fileName = this._generateSafeFileName(illustInfo, url, customFileName);
    logger.debug(`addTask fileName: ${fileName}`)
    const filePath = `${this.downloadDir}/${fileName}`;

    const headers: Record<string, string> = {
      "Referer": "https://www.pixiv.net/",
      "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    };

    try {
      // 创建系统任务
      let task = await request.agent.create(context, {
        action: request.agent.Action.DOWNLOAD,
        url: url,
        title: fileName,
        saveas: filePath,
        headers: headers,
        retry: true,
        gauge: true,
        mode: request.agent.Mode.BACKGROUND,
        overwrite: true,
      });
      // 构造数据库实体
      const record = new DownloadRecordInfo();
      record.taskId = task.tid
      record.illustId = illustInfo.id
      record.title = illustInfo.title
      record.artistName = illustInfo.user?.name
      record.artistAvatar = illustInfo.user?.profile_image_urls?.medium
      record.thumbnail = illustInfo.image_urls?.medium || illustInfo.image_urls?.large
      record.filePath = filePath
      record.url = url
      record.status = request.agent.State.INITIALIZED
      record.createTime = Date.now()
      // 存入数据库
      await db.insert(record);
      // 更新内存列表
      this.tasks.unshift(record);
      // 开始任务
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
      let running = await this.TryRunTask(sysTask);
      if (running) {
        let target = this.tasks.find(d => d.taskId === sysTask.tid);
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
    task.off('progress');
    task.off('completed');
    task.off('failed');
    task.off('pause');
    task.off('resume');
    task.off('remove');
  }

  /**
   * 将沙箱文件保存到系统相册
   */
  private async saveImageToGallery(localPath: string, title: string) {
    if (!localPath) return;
    if (!this.context) return
    try {
      const phAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.context);
      // 直接从路径提取文件名，无需重新拼接或生成时间戳
      // localPath 格式: /.../PID_p0_Title_Artist.jpg
      const fileName = localPath.substring(localPath.lastIndexOf('/') + 1);
      const lastDot = fileName.lastIndexOf('.');
      const safeTitle = lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
      const extension = lastDot > 0 ? fileName.substring(lastDot + 1) : 'jpg';

      const srcFileUris: Array<string> = [fileUri.getUriFromPath(localPath)];

      const photoCreationConfigs: Array<photoAccessHelper.PhotoCreationConfig> = [
        {
          title: safeTitle, // 使用提取好的文件名
          fileNameExtension: extension,
          photoType: photoAccessHelper.PhotoType.IMAGE,
          subtype: photoAccessHelper.PhotoSubtype.DEFAULT,
        }
      ];

      let desFileUris = await phAccessHelper.showAssetsCreationDialog(srcFileUris, photoCreationConfigs);
      this.appConfig.imagePath
      if (desFileUris && desFileUris.length > 0) {
        const destUri = desFileUris[0];
        const srcFd = fs.openSync(localPath, fs.OpenMode.READ_ONLY);
        const destFd = await fs.open(destUri, fs.OpenMode.WRITE_ONLY);
        await fs.copyFile(srcFd.fd, destFd.fd);
        fs.closeSync(srcFd);
        await fs.close(destFd.fd);
        logger.info('Image saved to gallery success: ' + destUri);
        await this.deleteFile(localPath);
        // 作品标题
        toastUtil.showToast({ message: $r('app.string.save_success', title) });
      }
    } catch (e) {
      logger.warn('Save to gallery failed or cancelled', e);
    }
  }

  /**
   * 统一生成安全的文件名
   * @param illustInfo 插画信息
   * @param url 图片URL
   * @param customFileName 自定义文件名(可选)
   * @returns 格式化后的文件名，如: PID_p0_Title_Artist.jpg
   */
  private _generateSafeFileName(illustInfo: PixivIllust, url: string, customFileName?: string): string {
    if (customFileName) return customFileName;
    // 提取扩展名
    const extension = url.split('.').pop() || 'jpg';
    // Pixiv URL 格式通常为 .../12345_p0.jpg
    // 提取页码 (如 12345_p0)
    const pageMatch = url.match(/(\d+_p\d+)/);
    const pageStr = pageMatch ? pageMatch[0] : '';
    // 构造基础名称
    const artist = illustInfo.user?.name || 'Pixiv';
    const title = illustInfo.title || 'Untitled';
    // 去除文件名中的非法字符 \ / : * ? " < > |
    const safeArtist = artist.replace(/[\\/:*?"<>|]/g, '');
    const safeTitle = title.replace(/[\\/:*?"<>|]/g, '');
    // 提示
    toastUtil.showToast({ message: $r('app.string.download_now', title) });
    // 严格按照顺序拼接：ID + 页码 + 标题 + 画师
    return `${pageStr}_${safeTitle}_${safeArtist}.${extension}`;
  }


}

export const downloaderVM = new DownloadsViewModel();
