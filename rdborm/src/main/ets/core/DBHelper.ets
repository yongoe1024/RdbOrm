import { relationalStore } from '@kit.ArkData'
import { DBParams } from '../model/DBParams'
import { ColumnMeta } from '../model/MetaData'
import { Wrapper } from './Wrapper'
import { buildPredicates } from './WrapperResolver'
import { buildCreateTableSql, buildDropTableSql } from './TableSqlBuilder'
import { LogUtils } from './LogUtils'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN: number = 0x0000
const TAG: string = 'rdborm'

/**
 * 数据库操作封装
 */
export class DBHelper<T> {
  private logUtils: LogUtils
  private store: relationalStore.RdbStore
  private params: DBParams<T>
  private propertyToColumn: Map<string, ColumnMeta> = new Map()
  private columnToProperty: Map<string, ColumnMeta> = new Map()

  private constructor(store: relationalStore.RdbStore, params: DBParams<T>) {
    this.store = store
    this.params = params
    this.logUtils = new LogUtils(params.buildParams.debugSql === true)
    for (let i = 0; i < params.columns.length; i++) {
      const c = params.columns[i]
      this.propertyToColumn.set(c.property, c)
      this.columnToProperty.set(c.column, c)
    }
  }

  /**
   * @internal 仅供 RdbOrm 调用
   * @throws BusinessError
   */
  static async create<T>(params: DBParams<T>): Promise<DBHelper<T>> {
    const store = await relationalStore.getRdbStore(
      params.buildParams.context,
      params.buildParams.config,
    )
    return new DBHelper<T>(store, params)
  }

  // ---------- 元信息 ----------

  getVersion(): number {
    return this.store.version
  }

  setVersion(v: number): void {
    this.store.version = v
  }

  getStore(): relationalStore.RdbStore {
    return this.store
  }

  // ---------- DDL ----------

  /**
   * 根据装饰器元数据生成建表语句
   * @throws BusinessError
   */
  createTable(): relationalStore.ValueType {
    const sql = buildCreateTableSql(this.params.tableName, this.params.columns)
    this.logUtils.logSql(sql)
    return this.store.executeSync(sql)
  }

  /**
   * 删除表，等价于 `DROP TABLE IF EXISTS <table>`
   * @throws BusinessError
   */
  dropTable(): void {
    const sql = buildDropTableSql(this.params.tableName)
    this.logUtils.logSql(sql)
    this.store.executeSync(sql)
  }

  // ---------- 原生 SQL ----------

  /**
   * 执行原生 SQL，`args` 通过 SQLite 预编译参数传入
   * @throws BusinessError
   */
  executeSql(sql: string, args?: Array<relationalStore.ValueType>): relationalStore.ValueType {
    this.logUtils.logSql(sql, args)
    return this.store.executeSync(sql, args)
  }

  /**
   * 执行原生查询 SQL，返回原始 ValuesBucket 数组
   * @throws BusinessError
   */
  querySql(sql: string, args?: Array<relationalStore.ValueType>): relationalStore.ValuesBucket[] {
    this.logUtils.logSql(sql, args)
    const rs = this.store.querySqlSync(sql, args)
    return this.consumeResultSet(rs, () => {
      const list: relationalStore.ValuesBucket[] = []
      while (rs.goToNextRow()) {
        list.push(rs.getRow())
      }
      return list
    })
  }

  // ---------- 查询 ----------

  /**
   * 按条件查询实体列表。无条件时返回全表
   * @throws BusinessError
   */
  select(wrapper?: Wrapper, columns?: string[]): T[] {
    const predicates = buildPredicates(this.params.tableName, wrapper)
    this.logUtils.logQuery(predicates, columns)
    const rs = this.store.querySync(predicates, columns)
    return this.consumeResultSet(rs, () => this.rowsToEntities(rs))
  }

  /**
   * 查询单条；无结果返回 `undefined`
   * @throws BusinessError
   */
  selectOne(wrapper?: Wrapper, columns?: string[]): T | undefined {
    //    * 内部会克隆传入的 `wrapper` 后再追加 `LIMIT 1`，**不会修改调用方的 wrapper 对象**
    const w = wrapper ? wrapper.clone() : new Wrapper()
    const list = this.select(w.limit(1), columns)
    return list.length > 0 ? list[0] : undefined
  }

