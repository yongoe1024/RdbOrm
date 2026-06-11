import { BuildParams } from '../model/BuildParams'
import { DBHelper } from './DBHelper'
import { DBParams } from '../model/DBParams'
import { getOwnMeta } from '../model/MetaData'

/**
 * 一张表对应的 ORM 入口。通过 `RdbOrm.build` 创建，再用 `getDBHelper` 获取 `DBHelper`
 */
export class RdbOrm<T> {
  private params: DBParams<T>

  private constructor(params: DBParams<T>) {
    this.params = params
  }

  /**
   * 解析实体类装饰器并创建 ORM 操作对象
   */
  static build<T>(buildParams: BuildParams<T>): RdbOrm<T> {
    const className = (buildParams.class as ESObject).name as string
    // 只读 target 自身的 __meta__，**不沿原型链向上查找**——与装饰器侧保持
    // 一致的 own-property 语义。子类必须自带装饰器；继承父类的元数据不会被复用。
    const meta = getOwnMeta(buildParams.class.prototype)

    if (!meta) {
      throw new Error(`实体类 ${className} 缺少装饰器：请添加 @Table / @Id / @Field`)
    }
    const primaryKey = meta.validate(className)

    return new RdbOrm<T>({
      buildParams,
      tableName: meta.tableName,
      // 浅拷贝：ColumnMeta 对象引用与 MetaData 共享，调用方不应修改返回值中的 ColumnMeta
      columns: meta.columns.slice(),
      primaryKey,
    })
  }

  /**
   * 获取一个 DBHelper。底层 `RdbStore` 的生命周期由 HarmonyOS 内部管理
   * @throws BusinessError
   */
  async getDBHelper(): Promise<DBHelper<T>> {
    return DBHelper.create<T>(this.params)
  }
}
