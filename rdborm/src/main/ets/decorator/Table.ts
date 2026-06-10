import { getOrInitOwnMeta } from '../model/MetaData'

/**
 * 类装饰器：声明实体对应的数据库表名
 */
export function Table(name: string) {
  if (!name || name.trim().length === 0) {
    throw new Error('@Table(name) 表名不能为空')
  }
  return function (target: ESObject) {
    const meta = getOrInitOwnMeta(target.prototype)
    if (meta.tableName && meta.tableName !== name) {
      throw new Error(`@Table 重复声明：${meta.tableName} -> ${name}`)
    }
    meta.tableName = name
  }
}
