import { relationalStore } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { TableParams } from '../model/TableParams'
import { ColumnMeta } from '../model/ColumnMeta'
import { Wrapper } from './Wrapper'
import { buildPredicates } from './WrapperResolver'

const DOMAIN: number = 0x0000
const TAG: string = 'rdborm'

// ---------- SQL 语句构建工具（模块级纯函数） ----------

/** 构建单列 DDL 定义 */
function buildColumnDefSql(c: ColumnMeta): string {
  const parts: string[] = [quoteIdentifier(c.column), c.type ?? 'TEXT']
  if (c.primaryKey) {
    parts.push('PRIMARY KEY')
    // AUTOINCREMENT 仅对 INTEGER PK 合法（SQLite 规范）
    if (c.autoIncrement !== false && c.type === 'INTEGER') {
      parts.push('AUTOINCREMENT')
    }
  }
  // INTEGER 主键作为 ROWID 别名允许 NULL 自增；其它类型主键必须 NOT NULL
  if (c.nullable === false && (!c.primaryKey || c.type !== 'INTEGER')) {
    parts.push('NOT NULL')
  }
  if (c.unique) {
    parts.push('UNIQUE')
  }
  if (c.defaultValue !== undefined) {
    parts.push(`DEFAULT ${formatDefaultValue(c.defaultValue)}`)
  }
  return parts.join(' ')
}

/** 格式化 DEFAULT 值 */
function formatDefaultValue(v: relationalStore.ValueType): string {
  if (v === null) {
    return 'NULL'
  }
  if (typeof v === 'number') {
    return String(v)
  }
  if (typeof v === 'boolean') {
    return v ? '1' : '0'
  }
  if (typeof v === 'string') {
    return `'${v.replace(/'/g, "''")}'`
  }
  throw new Error('createTable 暂不支持 BLOB / Uint8Array 默认值；请使用 executeSql 手写 CREATE TABLE')
}

/** SQL 标识符引号包裹 */
function quoteIdentifier(name: string): string {
  return `"${name.replace(/"/g, '""')}"`
}

/**
 * 数据库操作封装。建议通过 `RdbOrm.build(...).getDBHelper()` 获取实例。
 */
export class DBHelper<T> {
  private store: relationalStore.RdbStore
  private params: TableParams<T>
  private propertyToColumn: Map<string, ColumnMeta> = new Map()
  private columnToProperty: Map<string, ColumnMeta> = new Map()

  private constructor(store: relationalStore.RdbStore, params: TableParams<T>) {
    this.store = store
    this.params = params
    for (let i = 0; i < params.columns.length; i++) {
      const c = params.columns[i]
      this.propertyToColumn.set(c.property, c)
      this.columnToProperty.set(c.column, c)
    }
  }

