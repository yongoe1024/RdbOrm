import { relationalStore } from '@kit.ArkData'
import { WrapperActionType } from './WrapperResolver'

/**
 * 单条条件动作
 */
export interface WrapperAction {
  type: WrapperActionType
  field?: string
  value?: relationalStore.ValueType
  values?: relationalStore.ValueType[]
  devices?: string[]
  start?: relationalStore.ValueType
  end?: relationalStore.ValueType
  fields?: string[]
  sql?: string
  args?: relationalStore.ValueType[]
  numberValue?: number
  wrapper?: Wrapper
}

/**
 * Wrapper 中所有"值比较"类 action 类型
 *
 * **维护规则**：给 Wrapper 新增一个"值比较"类方法时，必须在下面列表中加对应的 type 字符串
 * `or` / `and` 不属于此列表——由 `hasWhereActions()` 单独递归处理子 wrapper
 */
const WRAPPER_WHERE_SET: Set<string> = new Set([
  'eq', 'notEq', 'contains', 'notContains', 'beginsWith', 'endsWith',
  'isNull', 'isNotNull', 'like', 'notLike', 'glob',
  'between', 'notBetween', 'lt', 'lte', 'gt', 'gte', 'in', 'notIn',
])

/**
 * 链式查询条件构造器
 *
 * 所有方法的 `field: string` 参数都是**数据库列名**
 */
export class Wrapper {
  private actions: WrapperAction[] = []

  /**
   * @internal 仅供内部翻译层（WrapperResolver）读取，外部不应调用或修改返回值
   */
  getActions(): WrapperAction[] {
    return this.actions.slice()
  }

  /**
   * 当前 Wrapper 是否至少包含一个 WHERE 条件（eq / lt / like / between / in / isNull 等值比较动作
   * 含递归检查 `or` / `and` 子 wrapper）
   *
   * 防全表更新/删除
   */
  hasWhereActions(): boolean {
    for (let i = 0; i < this.actions.length; i++) {
      const t = this.actions[i].type
      if (t === 'or' || t === 'and') {
        const sub = this.actions[i].wrapper
        if (sub && sub.hasWhereActions()) {
          return true
        }
      } else if (WRAPPER_WHERE_SET.has(t)) {
        return true
      }
    }
    return false
  }

  /**
   * 浅拷贝当前 Wrapper（actions 数组拷贝，单个 action 引用共享）
   *
   * 用于在不污染调用方对象的前提下追加额外条件，例如 selectOne 内部的 LIMIT 1
   */
  clone(): Wrapper {
    const fresh = new Wrapper()
    fresh.pushAll(this.actions)
    return fresh
  }

  private pushAll(actions: WrapperAction[]): void {
    for (let i = 0; i < actions.length; i++) {
      this.actions.push(actions[i])
    }
  }

  private push(action: WrapperAction, condition: boolean): Wrapper {
    if (condition) {
      this.actions.push(action)
    }
    return this
  }

  inDevices(devices: string[], condition: boolean = true): Wrapper {
    return this.push({ type: 'inDevices', devices }, condition)
  }

  inAllDevices(condition: boolean = true): Wrapper {
    return this.push({ type: 'inAllDevices' }, condition)
  }

  eq(field: string, value: relationalStore.ValueType, condition: boolean = true): Wrapper {
    return this.push({ type: 'eq', field, value }, condition)
  }

  notEq(field: string, value: relationalStore.ValueType, condition: boolean = true): Wrapper {
    return this.push({ type: 'notEq', field, value }, condition)
  }

  in(field: string, value: relationalStore.ValueType[], condition: boolean = true): Wrapper {
    return this.push({ type: 'in', field, values: value }, condition)
  }

  notIn(field: string, value: relationalStore.ValueType[], condition: boolean = true): Wrapper {
    return this.push({ type: 'notIn', field, values: value }, condition)
  }

  lt(field: string, value: relationalStore.ValueType, condition: boolean = true): Wrapper {
    return this.push({ type: 'lt', field, value }, condition)
  }

  lte(field: string, value: relationalStore.ValueType, condition: boolean = true): Wrapper {
    return this.push({ type: 'lte', field, value }, condition)
  }

  gt(field: string, value: relationalStore.ValueType, condition: boolean = true): Wrapper {
    return this.push({ type: 'gt', field, value }, condition)
  }