  /**
   * 计数。只统计 WHERE 匹配行数，调用方不应传 limit/offset/groupBy（见 README)
   * @throws BusinessError
   */
  count(wrapper?: Wrapper): number {
    const predicates = buildPredicates(this.params.tableName, wrapper)
    const cols: string[] = ['count(*) as __count__']
    this.logUtils.logQuery(predicates, cols)
    const rs = this.store.querySync(predicates, cols)
    // count(*) 只返回一行
    return this.consumeResultSet(rs, () =>
    rs.goToNextRow() ? Number(rs.getRow()['__count__'] ?? 0) : 0)
  }

  // ---------- 写入 ----------

  /**
   * 插入单条。返回 `rowId`，失败为 -1
   * @throws BusinessError
   */
  insert(obj: T, conflict?: relationalStore.ConflictResolution): number {
    const bucket = this.toValuesBucket(obj)
    this.logUtils.logInsert(this.params.tableName, bucket, conflict)
    return this.store.insertSync(this.params.tableName, bucket, conflict)
  }

  /**
   * 批量插入。返回成功插入数量，失败为 -1
   * 注：无log
   * @throws BusinessError
   */
  batchInsert(list: T[], conflict?: relationalStore.ConflictResolution): number {
    const buckets: relationalStore.ValuesBucket[] = []
    for (let i = 0; i < list.length; i++) {
      buckets.push(this.toValuesBucket(list[i]))
    }
    if (conflict !== undefined) {
      return this.store.batchInsertWithConflictResolutionSync(this.params.tableName, buckets, conflict)
    }
    return this.store.batchInsertSync(this.params.tableName, buckets)
  }

  /**
   * 按条件更新指定字段。
   * @param values 待更新字段对象（传 `undefined` 的字段忽略，传 `null` 写入 NULL）
   *               推荐：实体类的字段建议都声明为可选 `?`，这样可以只填要更新的字段
   *               注意：主键也会进入 SET 子句
   * @param wrapper 必传，至少一条 WHERE 条件
   * @throws BusinessError
   */
  update(values: T, wrapper: Wrapper, conflict?: relationalStore.ConflictResolution): number {
    if (!wrapper.hasWhereActions()) {
      throw new Error('update(values, wrapper) 必须至少传入一个 WHERE 条件，避免误更新全表')
    }
    const bucket = this.toValuesBucket(values)
    if (Object.keys(bucket).length === 0) {
      throw new Error('update(values, wrapper) 的 values 必须包含至少一个被装饰过的字段')
    }
    const predicates = buildPredicates(this.params.tableName, wrapper)
    this.logUtils.logUpdate(predicates, bucket, conflict)
    return this.store.updateSync(bucket, predicates, conflict)
  }

  /**
   * 按主键更新整条实体。实体必须包含主键属性值。
   *
   * 主键**不会**进入 SET 子句
   * @throws BusinessError
   */
  updateById(obj: T, conflict?: relationalStore.ConflictResolution): number {
    const pk = this.getPrimaryKeyOrThrow()
    const idValue: ESObject = (obj as ESObject)[pk.property]
    if (idValue === undefined || idValue === null) {
      throw new Error(`updateById 缺少主键值：${pk.property}`)
    }
    const bucket = this.toValuesBucket(obj, pk.column)
    if (Object.keys(bucket).length === 0) {
      return 0
    }
    const predicates = new relationalStore.RdbPredicates(this.params.tableName)
    predicates.equalTo(pk.column, idValue as relationalStore.ValueType)
    this.logUtils.logUpdate(predicates, bucket, conflict)
    return this.store.updateSync(bucket, predicates, conflict)
  }

  /**
   * 按条件删除。`wrapper` 必须至少包含一个 WHERE 条件
   * @throws BusinessError
   */
  delete(wrapper: Wrapper): number {
    if (!wrapper.hasWhereActions()) {
      throw new Error('delete(wrapper) 必须至少传入一个 WHERE 条件；要清空整张表请使用 clear()')
    }
    const predicates = buildPredicates(this.params.tableName, wrapper)
    this.logUtils.logDelete(predicates)
    return this.store.deleteSync(predicates)
  }

  /**
   * 按主键删除
   * @throws BusinessError
   */
  deleteById(id: relationalStore.ValueType): number {
    const pk = this.getPrimaryKeyOrThrow()
    const predicates = new relationalStore.RdbPredicates(this.params.tableName)
    predicates.equalTo(pk.column, id)
    return this.store.deleteSync(predicates)
  }

