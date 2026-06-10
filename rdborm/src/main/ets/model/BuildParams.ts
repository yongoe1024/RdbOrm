import { relationalStore } from '@kit.ArkData'
import { Context } from '@kit.AbilityKit'

/**
 * RdbOrm.build 参数
 */
export interface BuildParams<T> {
  context: Context
  class: new () => T
  config: relationalStore.StoreConfig
  /** 开启后会通过 hilog 输出每条 SQL 与参数 */
  debugSql?: boolean
}
