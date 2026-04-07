import { relationalStore } from "@kit.ArkData"

type WrapperActionType =
  | 'set'
  | 'inDevices'
  | 'inAllDevices'
  | 'eq'
  | 'notEq'
  | 'or'
  | 'and'
  | 'contains'
  | 'beginsWith'
  | 'endsWith'
  | 'isNull'
  | 'isNotNull'
  | 'like'
  | 'glob'
  | 'between'
  | 'notBetween'
  | 'lt'
  | 'lte'
  | 'gt'
  | 'gte'
  | 'orderByAsc'
  | 'orderByDesc'
  | 'distinct'
  | 'limit'
  | 'offset'
  | 'groupBy'
  | 'indexedBy'
  | 'in'
  | 'notIn'
  | 'notLike'
  | 'having'
  | 'notContains'

/**
 * 条件实体
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
 * 构造查询参数
 */
export class Wrapper {
  private actions: WrapperAction[] = []

  constructor() {
  }

  getActions(): WrapperAction[] {
    return [...this.actions]
  }


  private pushAction(action: WrapperAction, condition: boolean = true): Wrapper {
    if (condition) {
      this.actions.push(action)
    }
    return this
  }

  /**
   * update set 修改某字段
   * @param field 字段
   * @param value 值
   * @returns Wrapper
   */
  set(field: string, value: relationalStore.ValueType, condition: boolean = true) {
    return this.pushAction({ type: 'set', field, value }, condition)
  }