  /**
   * 清空整张表
   * 等价于不带条件的 DELETE。
   * @throws BusinessError
   */
  clear(): number {
    return this.store.deleteSync(new relationalStore.RdbPredicates(this.params.tableName))
  }

  // ---------- 事务 ----------

  /**
   * 事务包装：`fn` 抛错时自动回滚，正常返回时提交。
   *
   * ⚠️ `fn` 必须是同步函数。**禁止**传 async lambda 或返回 Promise。
   * @throws BusinessError
   */
  transaction<R>(fn: () => R): R {
    this.store.beginTransaction()
    let shouldRollback = true
    try {
      const result = fn()
      if (this.isPromiseLike(result as ESObject)) {
        throw new Error('transaction(fn) 不支持 async 函数或 Promise 返回值；请在事务体内只调用同步 CRUD')
      }
      this.store.commit()
      shouldRollback = false
      return result
    } catch (e) {
      if (shouldRollback) {
        this.rollbackQuietly()
      }
      throw e as Error
    }
  }

  /**
   * 关闭连接
   * @throws BusinessError
   */
  close(): void {
    this.store.close()
  }

  // ---------- 内部工具 ----------

  /**
   * 把实体转成 ValueBucket
   * - `undefined`：跳过（让 SQL 默认值生效）
   * - `null`：直通（写入 SQL NULL）
   * - 其它：原值透传，HarmonyOS 底层负责把 JS boolean 转 1/0、Date 转字符串等
   *
   * @param excludeColumn 可选，需要从结果中排除的列名（可用来去掉主键）
   */
  private toValuesBucket(obj: T, excludeColumn?: string): relationalStore.ValuesBucket {
    const bucket: relationalStore.ValuesBucket = {}
    this.propertyToColumn.forEach((meta, property) => {
      if (excludeColumn !== undefined && meta.column === excludeColumn) {
        return
      }
      const v: ESObject = (obj as ESObject)[property]
      if (v === undefined) {
        return
      }
      if (v === null) {
        bucket[meta.column] = null
        return
      }
      bucket[meta.column] = v as relationalStore.ValueType
    })
    return bucket
  }

  /**
   * ResultSet 行 → 实体对象。
   * - 仅写回在 `propertyToColumn` 中声明过的列，未声明列被**丢弃**。
   * - 配了 `@Field({ enableBoolMapper: true })` 的列，把 `1`/`0` 转回 `true`/`false`；
   *   `null` / `undefined` 直通不转换。
   * - 其它列原值透传（HarmonyOS 内部按列类型返回 number / string / Uint8Array 等）。
   */
  private rowsToEntities(rs: relationalStore.ResultSet): T[] {
    const list: T[] = []
    while (rs.goToNextRow()) {
      const entity = new this.params.buildParams.class()
      const row: relationalStore.ValuesBucket = rs.getRow()
      const keys = Object.keys(row)
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i]
        const meta = this.columnToProperty.get(key)
        if (meta) {
          const raw = row[key]
          if (raw !== null && raw !== undefined && meta.enableBoolMapper) {
            // 1/0 → true/false
            (entity as ESObject)[meta.property] = raw === 1 || raw === true
          } else {
            (entity as ESObject)[meta.property] = raw
          }
        }
      }
      list.push(entity)
    }
    return list
  }

  private consumeResultSet<R>(rs: relationalStore.ResultSet, fn: () => R): R {
    try {
      return fn()
    } finally {
      rs.close()
    }
  }

  private getPrimaryKeyOrThrow(): ColumnMeta {
    const pk = this.params.primaryKey
    if (!pk) {
      const className = (this.params.buildParams.class as ESObject).name as string
      throw new Error(`实体类 ${className} 未声明主键，updateById/deleteById 不可用，请使用 @Id`)
    }
    return pk
  }

  private isPromiseLike(value: ESObject): boolean {
    return value !== null && value !== undefined && typeof value.then === 'function'
  }

  private rollbackQuietly(): void {
    try {
      this.store.rollBack()
    } catch (rollbackErr) {
      const msg = rollbackErr instanceof Error ? rollbackErr.message : String(rollbackErr)
      hilog.error(DOMAIN, TAG, 'rollBack 失败：%{public}s', msg)
    }
  }
}
