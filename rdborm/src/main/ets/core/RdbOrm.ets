import { BuildParams } from "../model/BuildParams";
import { DBHelper } from "./DBHelper";
import { BusinessError } from "@kit.BasicServicesKit";
import { TableParams } from "../model/TableParams";
import { hilog } from "@kit.PerformanceAnalysisKit";

const DOMAIN: number = 0x0000;
const TAG: string = 'rdborm';

export class RdbOrm<T> {
  private params: TableParams<T>
  public static debugSql: boolean = false

  constructor(params: TableParams<T>) {
    this.params = params;
  }

  /**
   * 创建一张表的操作对象
   * @param buildParams orm构建参数
   * @returns RdbOrm
   * @throws BusinessError
   */
  static build<T>(buildParams: BuildParams<T>): RdbOrm<T> {
    const prototype: ESObject = buildParams.class.prototype
    const tableName: string = prototype['__meta__']?.tableName
    const fields: Record<string, string> = prototype['__meta__']?.fields
    const propertyKeys: Record<string, string> = prototype['__meta__']?.propertyKeys
    if (tableName && fields && propertyKeys) {
      return new RdbOrm({
        buildParams: buildParams,
        tableName: tableName,
        fields: fields,
        propertyKeys: propertyKeys
      })
    } else {
      hilog.error(DOMAIN, TAG, '实体类缺少装饰器或参数异常');
      throw new Error('实体类缺少装饰器')
    }
  }

  /**
   * 获取新连接操作数据库
   * @param fn 接收DBHelper对象的回调
   */
  start(fn: (db: DBHelper<T>) => void): void {
    DBHelper.create<T>(this.params)
      .then(value => {
        fn(value)
      })
      .catch((e: BusinessError) => {
        hilog.error(DOMAIN, TAG, e.code + e.message);
      })
  }
}