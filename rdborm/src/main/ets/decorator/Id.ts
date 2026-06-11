import { IdParams } from '../model/DecoratorParams'
import { getOrInitOwnMeta, ColumnMeta } from '../model/MetaData'

/**
 * 主键装饰器：标注表主键，**必须与同属性上的 `@Field` 叠加使用**
 *
 * `autoIncrement`仅对`INTEGER`类型有效
 */
export function Id(data: IdParams) {
  return function (target: ESObject, propertyKey: string) {
    const meta = getOrInitOwnMeta(target)

    const existingPk = meta.findPrimaryKey()
    if (existingPk && existingPk.property !== propertyKey) {
      throw new Error(`@Id 重复声明：已存在主键 ${existingPk.property}`)
    }

    const wantAutoIncrement = data.autoIncrement
    const existing = meta.findByProperty(propertyKey)

    if (existing) {
      if (existing.primaryKey) {
        throw new Error(`@Id 重复声明：${propertyKey}`)
      }
      // @Field 先跑了，把已存在的列升级为主键（type 由 @Field 提供，此处不再兜底）
      existing.primaryKey = true
      existing.nullable = false
      existing.unique = undefined // PK 隐含唯一，清除 @Field 可能设置的 unique 避免冗余 DDL
      existing.enableBoolMapper = undefined // 主键不会是 boolean，清除以与「@Id 先跑」路径保持顺序无关
      existing.autoIncrement = wantAutoIncrement
    } else {
      // @Id 先于 @Field 跑，建主键占位列；type 等列定义由随后的 @Field 增量补全
      const placeholder: ColumnMeta = {
        property: propertyKey,
        column: propertyKey,
        nullable: false,
        primaryKey: true,
        autoIncrement: wantAutoIncrement,
      }
      meta.columns.push(placeholder)
    }
  }
}
