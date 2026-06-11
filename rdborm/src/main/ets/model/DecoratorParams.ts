import { relationalStore } from '@kit.ArkData'
import { SqlType } from './MetaData'

/**
 * @Field 装饰器参数
 */
export interface FieldParams {
  name?: string
  /** SQL 列类型 */
  type: SqlType
  nullable?: boolean
  defaultValue?: relationalStore.ValueType
  unique?: boolean
  /**
   * 开启TS-boolean 与 SQL-INTEGER 映射
   *
   * 仅对 boolean 字段有效：开启后，**查询结果**里的 1/0 会被转回 `true`/`false`
   */
  enableBoolMapper?: boolean
}

/**
 * @Id 装饰器参数
 *
 * 只负责标注主键，必须与同属性上的 `@Field` 叠加使用
 */
export interface IdParams {
  /**
   * 是否自增，必填。非 INTEGER 主键无效
   */
  autoIncrement: boolean
}
