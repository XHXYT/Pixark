import { Context } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { request } from '@kit.BasicServicesKit';
import { createLogger } from '../common/utils/Logger';
import { _PixState } from '../entryability/AppState';
import { SearchHistoryTable } from '../common/utils/database/impl/SearchHistoryDao';
import { IllustHistoryTable } from '../common/utils/database/impl/IllustHistoryDao';
import { DownloadRecordTable, getDownloadRecordTable } from '../common/utils/database/impl/DownloadRecordTable';
import { toastUtil } from '../common/utils/ToastUtils';
import { AppSettings, appSettings } from '../common/entity/SettingsModel';
import IllustHistoryInfo from '../common/entity/IllustHistoryInfo';
import SearchHistoryInfo from '../common/entity/SearchHistoryInfo';
import DownloadRecordInfo from '../common/entity/DownloadRecordInfo';
import { util } from '@kit.ArkTS';

const logger = createLogger('AppDataViewModel');

/** 定义导入数据结构 */
interface ImportDataStructure {
  illustHistory?: Array<IllustHistoryInfo>;
  searchHistory?: Array<SearchHistoryInfo>;
  downloadRecords?: Array<DownloadRecordInfo>;
  settings?: AppSettings;
}

@ObservedV2
export class AppDataViewModel {
  private context: Context = _PixState.Context;
  private searchHistoryDB = new SearchHistoryTable(this.context);
  private illustHistoryDB = new IllustHistoryTable(this.context);
  private downloadRecordDB: DownloadRecordTable = getDownloadRecordTable(this.context);

  @Trace imageCacheSize: string = '计算中...';
  @Trace pictureCacheSize: string = '计算中...';

  private getDateStr(): string {
    const d = new Date();
    return `${d.getFullYear()}${(d.getMonth() + 1).toString().padStart(2, '0')}${d.getDate().toString().padStart(2, '0')}`;
  }

  /** 格式化文件大小 */
  private formatSize(totalSize: number): string {
    if (totalSize < 1024) return `${totalSize} B`;
    else if (totalSize < 1024 * 1024) return `${(totalSize / 1024).toFixed(1)} KB`;
    else return `${(totalSize / 1024 / 1024).toFixed(1)} MB`;
  }

  /** 读取文件并解析为严格的 ImportDataStructure */
  private async readJsonFile(uri: string): Promise<ImportDataStructure | null> {
    try {
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      const stat = fs.statSync(file.fd);
      const buffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      fs.closeSync(file);
      const textDecoder = util.TextDecoder.create('utf-8');
      const jsonStr = textDecoder.decodeToString(new Uint8Array(buffer));
      logger.info(`[Import] Read JSON start: ${jsonStr.substring(0, 200)}`);
      const parsedObj = JSON.parse(jsonStr) as ImportDataStructure;
      if (parsedObj instanceof Object) {
        logger.info(`[Import] Parsed keys: ${Object.keys(parsedObj).join(',')}`);
        return parsedObj as ImportDataStructure;
      }
      logger.error('[Import] Parsed object is not an Object');
      return null;
    } catch (e) {
      logger.error('ReadJsonFile failed', e);
      return null;
    }
  }

  /** 保存数据到文件 */
  private async saveFile<T>(data: T, defaultFileName: string) {
    let file: fs.File | null = null;
    try {
      const documentSaveOptions = new picker.DocumentSaveOptions();
      documentSaveOptions.newFileNames = [defaultFileName];
      const documentViewPicker = new picker.DocumentViewPicker(this.context);
      const uris: Array<string> = await documentViewPicker.save(documentSaveOptions);
      if (uris && uris.length > 0) {
        // 使用TRUNC，覆盖写入时清空文件旧内容，防止旧数据尾巴拼接！
        file = fs.openSync(uris[0], fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE | fs.OpenMode.TRUNC);

        let datas = JSON.stringify(data as Object, null, 2);
        datas = AppDataViewModel.cleanAndFixJson(datas);

        const textEncoder = new util.TextEncoder();
        const uint8Array = textEncoder.encodeInto(datas);
        const safeBuffer = uint8Array.buffer.slice(0, uint8Array.byteLength);
        fs.writeSync(file.fd, safeBuffer);
        fs.fsyncSync(file.fd);
        toastUtil.showToast({ message: '导出成功' });
      }
    } catch (e) {
      logger.error('SaveFile cancelled or failed', e);
    } finally {
      if (file) {
        fs.closeSync(file);
      }
    }
  }

