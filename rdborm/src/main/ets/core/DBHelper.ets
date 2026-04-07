import relationalStore from '@ohos.data.relationalStore'
import { TableParams } from '../model/TableParams'
import { RdbOrm } from './RdbOrm'
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Wrapper } from './Wrapper';

/**
 * 数据库工具
 */
const DOMAIN: number = 0x0000;
const TAG: string = 'rdborm';

export class DBHelper<T> {
  private store: relationalStore.RdbStore
  private params: TableParams<T>
  private propertyToFieldMap: Record<string, string> = {}
  private fieldToPropertyMap: Record<string, string> = {}

  private constructor(store: relationalStore.RdbStore, params: TableParams<T>) {
    this.store = store
    this.params = params
    this.initFieldMappings()
  }

  /**
   * 获取版本
   */
  getVersion(): number {
    return this.store.version
  }

  /**
   * 更新版本
   */
  updateVersion(v: number) {
    this.store.version = v
  }

  /**
   * 获取RdbStore对象
   */
  getStore(): relationalStore.RdbStore {
    return this.store
  }

  /**
   * 创建新的dbHelper对象
   * @throws BusinessError
   * @param params 构建参数
   * @param context 不传入则使用默认context
   * @returns DBHelper
   */
  static async create<T>(params: TableParams<T>, context?: Context): Promise<DBHelper<T>> {
    let store = await relationalStore.getRdbStore(context ?? params.buildParams.context, params.buildParams.config)
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
    try {
      while (res.goToNextRow()) {
        list.push(res.getRow())
      }
    } finally {
      res.close()
    }
    return list
  }

  /**
   * 根据谓词进行查询
   * @throws BusinessError
   * @param wrapper 条件构造器
   * @param columns 要查询的列
   * @returns 实体类
   */
  select(wrapper?: Wrapper, columns?: string[]): T[] {
    const predicates = new relationalStore.RdbPredicates(this.params.tableName)
    this.applyWrapper(predicates, wrapper)
    if (RdbOrm.debugSql) {
      const sqlInfo = relationalStore.getQuerySqlInfo(predicates, columns)
      hilog.debug(DOMAIN, TAG, `SQL:${sqlInfo.sql}，args:${sqlInfo.args || []}`);
    }
    const res = this.getStore().querySync(predicates, columns)
    try {
      return this.getData(res)
    } finally {
      res.close()
    }
  }

  /**
   * 查询符合条件的记录数
   * @throws BusinessError
   * @param wrapper 条件构造器
   * @returns 记录数
   */
  count(wrapper?: Wrapper): number {
    const predicates = new relationalStore.RdbPredicates(this.params.tableName)
    this.applyWrapper(predicates, wrapper)
    if (RdbOrm.debugSql) {
      const sqlInfo = relationalStore.getQuerySqlInfo(predicates, ['count(*) as total'])
      hilog.debug(DOMAIN, TAG, `SQL:${sqlInfo.sql}，args:${sqlInfo.args || []}`);
    }
    const res = this.getStore().querySync(predicates, ['count(*) as total'])
    try {
      let total = 0
      while (res.goToNextRow()) {
        const row = res.getRow()
        total = Number(row['total'] ?? 0)
      }
      return total
    } finally {
      res.close()
    }
  }

  /**
   * 向目标表中插入一行数据
   * @throws BusinessError
   * @param obj 实体对象
   * @param conflict 指定冲突解决模式
   * @returns 如果操作成功，返回行ID；否则返回-1
   */
  insert(obj: T, conflict?: relationalStore.ConflictResolution): number {
    const valueBucket = this.getRecord(obj)
    if (RdbOrm.debugSql) {
      const sqlInfo = relationalStore.getInsertSqlInfo(this.params.tableName, valueBucket, conflict)
      hilog.debug(DOMAIN, TAG, `SQL:${sqlInfo.sql}，args:${sqlInfo.args || []}`);
    }
    return this.getStore().insertSync(this.params.tableName, valueBucket, conflict)
  }