  gte(field: string, value: relationalStore.ValueType, condition: boolean = true): Wrapper {
    return this.push({ type: 'gte', field, value }, condition)
  }

  between(field: string, start: relationalStore.ValueType, end: relationalStore.ValueType,
    condition: boolean = true): Wrapper {
    return this.push({
      type: 'between',
      field,
      start,
      end
    }, condition)
  }

  notBetween(field: string, start: relationalStore.ValueType, end: relationalStore.ValueType,
    condition: boolean = true): Wrapper {
    return this.push({
      type: 'notBetween',
      field,
      start,
      end
    }, condition)
  }

  contains(field: string, value: string, condition: boolean = true): Wrapper {
    return this.push({ type: 'contains', field, value }, condition)
  }

  notContains(field: string, value: string, condition: boolean = true): Wrapper {
    return this.push({ type: 'notContains', field, value }, condition)
  }

  beginsWith(field: string, value: string, condition: boolean = true): Wrapper {
    return this.push({ type: 'beginsWith', field, value }, condition)
  }

  endsWith(field: string, value: string, condition: boolean = true): Wrapper {
    return this.push({ type: 'endsWith', field, value }, condition)
  }

  like(field: string, value: string, condition: boolean = true): Wrapper {
    return this.push({ type: 'like', field, value }, condition)
  }

  notLike(field: string, value: string, condition: boolean = true): Wrapper {
    return this.push({ type: 'notLike', field, value }, condition)
  }

  glob(field: string, value: string, condition: boolean = true): Wrapper {
    return this.push({ type: 'glob', field, value }, condition)
  }

  isNull(field: string, condition: boolean = true): Wrapper {
    return this.push({ type: 'isNull', field }, condition)
  }

  isNotNull(field: string, condition: boolean = true): Wrapper {
    return this.push({ type: 'isNotNull', field }, condition)
  }

  orderByAsc(field: string, condition: boolean = true): Wrapper {
    return this.push({ type: 'orderByAsc', field }, condition)
  }

  orderByDesc(field: string, condition: boolean = true): Wrapper {
    return this.push({ type: 'orderByDesc', field }, condition)
  }

  distinct(condition: boolean = true): Wrapper {
    return this.push({ type: 'distinct' }, condition)
  }

  limit(value: number, condition: boolean = true): Wrapper {
    return this.push({ type: 'limit', numberValue: value }, condition)
  }

  offset(value: number, condition: boolean = true): Wrapper {
    return this.push({ type: 'offset', numberValue: value }, condition)
  }

  groupBy(fields: string | string[], condition: boolean = true): Wrapper {
    const fieldList = Array.isArray(fields) ? fields : [fields]
    return this.push({ type: 'groupBy', fields: fieldList }, condition)
  }

  indexedBy(field: string, condition: boolean = true): Wrapper {
    return this.push({ type: 'indexedBy', field }, condition)
  }

  /**
   * GROUP BY 之后追加 HAVING 子句。
   *
   * 第二参数支持两种用法（按 typeof 区分）：
   *   - 传 `ValueType[]`：作为 having SQL 的预编译参数；第三参数是拼接开关
   *   - 传 `boolean`：当作拼接开关，本次调用没有预编译参数
   *
   * ```ts
   * wrapper.having('count(*) > ?', [10])             // 走预编译，always 拼接
   * wrapper.having('count(*) > ?', [10], hasFilter)  // 走预编译，按开关拼接
   * wrapper.having('count(*) > 10', false)           // 不走预编译，按开关拼接（这里 false → 跳过）
   * ```
   *
   * 由于是原生 SQL 出口，args 不经 `@Field({ enableBoolMapper })`。
   */
  having(sql: string, argsOrCondition?: relationalStore.ValueType[] | boolean,
    condition: boolean = true): Wrapper {
    let args: relationalStore.ValueType[] | undefined = undefined
    let enable = condition
    if (typeof argsOrCondition === 'boolean') {
      enable = argsOrCondition
    } else {
      args = argsOrCondition
    }
    return this.push({ type: 'having', sql, args }, enable)
  }

  or(wrapper: Wrapper, condition: boolean = true): Wrapper {
    return this.push({ type: 'or', wrapper }, condition)
  }

  and(wrapper: Wrapper, condition: boolean = true): Wrapper {
    return this.push({ type: 'and', wrapper }, condition)
  }
}