  /** @internal 仅供 RdbOrm 调用
   * @throws BusinessError
   */
  static async create<T>(params: TableParams<T>): Promise<DBHelper<T>> {
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
   *
   * 列类型由 `@Field({ type })` / `@Id` 决定；未声明类型时默认 `TEXT`。
   * 主键默认为 `INTEGER PRIMARY KEY AUTOINCREMENT`，可通过 `@Id({ autoIncrement: false })` 关闭。
   * @throws BusinessError
   */
  createTable(): void {
    const sql = this.buildCreateTableSql()
    this.logSql(sql)
    this.store.executeSync(sql)
  }

  private buildCreateTableSql(): string {
    const cols: string[] = []
    for (let i = 0; i < this.params.columns.length; i++) {
      cols.push(buildColumnDefSql(this.params.columns[i]))
    }
    return `CREATE TABLE IF NOT EXISTS ${quoteIdentifier(this.params.tableName)} (\n  ${cols.join(',\n  ')}\n)`
  }

  /** 等价于 `DROP TABLE IF EXISTS <table>` */
  dropTable(): void {
    const sql = `DROP TABLE IF EXISTS ${quoteIdentifier(this.params.tableName)}`
    this.logSql(sql)
    this.store.executeSync(sql)
  }

  // ---------- 原生 SQL ----------

  /**
   * 执行原生 SQL。`args` 通过 SQLite 预编译参数传入；**`sql` 字符串本身由调用方负责**——
   * 任何拼接到 `sql` 里的外部输入都需要自行做白名单校验。
   */
  executeSql(sql: string, args?: Array<relationalStore.ValueType>): relationalStore.ValueType {
    this.logSql(sql, args)
    return this.store.executeSync(sql, args)
  }

  /**
   * 执行原生查询 SQL，返回原始 ValuesBucket 数组——**不做实体映射、不做 boolean 转换**。
   * 列值就是 SQLite 存的什么样返回什么样（INTEGER / TEXT / REAL / BLOB）。
   * 如果需要 boolean 字段自动转换，请改用 `select()`。
   */
  querySql(sql: string, args?: Array<relationalStore.ValueType>): relationalStore.ValuesBucket[] {
    this.logSql(sql, args)
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

  /** 按条件查询实体列表。无条件时返回全表。 */
  select(wrapper?: Wrapper, columns?: string[]): T[] {
    const predicates = buildPredicates(this.params.tableName, wrapper)
    this.logQuery(predicates, columns)
    const rs = this.store.querySync(predicates, columns)
    return this.consumeResultSet(rs, () => this.rowsToEntities(rs))
  }

  /**
   * 查询单条；无结果返回 `null`。
   *
   * 内部会克隆传入的 `wrapper` 后再追加 `LIMIT 1`，**不会修改调用方的 wrapper 对象**。
   */
  selectOne(wrapper?: Wrapper, columns?: string[]): T | null {
    const w = wrapper ? wrapper.clone() : new Wrapper()
    const list = this.select(w.limit(1), columns)
    return list.length > 0 ? list[0] : null
  }

  /** 计数。只统计 WHERE 匹配行数，调用方不应传 limit/offset/groupBy（见 README）。 */
  count(wrapper?: Wrapper): number {
    const predicates = buildPredicates(this.params.tableName, wrapper)
    const cols: string[] = ['count(*) as __rdborm_count__']
    this.logQuery(predicates, cols)
    const rs = this.store.querySync(predicates, cols)
    // count(*) 只返回一行
    return this.consumeResultSet(rs, () =>
      rs.goToNextRow() ? Number(rs.getRow()['__rdborm_count__'] ?? 0) : 0
    )
  }

  // ---------- 写入 ----------

  /** 插入单条。返回 `rowId`，失败为 -1。 */
  insert(obj: T, conflict?: relationalStore.ConflictResolution): number {
    const bucket = this.toValuesBucket(obj)
    if (this.debug()) {
      const info = relationalStore.getInsertSqlInfo(this.params.tableName, bucket, conflict)
      this.logSql(info.sql, info.args)
    }
    return this.store.insertSync(this.params.tableName, bucket, conflict)
  }

  /** 批量插入。返回成功插入数量，失败为 -1。 */
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
   * @param values 待更新字段对象（按属性名传入，会自动映射为列名；传 `undefined` 的字段忽略，传 `null` 写入 NULL）
   *               实体类的字段建议都声明为可选 `?`，这样可以只填要更新的字段。
   *               注意：若 `values` 上设置了主键属性，主键也会进入 SET 子句（与只更新非主键字段的 `updateById` 不同）；
   *               不想改主键就不要在 `values` 上赋主键值。
   * @param wrapper 必传，至少一条 WHERE 条件
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
    if (this.debug()) {
      const info = relationalStore.getUpdateSqlInfo(predicates, bucket, conflict)
      this.logSql(info.sql, info.args)
    }
    return this.store.updateSync(bucket, predicates, conflict)
  }

  /**
   * 按主键更新整条实体。实体必须包含主键属性值。
   *
   * 主键列**不会**进入 SET 子句——`updateById` 顾名思义只更新除主键外的字段，
   * 即便 entity 上同时设置了主键和其它字段，主键也只用于 WHERE 定位。
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
    if (this.debug()) {
      const info = relationalStore.getUpdateSqlInfo(predicates, bucket, conflict)
      this.logSql(info.sql, info.args)
    }
    return this.store.updateSync(bucket, predicates, conflict)
  }

  /**
   * 按条件删除。`wrapper` 必须至少包含一个 WHERE 条件；要清空整张表请使用 `clear()`。
   */
  delete(wrapper: Wrapper): number {
    if (!wrapper.hasWhereActions()) {
      throw new Error('delete(wrapper) 必须至少传入一个 WHERE 条件；要清空整张表请使用 clear()')
    }
    return this.executeDelete(buildPredicates(this.params.tableName, wrapper))
  }

  /** 按主键删除。 */
  deleteById(id: relationalStore.ValueType): number {
    const pk = this.getPrimaryKeyOrThrow()
    const predicates = new relationalStore.RdbPredicates(this.params.tableName)
    predicates.equalTo(pk.column, id)
    return this.executeDelete(predicates)
  }

  /** 清空整张表，等价于不带条件的 DELETE。 */
  clear(): number {
    return this.executeDelete(new relationalStore.RdbPredicates(this.params.tableName))
  }

  // ---------- 事务 ----------

  /**
   * 事务包装：`fn` 抛错时自动回滚，正常返回时提交。
   *
   * ⚠️ `fn` 必须是同步函数。**不要**传 async lambda 或返回 Promise。
   * rdborm 会在运行时拒绝 Promise 返回值并回滚事务；事务体内直接调用同步 CRUD 即可。
   *
   * ```ts
   * // ✅ 正确
   * db.transaction(() => {
   *   db.insert(a)
   *   db.insert(b)
   * })
   *
   * // ❌ 错误：会抛错并回滚
   * db.transaction(async () => {
   *   await fetchExternal()
   *   db.insert(a)
   * })
   * ```
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

  // ---------- 备份 / 关闭 ----------

  backup(fileName: string): Promise<void> {
    return this.store.backup(fileName)
  }

  restore(fileName: string): Promise<void> {
    return this.store.restore(fileName)
  }

  close(): void {
    this.store.close()
  }

  // ---------- 内部工具 ----------

  private debug(): boolean {
    return this.params.buildParams.debugSql === true
  }

  private logSql(sql: string, args?: relationalStore.ValueType[]): void {
    if (this.debug()) {
      hilog.debug(DOMAIN, TAG, `SQL:${sql}，args:${JSON.stringify(args ?? [])}`)
    }
  }

  private logQuery(predicates: relationalStore.RdbPredicates, columns?: string[]): void {
    if (this.debug()) {
      const info = relationalStore.getQuerySqlInfo(predicates, columns)
      this.logSql(info.sql, info.args)
    }
  }

  /**
   * 把实体转成 ValueBucket，按 `@Id`/`@Field` 装饰过的属性筛选。
   * - `undefined`：跳过（让 SQL 默认值生效）
   * - `null`：直通（写入 SQL NULL）
   * - 其它：原值透传，HarmonyOS 底层负责把 JS boolean 转 1/0、Date 转字符串等
   *
   * @param excludeColumn 可选，需要从结果中排除的列名（updateById 用来去掉主键）
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

  private executeDelete(predicates: relationalStore.RdbPredicates): number {
    if (this.debug()) {
      const info = relationalStore.getDeleteSqlInfo(predicates)
      this.logSql(info.sql, info.args)
    }
    return this.store.deleteSync(predicates)
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
