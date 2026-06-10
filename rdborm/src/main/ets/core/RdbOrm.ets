import { BuildParams } from '../model/BuildParams'
import { DBHelper } from './DBHelper'
import { TableParams } from '../model/TableParams'
import { getOwnMeta } from '../model/MetaData'
import { ColumnMeta } from '../model/ColumnMeta'

/**
 * 一张表对应的 ORM 入口。通过 `RdbOrm.build` 创建，再用 `getDBHelper` 获取 `DBHelper`。
 */
export class RdbOrm<T> {
  private params: TableParams<T>

  private constructor(params: TableParams<T>) {
    this.params = params
  }

  /**
   * 解析实体类装饰器并创建 ORM 操作对象。校验失败时抛错。
   */
  static build<T>(buildParams: BuildParams<T>): RdbOrm<T> {
    const className = (buildParams.class as ESObject).name as string
    // 只读 target 自身的 __meta__，**不沿原型链向上查找**——与装饰器侧保持
    // 一致的 own-property 语义。子类必须自带装饰器；继承父类的元数据不会被复用。
    const meta = getOwnMeta(buildParams.class.prototype)

    if (!meta) {
      throw new Error(`实体类 ${className} 缺少装饰器：请添加 @Table / @Id / @Field`)
    }
    if (!meta.tableName || meta.tableName.trim().length === 0) {
      throw new Error(`实体类 ${className} 缺少 @Table(name) 声明`)
    }
    if (!meta.columns || meta.columns.length === 0) {
      throw new Error(`实体类 ${className} 至少需要一个 @Field 或 @Id`)
    }
    const columnNames = new Set<string>()
    const propertyNames = new Set<string>()
    let primaryKey: ColumnMeta | undefined = undefined
    for (let i = 0; i < meta.columns.length; i++) {
      const c = meta.columns[i]
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
      if (c.primaryKey) {
        if (primaryKey) {
          throw new Error(`实体类 ${className} 主键重复：${primaryKey.property} / ${c.property}`)
        }
        primaryKey = c
      }
    }

    return new RdbOrm<T>({
      buildParams,
      tableName: meta.tableName,
      // 浅拷贝：ColumnMeta 对象引用与 MetaData 共享，调用方不应修改返回值中的 ColumnMeta
      columns: meta.columns.slice(),
      primaryKey,
    })
  }

  /**
   * 获取一个 DBHelper。底层 `RdbStore` 的生命周期由 HarmonyOS 内部管理。
   */
  async getDBHelper(): Promise<DBHelper<T>> {
    return DBHelper.create<T>(this.params)
  }
}
