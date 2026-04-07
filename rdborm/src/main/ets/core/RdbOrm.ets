import { BuildParams } from "../model/BuildParams";
import { DBHelper } from "./DBHelper";
import { TableParams } from "../model/TableParams";
import { hilog } from "@kit.PerformanceAnalysisKit";
import { MetaData } from "../model/MetaData";

const DOMAIN: number = 0x0000;
const TAG: string = 'rdborm';

export class RdbOrm<T> {
  private params: TableParams<T>
  public static debugSql: boolean = false

  private constructor(params: TableParams<T>) {
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
    let meta: MetaData = prototype['__meta__']
    if (meta?.tableName && meta?.fields.length > 0 && meta?.propertyKeys.length > 0) {
      return new RdbOrm({
        buildParams: buildParams,
        tableName: meta.tableName,
        fields: meta.fields,
        propertyKeys: meta.propertyKeys,
        tableId: meta.tableId,
        propertyId: meta.propertyId
      })
    } else {
      hilog.error(DOMAIN, TAG, '实体类缺少装饰器或参数异常');
      throw new Error('实体类缺少装饰器')
    }
  }

  /**
   * 获取新连接操作数据库
   * @param context 可选，在taskpool单独传入
   * @throws BusinessError
   */
  async getDBHelper(context?: Context): Promise<DBHelper<T>> {
    return DBHelper.create<T>(this.params, context)
  }
}