  private async pickAndReadFile(): Promise<ImportDataStructure | null> {
    try {
      const documentSelectOptions = new picker.DocumentSelectOptions();
      documentSelectOptions.maxSelectNumber = 1;
      documentSelectOptions.fileSuffixFilters = ['.json'];
      const documentViewPicker = new picker.DocumentViewPicker(this.context);
      const uris: Array<string> = await documentViewPicker.select(documentSelectOptions);
      if (uris && uris.length > 0) {
        return await this.readJsonFile(uris[0]);
      }
    } catch (e) {
      logger.error('PickFile cancelled or failed', e);
      toastUtil.showToast({ message: '导入取消或文件读取失败' });
    }
    return null;
  }

  // 浏览历史
  async exportIllustHistory() {
    const data = await this.illustHistoryDB.queryAllByAccessTimeDesc();
    await this.saveFile({ illustHistory: data } as Partial<ImportDataStructure>, `PixArk_浏览历史_${this.getDateStr()}.json`);
  }

  async importIllustHistory() {
    const data = await this.pickAndReadFile();
    logger.info(`[Import] IllustHistory data exists: ${!!data?.illustHistory}, isArray:${Array.isArray(data?.illustHistory)}`);
    if (data?.illustHistory && Array.isArray(data.illustHistory)) {
      logger.info(`[Import] IllustHistory length: ${data.illustHistory.length}`);

      let updateCount = 0;
      let insertCount = 0;

      for (const item of data.illustHistory) {
        // 它内部会根据 pid 查询，存在则更新，不存在则新增
        const existingItems = await this.illustHistoryDB.queryByPid(item.pid);
        if (existingItems.length > 0) {
          updateCount++;
        } else {
          insertCount++;
        }
        item.id = existingItems.length > 0 ? existingItems[0].id : null;
        await this.illustHistoryDB.save(item);
      }

      toastUtil.showToast({ message: `导入完成：新增 ${insertCount} 条，更新${updateCount} 条` });
    } else {
      toastUtil.showToast({ message: '文件格式不正确' });
    }
  }

  // 搜索记录
  async exportSearchHistory() {
    const data = await this.searchHistoryDB.queryAll();
    await this.saveFile({ searchHistory: data } as Partial<ImportDataStructure>, `PixArk_搜索记录_${this.getDateStr()}.json`);
  }

  async importSearchHistory() {
    const data = await this.pickAndReadFile();
    if (data?.searchHistory && Array.isArray(data.searchHistory)) {
      let insertCount = 0;
      let updateCount = 0;

      for (const item of data.searchHistory) {
        // 查询本地是否已有该关键词
        const existing = await this.searchHistoryDB.query(
          this.searchHistoryDB.getPredicates().equalTo('keyword', item.keyword)
        );
        if (existing.length > 0) {
          // 已存在：如果导入的访问时间更新，则更新本地记录的时间
          const localItem = existing[0];
          if (item.accessTime > localItem.accessTime) {
            localItem.accessTime = item.accessTime;
            await this.searchHistoryDB.update(localItem);
            updateCount++;
          }
        } else {
          // 不存在：直接插入，保留原始时间
          item.id = null;
          await this.searchHistoryDB.insert(item);
          insertCount++;
        }
      }

      toastUtil.showToast({ message: `导入完成：新增 ${insertCount} 条，更新${updateCount} 条` });
    } else {
      toastUtil.showToast({ message: '文件格式不正确' });
    }
  }

  // 下载记录
  async exportDownloadRecords() {
    const data = await this.downloadRecordDB.queryAllDesc();
    await this.saveFile({ downloadRecords: data } as Partial<ImportDataStructure>, `PixArk_下载记录_${this.getDateStr()}.json`);
  }

  async importDownloadRecords() {
    const data = await this.pickAndReadFile();
    if (data?.downloadRecords && Array.isArray(data.downloadRecords)) {
      let insertCount = 0;
      let skipCount = 0;

      for (const item of data.downloadRecords) {
        // 下载记录按 illust_id 判重，如果本地已经有了，就跳过不再导入
        const existing = await this.downloadRecordDB.query(
          this.downloadRecordDB.getPredicates().equalTo('illust_id', item.illust_id)
        );

        if (existing.length > 0) {
          skipCount++;
          continue; // 跳过重复项
        }
        // 不存在则新增，并重置下载状态
        item.id = null;
        item.task_id = `imported_${Date.now()}_${Math.random()}`;
        item.status = request.agent.State.FAILED;
        item.progress = 0;
        item.filePath = '';
        await this.downloadRecordDB.insert(item);
        insertCount++;
      }
      toastUtil.showToast({ message: `导入完成：新增 ${insertCount} 条，跳过${skipCount} 条重复` });
    } else {
      toastUtil.showToast({ message: '文件格式不正确' });
    }
  }

