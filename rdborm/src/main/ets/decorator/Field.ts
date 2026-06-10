import { FieldParams } from '../model/FieldParams'
import { getOrInitOwnMeta } from '../model/MetaData'
import { ColumnMeta } from '../model/ColumnMeta'

/**
 * 字段装饰器：声明实体属性与表列的映射。
 *
 * 与 `@Id` 叠加时（任一顺序）：`@Field` 提供列类型 / 名称 / nullable / defaultValue / unique / enableBoolMapper；
 * `@Id` 在同一列上加主键标记。如果 `@Id` 先跑过，本装饰器会**增量补全**已有的主键占位列，而不是重复创建。
 */
export function Field(data?: FieldParams) {
  return function (target: ESObject, propertyKey: string) {
    const meta = getOrInitOwnMeta(target)
    const existing = meta.findByProperty(propertyKey)

    if (existing) {
      if (!existing.primaryKey) {
        // 普通字段重复装饰
        throw new Error(`@Field 重复声明：${propertyKey}`)
      }
      // @Id 先跑了，本次 @Field 增量补全列属性
      if (data?.name) {
        existing.column = data.name
      }
      if (data?.type !== undefined) {
        existing.type = data.type
      }
      if (data?.defaultValue !== undefined) {
        existing.defaultValue = data.defaultValue
      }
      // 主键列忽略以下属性（主键专属约束已自带，或与主键逻辑冲突）：
      //   - nullable：PK 强制 NOT NULL（INTEGER PK 在 DDL 层享受 ROWID 别名特殊待遇）
      //   - unique：PK 隐含唯一，写 UNIQUE 是冗余 DDL
      //   - enableBoolMapper：主键不会是 boolean
      //   - autoIncrement：由 @Id 单独管理，Field 不干预
      //      （非 INTEGER PK 写了 autoIncrement 也没关系——DDL 生成侧 buildColumnDefSql 会兜底过滤）
      return
    }

    // 普通字段路径
    const column: ColumnMeta = {
      property: propertyKey,
      column: data?.name || propertyKey,
      type: data?.type,
      nullable: data?.nullable,
      defaultValue: data?.defaultValue,
      unique: data?.unique,
      enableBoolMapper: data?.enableBoolMapper,
      primaryKey: false,
      autoIncrement: false,
    }
    meta.columns.push(column)
  }
}
