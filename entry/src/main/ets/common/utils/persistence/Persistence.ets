// From 小白工坊子模块

import { PersistenceV2 } from "@kit.ArkUI"
import { TypeConstructorWithArgs } from "@ohos.arkui.StateManagement"

// 获取持久化的状态
export function getPersistence<T extends object>(type: TypeConstructorWithArgs<T>,  defaultFactory:(() =>T) | undefined = undefined): T | undefined {
  try {
    return PersistenceV2.connect(type, type.name, defaultFactory)
  }catch (e) {
    return undefined
  }
}

// 手动持久化
export function savePersistence<T extends object>(keyOrType: string | TypeConstructorWithArgs<T>) {
  PersistenceV2.save(keyOrType)
}