  // 偏好设置
  async exportSettings() {
    await this.saveFile({ settings: appSettings } as Partial<ImportDataStructure>, `PixArk_偏好设置_${this.getDateStr()}.json`);
  }

  async importSettings() {
    const data = await this.pickAndReadFile();
    if (data?.settings && typeof data.settings === 'object') {
      toastUtil.showToast({ message: '偏好设置导入成功' });
    } else {
      toastUtil.showToast({ message: '文件格式不正确' });
    }
  }

  // 缓存管理
  /**
   * 计算缓存大小
   * @param dir 不传则计算全部，传 'ImageKnife' 或 'Pixiv/Pictures' 计算指定目录
   */
  async calculateCacheSize(dir?: string) {
    if (!dir) {
      // 并发计算两个
      await Promise.all([
        this.calculateCacheSize('ImageKnife'),
        this.calculateCacheSize('Pixiv/Pictures')
      ]);
      return;
    }

    try {
      let totalSize = 0;
      const targetDir = `${this.context.filesDir}/${dir}`;

      const calculateDirSize = (currentDir: string) => {
        try {
          // 目录不存在则跳过
          if (!fs.accessSync(currentDir)) return;
          const files = fs.listFileSync(currentDir);
          for (const file of files) {
            const path = `${currentDir}/${file}`;
            const stat = fs.statSync(path);
            if (stat.isDirectory()) {
              calculateDirSize(path);
            } else {
              totalSize += stat.size;
            }
          }
        } catch (e) { /* 忽略无权限目录 */ }
      };

      calculateDirSize(targetDir);
      const sizeStr = this.formatSize(totalSize);

      if (dir === 'ImageKnife') {
        this.imageCacheSize = sizeStr;
      } else if (dir === 'Pixiv/Pictures') {
        this.pictureCacheSize = sizeStr;
      }
    } catch (e) {
      if (dir === 'ImageKnife') {
        this.imageCacheSize = '未知';
      } else if (dir === 'Pixiv/Pictures') {
        this.pictureCacheSize = '未知';
      }
    }
  }

  /**
   * 清理缓存
   * @param dir 不传则清理全部，传 'ImageKnife' 或 'Pixiv/Pictures' 清理指定目录
   */
  async clearCache(dir?: string) {
    if (!dir) {
      await Promise.all([
        this.clearCache('ImageKnife'),
        this.clearCache('Pixiv/Pictures')
      ]);
      return;
    }

    try {
      const cacheDir = `${this.context.filesDir}/${dir}`;
      if (!fs.accessSync(cacheDir)) {
        toastUtil.showToast({ message: '目录不存在，无需清理' });
        await this.calculateCacheSize(dir);
        return;
      }

      const files = fs.listFileSync(cacheDir);
      for (const file of files) {
        const filePath = `${cacheDir}/${file}`;
        try {
          const stat = fs.statSync(filePath);
          // ImageKnife 等库可能会有子目录，如果是目录需递归删除，否则直接删文件
          if (stat.isDirectory()) {
            // 简易递归删除子目录内容
            const subFiles = fs.listFileSync(filePath);
            for (const subFile of subFiles) {
              fs.unlinkSync(`${filePath}/${subFile}`);
            }
          }
          fs.unlinkSync(filePath);
        } catch (e) {
          logger.warn(`清理子文件失败: ${filePath}`, e);
        }
      }

      toastUtil.showToast({ message: '缓存已清理' });
      await this.calculateCacheSize(dir);
    } catch (e) {
      toastUtil.showToast({ message: '清理失败' });
    }
  }

  // 清理和修复JSON字符串的方法
  private static cleanAndFixJson(jsonStr: string): string {
    // 去除响应式属性
    let cleanedStr = jsonStr
      .replace(/"__ob_/g, '"')  // 移除 "__ob_" 前缀
      .replace(/"___watch__obj_":\{[^}]*\},?/g, ''); // 移除 "___watch__obj_{...}" 键值对
    // 修复多余的逗号
    cleanedStr = cleanedStr.replace(/,(\s*[}\]])/g, '$1');

    return cleanedStr;
  }

}

export const appDataVM = new AppDataViewModel();
