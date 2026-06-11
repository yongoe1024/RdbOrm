import { relationalStore } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'

const DOMAIN: number = 0x0000
const TAG: string = 'rdborm'

/**
 * debug模式日志
 */
export class LogUtils {
  private isDebug: boolean

  constructor(isDebug: boolean) {
    this.isDebug = isDebug
  }

  logSql(sql: string, args?: relationalStore.ValueType[]): void {
    if (this.isDebug) {
      hilog.debug(DOMAIN, TAG, `SQL:${sql}，args:${JSON.stringify(args ?? [])}`)
    }
  }

  logQuery(predicates: relationalStore.RdbPredicates, columns?: string[]): void {
    if (this.isDebug) {
      try {
        const info = relationalStore.getQuerySqlInfo(predicates, columns)
        hilog.debug(DOMAIN, TAG, `SQL:${info.sql}，args:${JSON.stringify(info.args ?? [])}`)
      } catch (error) {
        hilog.error(DOMAIN, TAG, `logQuery:msg${error.message},code:${error.code}}`)
      }
    }
  }

  logInsert(table: string, values: relationalStore.ValuesBucket, conflict?: relationalStore.ConflictResolution) {
    if (this.isDebug) {
      try {
        const info = relationalStore.getInsertSqlInfo(table, values, conflict)
        hilog.debug(DOMAIN, TAG, `SQL:${info.sql}，args:${JSON.stringify(info.args ?? [])}`)
      } catch (error) {
        hilog.error(DOMAIN, TAG, `logQuery:msg${error.message},code:${error.code}}`)
      }
    }
  }

  logUpdate(predicates: relationalStore.RdbPredicates, values: relationalStore.ValuesBucket,
    conflict?: relationalStore.ConflictResolution) {
    if (this.isDebug) {
      try {
        const info = relationalStore.getUpdateSqlInfo(predicates, values, conflict)
        hilog.debug(DOMAIN, TAG, `SQL:${info.sql}，args:${JSON.stringify(info.args ?? [])}`)
      } catch (error) {
        hilog.error(DOMAIN, TAG, `logQuery:msg${error.message},code:${error.code}}`)
      }
    }
  }

  logDelete(predicates: relationalStore.RdbPredicates) {
    if (this.isDebug) {
      try {
        const info = relationalStore.getDeleteSqlInfo(predicates)
        hilog.debug(DOMAIN, TAG, `SQL:${info.sql}，args:${JSON.stringify(info.args ?? [])}`)
      } catch (error) {
        hilog.error(DOMAIN, TAG, `logQuery:msg${error.message},code:${error.code}}`)
      }
    }
  }
}