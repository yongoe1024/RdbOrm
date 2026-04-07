import { MetaData } from "../model/MetaData";

/**
 * 类装饰器
 */
export function Table(name: string) {
  return function (target: ESObject) {
    //获取构造函数中的类原型
    target = target.prototype
    if (!target.__meta__) {
      target.__meta__ = new MetaData()
    }
    target.__meta__.tableName = name;
  };
}