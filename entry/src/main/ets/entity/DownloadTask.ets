import { request } from '@kit.BasicServicesKit';

export class DownloadTask {
  /** 任务 ID */
  id: string = '';

  /** 文件名称 */
  fileName: string = '';

  /** 保存路径 */
  filePath: string = '';

  /** 任务状态 */
  status: request.agent.State = request.agent.State.INITIALIZED;

  /** 进度百分比字符串 (如 "50%") */
  progress: string = '0%';

  /** 文件总大小字符串 (如 "10.5 MB") */
  totalSize: string = '0 B';

  /** 任务创建时间戳 */
  create_time: number = 0;

  /** 状态更新时间戳 */
  status_update_time: number = 0;

  /** 失败原因 (如果有) */
  reason: string = '';

  // 内部计算速度用变量
  private lastTimeStamp: number = 0;
  private lastProcessedSize: number = 0;
  private currentSpeed: number = 0; // 字节/秒

  /**
   * 构造函数：将系统任务对象转换为 UI 模型
   * @param taskInfo 系统返回的任务信息 (通过 request.agent.show 获取)
   */
  constructor(taskInfo: request.agent.TaskInfo) {
    if (!taskInfo) return;

    this.id = taskInfo.tid;
    this.filePath = taskInfo.saveas || '';

    // 提取文件名：优先使用 title，否则从路径截取
    if (taskInfo.title) {
      this.fileName = taskInfo.title;
    } else {
      const parts = this.filePath.split('/');
      this.fileName = parts.pop() || '未知文件';
    }

    // 创建时间
    this.create_time = taskInfo.ctime || Date.now();

    // 初始化进度信息
    if (taskInfo.progress) {
      this.updateProgressInfo(taskInfo.progress);
      this.status = taskInfo.progress.state;
    }

    this.status_update_time = Date.now();

    // 如果是失败状态，记录原因
    if (taskInfo.reason) {
      this.reason = taskInfo.reason;
    }
  }

  /**
   * 设置状态
   */
  setStatus(status: request.agent.State) {
    this.status = status;
    this.status_update_time = Date.now();

    // 如果状态变为非运行中，重置速度
    if (status !== request.agent.State.RUNNING) {
      this.currentSpeed = 0;
    }
  }

  /**
   * 设置进度 (由 ViewModel 回调触发)
   * @param progress 系统进度对象
   * @param reason 失败原因 (可选)
   */
  setProgress(progress: request.agent.Progress, reason?: string) {
    this.updateProgressInfo(progress);
    this.status_update_time = Date.now();

    if (reason) {
      this.reason = reason;
    }
  }

  /**
   * 获取当前下载速度字符串
   * @returns 如 "1.2 MB/s" 或空字符串
   */
  getSpeed(): string {
    if (this.currentSpeed <= 0 || this.status !== request.agent.State.RUNNING) {
      return '';
    }
    return `${this.formatFileSize(this.currentSpeed)}/s`;
  }

  /**
   * 内部方法：更新进度数据和计算速度
   */
  private updateProgressInfo(progress: request.agent.Progress) {
    if (!progress) return;
    // 总大小取 sizes 数组的第一个元素 (单文件下载场景)
    // 如果是多文件任务，需要累加 sizes，
    const totalBytes = (progress.sizes && progress.sizes.length > 0) ? progress.sizes[0] : 0;
    const processedBytes = progress.processed;

    // 计算百分比
    if (totalBytes > 0) {
      const percent = Math.floor((processedBytes / totalBytes) * 100);
      this.progress = `${percent}%`;
      this.totalSize = this.formatFileSize(totalBytes);
    } else {
      this.progress = '0%';
      this.totalSize = '未知大小';
    }

    // 计算实时速度
    const currentTime = Date.now();
    const timeDiff = (currentTime - this.lastTimeStamp) / 1000; // 秒

    if (timeDiff > 0 && this.lastTimeStamp !== 0) {
      const sizeDiff = processedBytes - this.lastProcessedSize;
      this.currentSpeed = sizeDiff / timeDiff;
    }

    this.lastTimeStamp = currentTime;
    this.lastProcessedSize = processedBytes;
  }

  /**
   * 格式化文件大小
   */
  private formatFileSize(bytes: number): string {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }

}
