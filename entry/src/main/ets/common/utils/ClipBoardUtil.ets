
import { pasteboard,BusinessError } from '@kit.BasicServicesKit';
import { createLogger } from './Logger';

const logger = createLogger('ClipBoardUtil');

/**
 * 剪贴板工具对象
 */
export class clipboard {

  /**
   * 复制文本到剪贴板
   * @param content 要复制的文本内容
   */
  static copyData(content: string): void {
    let systemPasteboard: pasteboard.SystemPasteboard = pasteboard.getSystemPasteboard();
    let pasteData: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, content);

    systemPasteboard.setData(pasteData).then(() => {
      logger.debug('Copy Succeeded in setting PasteData.');
    }).catch((err: BusinessError) => {
      logger.error('Copy Failed to set PasteData. Cause: ' + err.message);
    });
  }

}