  /**
   * 向目标表中插入一组数据
   * @throws BusinessError
   * @param list 实体对象数组
   * @param conflict 指定冲突解决模式
   * @returns 如果操作成功，返回插入的数据个数，否则返回-1
   */
  batchInsert(list: T[], conflict?: relationalStore.ConflictResolution): number {
    const bucketList: relationalStore.ValuesBucket[] = []
    list.forEach(item => {
      bucketList.push(this.getRecord(item))
    })
    if (conflict !== undefined) {
      return this.getStore().batchInsertWithConflictResolutionSync(this.params.tableName, bucketList, conflict)
    } else {
      return this.getStore().batchInsertSync(this.params.tableName, bucketList)
    }
  }

  /**
   * 根据谓词条件，更新数据库中的数据
   * @throws BusinessError
   * @param wrapper 条件构造器，set用于更新字段，其余条件用于where
   * @param conflict 指定冲突解决模式
   * @returns 返回受影响的行数
   */
  update(wrapper: Wrapper, conflict?: relationalStore.ConflictResolution): number {
    const predicates = new relationalStore.RdbPredicates(this.params.tableName)
    const valueBucket = this.getUpdateRecord(wrapper)
    this.applyWrapper(predicates, wrapper)
    if (RdbOrm.debugSql) {
      const sqlInfo = relationalStore.getUpdateSqlInfo(predicates, valueBucket, conflict)
      hilog.debug(DOMAIN, TAG, `SQL:${sqlInfo.sql}，args:${sqlInfo.args || []}`);
    }
    return this.getStore().updateSync(valueBucket, predicates, conflict)
  }

  /**
   * 根据谓词条件，从数据库中删除数据
   * @throws BusinessError
   * @param wrapper 条件构造器
   * @returns 返回受影响的行数
   */
  delete(wrapper?: Wrapper): number {
    const predicates = new relationalStore.RdbPredicates(this.params.tableName)
    this.applyWrapper(predicates, wrapper)
    if (RdbOrm.debugSql) {
      const sqlInfo = relationalStore.getDeleteSqlInfo(predicates)
      hilog.debug(DOMAIN, TAG, `SQL:${sqlInfo.sql}，args:${sqlInfo.args || []}`);
    }
    const res = this.getStore().deleteSync(predicates)
    return res
  }

  /**
   * 根据主键更新数据
   * @throws BusinessError
   * @param obj 实体对象，必须包含主键属性
   * @param conflict 指定冲突解决模式
   * @returns 返回受影响的行数
   */
  updateById(obj: T, conflict?: relationalStore.ConflictResolution): number {
    const data: ESObject = obj
    const bucket = this.getRecord(obj)
    const tableId = this.getTableIdOrThrow()
    const propertyId = this.getPropertyIdOrThrow()
    const predicates = new relationalStore.RdbPredicates(this.params.tableName)
    predicates.equalTo(tableId, data[propertyId])
    if (RdbOrm.debugSql) {
      const sqlInfo = relationalStore.getUpdateSqlInfo(predicates, bucket, conflict)
      hilog.debug(DOMAIN, TAG, `SQL:${sqlInfo.sql}，args:${sqlInfo.args || []}`);
    }
    return this.getStore().updateSync(bucket, predicates, conflict)
  }

