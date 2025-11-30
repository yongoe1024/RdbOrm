import relationalStore from '@ohos.data.relationalStore'
import { TableParams } from '../model/TableParams'
import { RdbOrm } from './RdbOrm'
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * 数据库工具
 */
const DOMAIN: number = 0x0000;
const TAG: string = 'rdborm';

export class DBHelper<T> {
  private store: relationalStore.RdbStore
  private params: TableParams<T>

  /**
   * 获取版本
   * @returns 版本
   */
  getVersion(): number {
    return this.store.version
  }

  /**
   * 更新版本
   * @param v 版本
   */
  updateVersion(v: number) {
    this.store.version = v
  }

  /**
   * 获取RdbStore对象
   * @returns RdbStore对象
   */
  getStore(): relationalStore.RdbStore {
    return this.store
  }

  constructor(store: relationalStore.RdbStore, params: TableParams<T>) {
    this.store = store
    this.params = params
  }


  /**
   * 创建新的dbHelper对象
   * @throws BusinessError
   * @param params 构建参数
   * @returns DBHelper
   */
  static async create<T>(params: TableParams<T>): Promise<DBHelper<T>> {
    let store = await relationalStore.getRdbStore(params.buildParams.context, params.buildParams.config)
    return new DBHelper<T>(store, params)
  }

  /**
   * 执行包含指定参数的SQL语句
   * @throws BusinessError
   * @param sql SQL语句
   * @param args SQL语句中占位符的值
   * @returns SQL执行后的结果
   */
  executeSql(sql: string, args?: Array<relationalStore.ValueType>): relationalStore.ValueType {
    if (RdbOrm.debugSql) {
      hilog.debug(DOMAIN, TAG, `SQL:${sql}，args:${args || []}`);
    }
    return this.getStore().executeSync(sql, args)
  }

  /**
   * 根据指定SQL语句查询数据库中的数据
   * @throws BusinessError
   * @param sql SQL语句
   * @param args SQL语句中占位符的值
   * @returns Record<string, ValueType>
   */
  querySql(sql: string, args?: Array<relationalStore.ValueType>): relationalStore.ValuesBucket[] {
    if (RdbOrm.debugSql) {
      hilog.debug(DOMAIN, TAG, `SQL:${sql}，args:${args || []}`);
    }
    const res = this.getStore().querySqlSync(sql, args)
    const list: relationalStore.ValuesBucket[] = []
    while (res.goToNextRow()) {
      list.push(res.getRow())
    }
    return list
  }

  /**
   * 根据谓词进行查询
   * @throws BusinessError
   * @param fn 谓词的回调
   * @param columns 要查询的列
   * @returns 实体类
   */
  select(fn?: (item: relationalStore.RdbPredicates) => void, columns?: string[]): T[] {
    const predicates = new relationalStore.RdbPredicates(this.params.tableName)
    fn?.(predicates)
    if (RdbOrm.debugSql) {
      const sqlInfo = relationalStore.getQuerySqlInfo(predicates)
      hilog.debug(DOMAIN, TAG, `SQL:${sqlInfo.sql}，args:${sqlInfo.args || []}`);
    }
    const res = this.getStore().querySync(predicates, columns)
    let list: T[] = this.getData(res)
    return list
  }

  /**
   * 向目标表中插入一行数据
   * @throws BusinessError
   * @param obj 实体类
   * @param conflict 指定冲突解决模式
   * @returns 如果操作成功，返回行ID；否则返回-1
   */
  insert(obj: T, conflict?: relationalStore.ConflictResolution): number {
    const valueBucket = this.getRecode(obj)
    if (RdbOrm.debugSql) {
      const sqlInfo = relationalStore.getInsertSqlInfo(this.params.tableName, valueBucket, conflict)
      hilog.debug(DOMAIN, TAG, `SQL:${sqlInfo.sql}，args:${sqlInfo.args || []}`);
    }
    let res: number = -1
    if (conflict) {
      res = this.getStore().insertSync(this.params.tableName, valueBucket, conflict)
    } else {
      res = this.getStore().insertSync(this.params.tableName, valueBucket)
    }
    return res
  }

