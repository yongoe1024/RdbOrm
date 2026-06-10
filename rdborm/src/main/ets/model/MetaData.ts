import { ColumnMeta } from './ColumnMeta'

/**
 * 实体类元数据，由 @Table / @Field / @Id 装饰器写入到原型 __meta__
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
}

/**
 * 取或初始化 target 自身的 __meta__。
 *
 * 关键点：用 `hasOwnProperty` 而不是 `target.__meta__ != null` 判断，避免在类继承时
 * 读到父类原型上的 MetaData，导致子类装饰器误改父类元数据。
 */
export function getOrInitOwnMeta(target: ESObject): MetaData {
  if (!Object.prototype.hasOwnProperty.call(target, '__meta__')) {
    target.__meta__ = new MetaData()
  }
  return target.__meta__ as MetaData
}

/**
 * 只读地获取 target 自身的 __meta__；**不沿原型链向上查找**。
 *
 * `RdbOrm.build` 用此函数读元数据，与装饰器写入端（`getOrInitOwnMeta`）保持
 * 同样的 own-property 严判语义：rdborm 不支持类继承共享元数据，子类必须
 * 自带装饰器；否则这里返回 `undefined`，由 build 抛出明确的"缺少装饰器"错误。
 */
export function getOwnMeta(target: ESObject): MetaData | undefined {
  if (Object.prototype.hasOwnProperty.call(target, '__meta__')) {
    return target.__meta__ as MetaData
  }
  return undefined
}
