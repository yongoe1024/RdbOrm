import { relationalStore } from "@kit.ArkData"
import { Context } from "@kit.AbilityKit"

/**
 * 构建参数
 */
export interface BuildParams<T> {
  context: Context
  class: new (...args: any) => T,
  config: relationalStore.StoreConfig,
}

