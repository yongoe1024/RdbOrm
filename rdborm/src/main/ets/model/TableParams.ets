import { BuildParams } from './BuildParams'
import { ColumnMeta } from './ColumnMeta'

/**
 * 内部参数：build 之后传给 DBHelper 的完整描述
 */
export interface TableParams<T> {
  buildParams: BuildParams<T>
  tableName: string
  columns: ColumnMeta[]
  primaryKey?: ColumnMeta
}
