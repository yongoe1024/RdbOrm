import { FieldParams } from "../model/FieldParams"
import { MetaData } from "../model/MetaData"

/**
 * 字段装饰器
 */
export function Field(data?: FieldParams) {
  return function (target: ESObject, propertyKey: string) {
    //target是原型
    if (!target.__meta__) {
      target.__meta__ = new MetaData()
    }
    // sql字段
    target.__meta__.fields.push(data?.name || propertyKey)
    // ts字段
    target.__meta__.propertyKeys.push(propertyKey)
    if (data?.id) {
      target.__meta__.tableId = data?.name || propertyKey
      target.__meta__.propertyId = propertyKey
    }
  }
}