  /**
   * 指定分布式数据库同步设备
   * @param devices 设备列表
   * @returns Wrapper
   */
  inDevices(devices: string[], condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'inDevices', devices }, condition)
  }

  /**
   * 指定所有已连接设备
   * @returns Wrapper
   */
  inAllDevices(condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'inAllDevices' }, condition)
  }

  /**
   * 等于
   * @param field 字段
   * @param value 值
   * @returns Wrapper
   */
  eq(field: string, value: relationalStore.ValueType, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'eq', field, value }, condition)
  }

  /**
   * 不等于
   * @param field 字段
   * @param value 值
   * @returns Wrapper
   */
  notEq(field: string, value: relationalStore.ValueType, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'notEq', field, value }, condition)
  }

  /**
   * 字段的值，在给定的集合中
   * @param field 字段
   * @param value 值的数组
   * @returns Wrapper
   */
  in(field: string, value: relationalStore.ValueType[], condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'in', field, values: value }, condition)
  }

  /**
   * 字段的值，不在给定的集合中
   * @param field 字段
   * @param value 值的数组
   * @returns Wrapper
   */
  notIn(field: string, value: relationalStore.ValueType[], condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'notIn', field, values: value }, condition)
  }

  /**
   * 小于
   * @param field 字段
   * @param value 值
   * @returns Wrapper
   */
  lt(field: string, value: relationalStore.ValueType, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'lt', field, value }, condition)
  }

  /**
   * 小于等于
   * @param field 字段
   * @param value 值
   * @returns Wrapper
   */
  lte(field: string, value: relationalStore.ValueType, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'lte', field, value }, condition)
  }

  /**
   * 大于
   * @param field 字段
   * @param value 值
   * @returns Wrapper
   */
  gt(field: string, value: relationalStore.ValueType, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'gt', field, value }, condition)
  }

  /**
   * 大于等于
   * @param field 字段
   * @param value 值
   * @returns Wrapper
   */
  gte(field: string, value: relationalStore.ValueType, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'gte', field, value }, condition)
  }

  /**
   * 设置单个字段的 BETWEEN 条件
   * @param field 字段
   * @param start 起始值
   * @param end 结束值
   * @returns Wrapper
   */
  between(field: string, start: relationalStore.ValueType, end: relationalStore.ValueType,
    condition: boolean = true): Wrapper {
    return this.pushAction({
      type: 'between',
      field,
      start,
      end
    }, condition)
  }

  /**
   * 设置单个字段的 NOT BETWEEN 条件
   * @param field 字段
   * @param start 起始值
   * @param end 结束值
   * @returns Wrapper
   */
  notBetween(field: string, start: relationalStore.ValueType, end: relationalStore.ValueType,
    condition: boolean = true): Wrapper {
    return this.pushAction({
      type: 'notBetween',
      field,
      start,
      end
    }, condition)
  }

  /**
   * 包含指定字符串
   * @param field 字段
   * @param value 值
   * @returns Wrapper
   */
  contains(field: string, value: string, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'contains', field, value }, condition)
  }

  /**
   * 不包含指定字符串
   * @param field 字段
   * @param value 值
   * @returns Wrapper
   */
  notContains(field: string, value: string, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'notContains', field, value }, condition)
  }

  /**
   * 以指定字符串开头
   * @param field 字段
   * @param value 值
   * @returns Wrapper
   */
  beginsWith(field: string, value: string, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'beginsWith', field, value }, condition)
  }

  /**
   * 以指定字符串结尾
   * @param field 字段
   * @param value 值
   * @returns Wrapper
   */
  endsWith(field: string, value: string, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'endsWith', field, value }, condition)
  }

  /**
   * 单个字段的模糊匹配条件
   * @param field 字段
   * @param value 值
   * @returns Wrapper
   */
  like(field: string, value: string, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'like', field, value }, condition)
  }

  /**
   * 单个字段的非模糊匹配条件
   * @param field 字段
   * @param value 值
   * @returns Wrapper
   */
  notLike(field: string, value: string, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'notLike', field, value }, condition)
  }

  /**
   * 通配符匹配，大小写敏感
   * @param field 字段
   * @param value 值
   * @returns Wrapper
   */
  glob(field: string, value: string, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'glob', field, value }, condition)
  }

  /**
   * 单个字段为null
   * @param field 字段
   * @returns Wrapper
   */
  isNull(field: string, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'isNull', field }, condition)
  }

  /**
   * 单个字段不为null
   * @param field 字段
   * @returns Wrapper
   */
  isNotNull(field: string, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'isNotNull', field }, condition)
  }

  /**
   * 对某字段排序-升序。可以调用多次，按顺序拼接SQL
   * @param field 字段
   * @returns Wrapper
   */
  orderByAsc(field: string, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'orderByAsc', field }, condition)
  }

  /**
   * 对某字段排序-降序。可以调用多次，按顺序拼接SQL
   * @param field 字段
   * @returns Wrapper
   */
  orderByDesc(field: string, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'orderByDesc', field }, condition)
  }

  /**
   * 去重查询
   * @returns Wrapper
   */
  distinct(condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'distinct' }, condition)
  }

  /**
   * 限制返回记录数
   * @param value 数量
   * @returns Wrapper
   */
  limit(value: number, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'limit', numberValue: value }, condition)
  }

  /**
   * 设置结果偏移量
   * @param value 偏移量
   * @returns Wrapper
   */
  offset(value: number, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'offset', numberValue: value }, condition)
  }

  /**
   * 分组查询，一般用getObject接收
   * @param fields 可以传多个字段
   * @returns Wrapper
   */
  groupBy(fields: string | string[], condition: boolean = true): Wrapper {
    const fieldList = Array.isArray(fields) ? fields : [fields]
    return this.pushAction({ type: 'groupBy', fields: fieldList }, condition)
  }

  /**
   * 指定索引列
   * @param field 索引列
   * @returns Wrapper
   */
  indexedBy(field: string, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'indexedBy', field }, condition)
  }

  /**
   * 过滤分组后的结果
   * @param sql having后面的sql条件
   * @returns Wrapper
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
    return this.pushAction({ type: 'having', sql, args }, enable)
  }

  /**
   * 在查询条件中添加 OR 逻辑，传入的wrapper仅用来拼接where条件
   * @param wrapper 一个新的Wrapper
   * @returns Wrapper
   */
  or(wrapper: Wrapper, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'or', wrapper }, condition)
  }

  /**
   * 在查询条件中添加 and 逻辑，传入的wrapper仅用来拼接where条件
   * @param wrapper 一个新的Wrapper
   * @returns Wrapper
   */
  and(wrapper: Wrapper, condition: boolean = true): Wrapper {
    return this.pushAction({ type: 'and', wrapper }, condition)
  }
}