  /**
   * 向目标表中插入一组数据
   * @throws BusinessError
   * @param obj 实体类数组
   * @param conflict 指定冲突解决模式
   * @returns 如果操作成功，返回插入的数据个数，否则返回-1
   */
  batchInsert(list: T[], conflict?: relationalStore.ConflictResolution): number {
    const bucketList: relationalStore.ValuesBucket[] = []
    list.forEach(item => {
      bucketList.push(this.getRecode(item))
    })
    let res: number = -1
    if (conflict) {
      res = this.getStore().batchInsertWithConflictResolutionSync(this.params.tableName, bucketList, conflict)
    } else {
      res = this.getStore().batchInsertSync(this.params.tableName, bucketList)
    }
    return res
  }

  /**
   * 根据谓词条件，更新数据库中的数据
   * @throws BusinessError
   * @param obj 实体类对象
   * @param fn 谓词的回调
   * @param conflict 指定冲突解决模式
   * @returns 返回受影响的行数
   */
  update(obj: T, fn?: (item: relationalStore.RdbPredicates) => void,
    conflict?: relationalStore.ConflictResolution): number {
    const valueBucket = this.getRecode(obj)
    const predicates = new relationalStore.RdbPredicates(this.params.tableName)
    fn?.(predicates)
    if (RdbOrm.debugSql) {
      const sqlInfo = relationalStore.getUpdateSqlInfo(predicates, valueBucket, conflict)
      hilog.debug(DOMAIN, TAG, `SQL:${sqlInfo.sql}，args:${sqlInfo.args || []}`);
    }
    let res: number = -1
    if (conflict) {
      res = this.getStore().updateSync(valueBucket, predicates, conflict)
    } else {
      res = this.getStore().updateSync(valueBucket, predicates)
    }
    return res
  }

  /**
   * 根据谓词条件，从数据库中删除数据
   * @throws BusinessError
   * @param fn 谓词的回调
   * @returns 返回受影响的行数
   */
  delete(fn?: (item: relationalStore.RdbPredicates) => void): number {
    const predicates = new relationalStore.RdbPredicates(this.params.tableName)
    fn?.(predicates)
    if (RdbOrm.debugSql) {
      const sqlInfo = relationalStore.getDeleteSqlInfo(predicates)
      hilog.debug(DOMAIN, TAG, `SQL:${sqlInfo.sql}，args:${sqlInfo.args || []}`);
    }
    const res = this.getStore().deleteSync(predicates)
    return res
  }


  /**
   * 开启事务
   * @throws BusinessError
   */
  beginTransaction(): void {
    this.store.beginTransaction()
  }

  /**
   * 提交事务
   * @throws BusinessError
   */
  commit(): void {
    this.store.commit()
  }

  /**
   * 回滚事务
   * @throws BusinessError
   */
  rollBack(): void {
    this.store.rollBack()
  }

  /**
   * 以指定名称备份数据库
   * @throws BusinessError
   */
  backup(fileName: string): Promise<void> {
    return this.store.backup(fileName)
  }

  /**
   * 从指定的数据库备份文件恢复数据库
   * @throws BusinessError
   */
  restore(fileName: string): Promise<void> {
    return this.store.restore(fileName)
  }

  /**
   * 根据实体类装饰器，过滤字段
   */
  private getRecode(obj: T): relationalStore.ValuesBucket {
    let data: ESObject = obj
    const recordData: relationalStore.ValuesBucket = {};
    // 遍历实例的自有可枚举属性（排除原型链属性）
    Object.keys(data).map((key: string) => {
      // 判断是否存在字段
      let fieldName = this.params.propertyKeys[key]
      if (fieldName) {
        // undefined转null
        recordData[fieldName] = data[key] ?? null
      }
    })
    return recordData;
  }

  /**
   * 结果集获取数据
   * @throws BusinessError
   */
  private getData(res: relationalStore.ResultSet): T[] {
    const list: T[] = []
    while (res.goToNextRow()) {
      let entity: ESObject = new this.params.buildParams.class()
      let row: ESObject = res.getRow()
      // 对应的转换进去，不对应的直接传
      Object.keys(row).forEach(key => {
        let propertyKey = this.params.fields[key]
        if (propertyKey) {
          entity[propertyKey] = row[key]
        } else {
          entity[key] = row[key]
        }
      })
      list.push(entity)
    }
    return list
  }
}

