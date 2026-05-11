import { emitter } from "@kit.BasicServicesKit";
import { createLogger } from "./Logger";

const logger = createLogger('EventHub')

export enum EventKey {
  FetchData = 10000,

}

export class EventHub {

  static sendEvent(key: EventKey, data: any = null) {
    if (canIUse("SystemCapability.Notification.Emitter")) {
      emitter.emit({ eventId: key }, { data: data })
    } else {
      logger.warn('当前设备不支持 emitter.emit')
    }
  }

  static on(key: EventKey,callback: (data: any) => void, once: boolean = true) {
    if (once) {
      if (canIUse("SystemCapability.Notification.Emitter")) {
        emitter.off(key)
      } else {
        logger.warn('当前设备不支持 emitter.off')
      }
    }
    if (canIUse("SystemCapability.Notification.Emitter")) {
      emitter.on({ eventId: key }, (data) => {
        callback(data.data)
      })
    } else {
      logger.warn('当前设备不支持 emitter.on')
    }
  }

  static off(key: EventKey) {
    if (canIUse("SystemCapability.Notification.Emitter")) {
      emitter.off(key)
    } else {
      logger.warn('当前设备不支持 emitter.off')
    }
  }

}