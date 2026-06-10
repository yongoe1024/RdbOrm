import { relationalStore } from '@kit.ArkData'

export type SqlType = 'INTEGER' | 'TEXT' | 'REAL' | 'BLOB'

export interface ColumnMeta {
  property: string
  column: string
  type?: SqlType
  nullable?: boolean
  defaultValue?: relationalStore.ValueType
  unique?: boolean
  primaryKey?: boolean
  autoIncrement?: boolean
  /** boolean 字段读取时把 1/0 转回 true/false */
  enableBoolMapper?: boolean
}