  /**
   * 根据主键删除数据
   * @throws BusinessError
   * @param id 主键值
   * @returns 返回受影响的行数
   */
  deleteById(id: relationalStore.ValueType): number {
    return this.delete(new Wrapper().eq(this.getTableIdOrThrow(), id))
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
   * 关闭数据库连接
   * @throws BusinessError
   */
  close(): void {
    this.store.close()
  }

  /**
   * 根据实体类装饰器过滤字段
   */
  private getRecord(obj: T): relationalStore.ValuesBucket {
    const data: ESObject = obj
    const recordData: relationalStore.ValuesBucket = {}
    Object.keys(data).forEach((key: string) => {
      const fieldName = this.propertyToFieldMap[key]
      if (fieldName !== undefined) {
        recordData[fieldName] = data[key] ?? null
      }
    })
    return recordData
  }

  /**
   * 结果集获取数据
   * @throws BusinessError
   */
  private getData(res: relationalStore.ResultSet): T[] {
    const list: T[] = []
    while (res.goToNextRow()) {
      const entity: ESObject = new this.params.buildParams.class()
      const row: ESObject = res.getRow()
      Object.keys(row).forEach((key: string) => {
        const propertyKey = this.fieldToPropertyMap[key]
        if (propertyKey !== undefined) {
          entity[propertyKey] = row[key]
        } else {
          entity[key] = row[key]
        }
      })
      list.push(entity)
    }
    return list
  }

  private initFieldMappings(): void {
    this.params.propertyKeys.forEach((propertyKey: string, index: number) => {
      const fieldName = this.params.fields[index]
      this.propertyToFieldMap[propertyKey] = fieldName
      this.fieldToPropertyMap[fieldName] = propertyKey
    })
  }


  private applyWrapper(predicates: relationalStore.RdbPredicates, wrapper?: Wrapper): void {
    if (!wrapper) {
      return
    }

    const actions = wrapper.getActions()
    actions.forEach(action => {
      const field = action.field
      const fields = action.fields
      switch (action.type) {
        case 'set':
          break
        case 'inDevices':
          predicates.inDevices(action.devices ?? [])
          break
        case 'inAllDevices':
          predicates.inAllDevices()
          break
        case 'eq':
          predicates.equalTo(field!, action.value!)
          break
        case 'notEq':
          predicates.notEqualTo(field!, action.value!)
          break
        case 'or':
          predicates.or()
          this.applyLogicWrapper(predicates, action.wrapper)
          break
        case 'and':
          predicates.and()
          this.applyLogicWrapper(predicates, action.wrapper)
          break
        case 'contains':
          predicates.contains(field!, action.value as string)
          break
        case 'beginsWith':
          predicates.beginsWith(field!, action.value as string)
          break
        case 'endsWith':
          predicates.endsWith(field!, action.value as string)
          break
        case 'isNull':
          predicates.isNull(field!)
          break
        case 'isNotNull':
          predicates.isNotNull(field!)
          break
        case 'like':
          predicates.like(field!, action.value as string)
          break
        case 'glob':
          predicates.glob(field!, action.value as string)
          break
        case 'between':
          predicates.between(field!, action.start!, action.end!)
          break
        case 'notBetween':
          predicates.notBetween(field!, action.start!, action.end!)
          break
        case 'lt':
          predicates.lessThan(field!, action.value!)
          break
        case 'lte':
          predicates.lessThanOrEqualTo(field!, action.value!)
          break
        case 'gt':
          predicates.greaterThan(field!, action.value!)
          break
        case 'gte':
          predicates.greaterThanOrEqualTo(field!, action.value!)
          break
        case 'orderByAsc':
          predicates.orderByAsc(field!)
          break
        case 'orderByDesc':
          predicates.orderByDesc(field!)
          break
        case 'distinct':
          predicates.distinct()
          break
        case 'limit':
          predicates.limitAs(action.numberValue!)
          break
        case 'offset':
          predicates.offsetAs(action.numberValue!)
          break
        case 'groupBy':
          predicates.groupBy(fields ?? [])
          break
        case 'indexedBy':
          predicates.indexedBy(field!)
          break
        case 'in':
          predicates.in(field!, action.values ?? [])
          break
        case 'notIn':
          predicates.notIn(field!, action.values ?? [])
          break
        case 'notLike':
          predicates.notLike(field!, action.value as string)
          break
        case 'having':
          predicates.having(action.sql!, action.args)
          break
        case 'notContains':
          predicates.notContains(field!, action.value as string)
          break
      }
    })
  }

  private applyLogicWrapper(predicates: relationalStore.RdbPredicates, wrapper?: Wrapper): void {
    if (!wrapper) {
      return
    }
    predicates.beginWrap()
    this.applyWrapper(predicates, wrapper)
    predicates.endWrap()
  }

  private getUpdateRecord(wrapper: Wrapper): relationalStore.ValuesBucket {
    const recordData: relationalStore.ValuesBucket = {}
    wrapper.getActions().forEach(action => {
      if (action.type === 'set' && action.field) {
        recordData[action.field] = action.value ?? null
      }
    })
    if (Object.keys(recordData).length === 0) {
      throw new Error('update requires at least one set(...) action')
    }
    return recordData
  }

  private getTableIdOrThrow(): string {
    if (!this.params.tableId) {
      throw new Error('Primary key field is required for updateById/deleteById')
    }
    return this.params.tableId
  }

  private getPropertyIdOrThrow(): string {
    if (!this.params.propertyId) {
      throw new Error('Primary key field is required for updateById/deleteById')
    }
    return this.params.propertyId
  }
}
