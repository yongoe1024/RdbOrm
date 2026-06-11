import { relationalStore } from '@kit.ArkData'
import { ColumnMeta } from '../model/ColumnMeta'

// ---------- ColumnMeta → DDL 文本（模块级纯函数） ----------

/** 根据列元数据生成 `CREATE TABLE IF NOT EXISTS` 语句。 */
export function buildCreateTableSql(tableName: string, columns: ColumnMeta[]): string {
  const cols: string[] = []
  for (let i = 0; i < columns.length; i++) {
    cols.push(buildColumnDefSql(columns[i]))
  }
  return `CREATE TABLE IF NOT EXISTS ${quoteIdentifier(tableName)} (\n  ${cols.join(',\n  ')}\n)`
}

/** 生成 `DROP TABLE IF EXISTS` 语句。 */
export function buildDropTableSql(tableName: string): string {
  return `DROP TABLE IF EXISTS ${quoteIdentifier(tableName)}`
}

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
