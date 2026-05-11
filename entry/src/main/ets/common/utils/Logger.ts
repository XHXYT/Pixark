/**
 * 日志条目接口
 */
export interface LogEntry {
  timestamp: Date;
  level: 'DEBUG' | 'INFO' | 'WARN' | 'ERROR';
  category: string;
  message: string;
  data?: any;
}

/**
 * 日志回调函数类型
 */
export type LogCallback = (log: LogEntry) => void;


/**
 * 日志工具
 */
export class Logger {
  private static instance: Logger;
  private callbacks: LogCallback[] = [];
  private currentLevel: number = 0; // DEBUG级别

  private constructor() {}

  static getInstance(): Logger {
    if (!Logger.instance) {
      Logger.instance = new Logger();
    }
    return Logger.instance;
  }

  clearCallback() {
    this.callbacks = []
  }

  // 添加/移除回调
  addCallback(callback: LogCallback): void {
    this.callbacks.push(callback);
  }

  removeCallback(callback: LogCallback): void {
    const index = this.callbacks.indexOf(callback);
    if (index > -1) {
      this.callbacks.splice(index, 1);
    }
  }

  setLevel(level: 'DEBUG' | 'INFO' | 'WARN' | 'ERROR'): void {
    const levels = { DEBUG: 0, INFO: 1, WARN: 2, ERROR: 3 };
    this.currentLevel = levels[level];
  }

  getLevel() {
    return this.currentLevel
  }

  // 核心日志方法
  private log(level: 'DEBUG' | 'INFO' | 'WARN' | 'ERROR', category: string, message: string, data?: any): void {
    const levels = { DEBUG: 0, INFO: 1, WARN: 2, ERROR: 3 };

    if (levels[level] < this.currentLevel) {
      return;
    }

    const logEntry: LogEntry = {
      timestamp: new Date(),
      level,
      category,  // 用于区分不同模块
      message,
      data
    };

    // 发送给所有回调
    this.callbacks.forEach(callback => {
      try {
        callback(logEntry);
      } catch (error) {
        console.error('日志回调错误:', error);
      }
    });

    // 控制台输出
    this.logToConsole(logEntry);
  }

  private logToConsole(log: LogEntry): void {
    const timeStr = log.timestamp.toLocaleTimeString();
    // 构建基础消息部分
    let message = `[${timeStr}] ${log.level} [${log.category}] ${log.message}`;

    // 当 data 存在且不为 null 时，尝试序列化
    if (log.data !== undefined && log.data !== null) {
      try {
        const serializedData = JSON.stringify(log.data);
        // 检查序列化结果是否有效（防止函数、Symbol等返回undefined）
        if (serializedData !== undefined) {
          // 在一切正常时，追加一个空格和序列化后的数据
          message += ` ${serializedData}`;
        }
      } catch (error) {
        // 如果数据是循环引用等无法序列化的对象，JSON.stringify会抛出异常
        message += ` [无法序列化的数据: ${error.message}]`;
      }
    }

    // 将最终格式化好的消息输出到控制台
    switch (log.level) {
      case 'DEBUG':
        console.debug(message);
        break;
      case 'INFO':
        console.info(message);
        break;
      case 'WARN':
        console.warn(message);
        break;
      case 'ERROR':
        console.error(message);
        break;
    }
  }

  // 公共日志方法
  debug(category: string, message: string, data?: any): void {
    this.log('DEBUG', category, message, data);
  }

  info(category: string, message: string, data?: any): void {
    this.log('INFO', category, message, data);
  }

  warn(category: string, message: string, data?: any): void {
    this.log('WARN', category, message, data);
  }

  error(category: string, message: string, data?: any): void {
    this.log('ERROR', category, message, data);
  }

}


/**
 * 便捷的 Logger 工厂函数
 * @param category 模块名/分类名
 */
export function createLogger(category: string) {
  const logger = Logger.getInstance();

  return {
    debug: (msg: string, data?: any) => logger.debug(category, msg, data),
    info:  (msg: string, data?: any) => logger.info(category, msg, data),
    warn:  (msg: string, data?: any) => logger.warn(category, msg, data),
    error: (msg: string, data?: any) => logger.error(category, msg, data),
  };
}


