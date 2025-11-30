/**
 * 字段装饰器
 */
export function Field(name?: string) {
  return function (target: ESObject, propertyKey: string) {
    //target是原型
    if (!target.__meta__) {
      target.__meta__ = {}
    }
    if (!target.__meta__.fields) {
      // sql对应ts
      target.__meta__.fields = {}
      // ts对应sql
      target.__meta__.propertyKeys = {}
    }
    // sql字段：ts字段
    target.__meta__.fields[name?? propertyKey] = propertyKey
    // ts字段：sql字段
    target.__meta__.propertyKeys[propertyKey] = name ?? propertyKey
  }
}