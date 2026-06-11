import { relationalStore } from '@kit.ArkData'

/**
 * sql字段类型
 */
export type SqlType = 'INTEGER' | 'TEXT' | 'REAL' | 'BLOB'

/**
 * 字段元数据
 */
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

/**
 * 实体类元数据，由 @Table / @Field / @Id 装饰器写入到原型
 */
export class MetaData {
  tableName: string = ''
  columns: ColumnMeta[] = []

  findByProperty(property: string): ColumnMeta | undefined {
    for (let i = 0; i < this.columns.length; i++) {
      if (this.columns[i].property === property) {
        return this.columns[i]
      }
    }
    return undefined
  }

  findPrimaryKey(): ColumnMeta | undefined {
    for (let i = 0; i < this.columns.length; i++) {
      if (this.columns[i].primaryKey) {
        return this.columns[i]
      }
    }
    return undefined
  }

  /**
   * 校验元数据完整性并返回主键列（无主键返回 `undefined`）；不合法时抛错
   *
   * 由 `RdbOrm.build` 在创建 ORM 前调用
   */
  validate(className: string): ColumnMeta | undefined {
    if (!this.tableName || this.tableName.trim().length === 0) {
      throw new Error(`实体类 ${className} 缺少 @Table(name) 声明`)
    }
    if (this.columns.length === 0) {
      throw new Error(`实体类 ${className} 至少需要一个 @Field 或 @Id`)
    }
    const columnNames = new Set<string>()
    const propertyNames = new Set<string>()
    let primaryKey: ColumnMeta | undefined = undefined
    for (let i = 0; i < this.columns.length; i++) {
      const c = this.columns[i]
      if (!c.column || c.column.trim().length === 0) {
        throw new Error(`实体类 ${className}.${c.property} 列名不能为空`)
      }
      if (columnNames.has(c.column)) {
        throw new Error(`实体类 ${className} 列名重复：${c.column}`)
      }
      if (propertyNames.has(c.property)) {
        throw new Error(`实体类 ${className} 属性重复：${c.property}`)
      }
      columnNames.add(c.column)
      propertyNames.add(c.property)
      // 装饰器期 @Id 已保证至多一个主键，这里只需取出
      if (c.primaryKey) {
        primaryKey = c
      }
    }
    return primaryKey
  }
}

/**
 * 读取或初始化 target 自身的 __meta__
 *
 * **不支持继承，不沿原型链向上查找**
 */
export function getOrInitOwnMeta(target: ESObject): MetaData {
  if (!Object.prototype.hasOwnProperty.call(target, '__meta__')) {
    target.__meta__ = new MetaData()
  }
  return target.__meta__ as MetaData
}

/**
 * 只读地获取 target 自身的 __meta__
 *
 * **不支持继承，不沿原型链向上查找**
 */
export function getOwnMeta(target: ESObject): MetaData | undefined {
  if (Object.prototype.hasOwnProperty.call(target, '__meta__')) {
    return target.__meta__ as MetaData
  }
  return undefined
}
