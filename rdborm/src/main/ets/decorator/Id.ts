import { IdParams } from '../model/FieldParams'
import { getOrInitOwnMeta } from '../model/MetaData'
import { ColumnMeta } from '../model/ColumnMeta'

/**
 * 主键装饰器：仅标注哪个属性是表主键。
 *
 * - 列的类型 / 名称 / nullable / defaultValue / unique / enableBoolMapper 由叠加的 `@Field` 提供
 * - `@Id` 仅 `autoIncrement?: boolean` 一个参数（DDL 生成侧会过滤掉非 INTEGER 主键的 AUTOINCREMENT，即使用户写了 `true` 也不会出现在 SQL 里）
 * - 推荐写法（任一顺序均可，效果一致）：
 *   ```ts
 *   @Field({ type: 'INTEGER' })
 *   @Id()
 *   id?: number
 *   ```
 * - 仅 `@Id()` 不叠加 `@Field` 时，等价 `INTEGER PRIMARY KEY AUTOINCREMENT`
 */
export function Id(data?: IdParams) {
  return function (target: ESObject, propertyKey: string) {
    const meta = getOrInitOwnMeta(target)

    const existingPk = meta.findPrimaryKey()
    if (existingPk && existingPk.property !== propertyKey) {
      throw new Error(`@Id 重复声明：已存在主键 ${existingPk.property}`)
    }

    const wantAutoIncrement = data?.autoIncrement !== false
    const existing = meta.findByProperty(propertyKey)

    if (existing) {
      if (existing.primaryKey) {
        throw new Error(`@Id 重复声明：${propertyKey}`)
      }
      // @Field 先跑了，把已存在的列升级为主键
      existing.primaryKey = true
      existing.nullable = false
      existing.unique = undefined // PK 隐含唯一，清除 @Field 可能设置的 unique 避免冗余 DDL
      // 若 @Field 未指定 type，默认 INTEGER（最常见的主键类型）
      if (existing.type === undefined) {
        existing.type = 'INTEGER'
      }
      existing.autoIncrement = wantAutoIncrement
    } else {
      // @Field 还没跑（或不会跑），建占位列；@Field 跑到时若指定属性会增量覆盖
      const placeholder: ColumnMeta = {
        property: propertyKey,
        column: propertyKey,
        type: 'INTEGER',
        nullable: false,
        primaryKey: true,
        autoIncrement: wantAutoIncrement,
      }
      meta.columns.push(placeholder)
    }
  }
}
