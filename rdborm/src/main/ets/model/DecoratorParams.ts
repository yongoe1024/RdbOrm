import { relationalStore } from '@kit.ArkData'
import { SqlType } from './ColumnMeta'

/**
 * @Field 装饰器参数
 */
export interface FieldParams {
  name?: string
  type?: SqlType
  nullable?: boolean
  defaultValue?: relationalStore.ValueType
  unique?: boolean
  /**
   * 仅对 boolean 字段使用：开启后，**查询结果**里的 1/0 会被转回 `true`/`false`，
   * 让 TS 端永远拿到 boolean。写入与 Wrapper 条件不需要转换（HarmonyOS 底层接受 JS boolean）。
   *
   * 列类型必须是 `INTEGER`（boolean 在 SQLite 里就是存 INTEGER），其它类型上写了也无意义。
   */
  enableBoolMapper?: boolean
}

/**
 * @Id 装饰器参数
 *
 * `@Id` 只负责标注主键。列的类型 / 名称 / nullable / defaultValue
 * 全部由叠加在同一属性上的 `@Field` 提供。`@Id` 自身只关心主键专属语义：是否 AUTOINCREMENT。
 */
export interface IdParams {
  /**
   * 写入用户意图；非 INTEGER 主键即便写 `true`，DDL 生成侧 `buildColumnDefSql` 也会自动过滤掉 AUTOINCREMENT
   * （SQLite 规范只允许 INTEGER PK 带 AUTOINCREMENT）
   */
  autoIncrement?: boolean
}
