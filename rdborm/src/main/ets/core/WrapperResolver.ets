import { relationalStore } from '@kit.ArkData'
import { Wrapper, WrapperAction } from './Wrapper'

// ---------- Wrapper action → RdbPredicates 分发映射 ----------


const ACTION_HANDLERS: Record<string, (p: relationalStore.RdbPredicates, a: WrapperAction,
  f: string | undefined) => void> = {
  "inDevices": (p, a) => p.inDevices(a.devices ?? []),
  "inAllDevices": (p) => p.inAllDevices(),
  "eq": (p, a, f) => p.equalTo(f!, a.value!),
  "notEq": (p, a, f) => p.notEqualTo(f!, a.value!),
  "lt": (p, a, f) => p.lessThan(f!, a.value!),
  "lte": (p, a, f) => p.lessThanOrEqualTo(f!, a.value!),
  "gt": (p, a, f) => p.greaterThan(f!, a.value!),
  "gte": (p, a, f) => p.greaterThanOrEqualTo(f!, a.value!),
  "between": (p, a, f) => p.between(f!, a.start!, a.end!),
  "notBetween": (p, a, f) => p.notBetween(f!, a.start!, a.end!),
  "in": (p, a, f) => p.in(f!, a.values ?? []),
  "notIn": (p, a, f) => p.notIn(f!, a.values ?? []),
  "isNull": (p, _, f) => p.isNull(f!),
  "isNotNull": (p, _, f) => p.isNotNull(f!),
  "like": (p, a, f) => p.like(f!, a.value as string),
  "notLike": (p, a, f) => p.notLike(f!, a.value as string),
  "glob": (p, a, f) => p.glob(f!, a.value as string),
  "contains": (p, a, f) => p.contains(f!, a.value as string),
  "notContains": (p, a, f) => p.notContains(f!, a.value as string),
  "beginsWith": (p, a, f) => p.beginsWith(f!, a.value as string),
  "endsWith": (p, a, f) => p.endsWith(f!, a.value as string),
  "orderByAsc": (p, _, f) => p.orderByAsc(f!),
  "orderByDesc": (p, _, f) => p.orderByDesc(f!),
  "distinct": (p) => p.distinct(),
  "limit": (p, a) => p.limitAs(a.numberValue!),
  "offset": (p, a) => p.offsetAs(a.numberValue!),
  "groupBy": (p, a) => p.groupBy(a.fields ?? []),
  "indexedBy": (p, _, f) => p.indexedBy(f!),
  "having": (p, a) => p.having(a.sql!, a.args),
}

/**
 * 把 `Wrapper` 翻译成底层 `RdbPredicates`。无 `wrapper` 时返回仅含表名的谓词（即全表）
 *
 * 这是 Wrapper（查询条件构造器）与 relationalStore（底层存储）之间唯一的翻译层
 */
export function buildPredicates(tableName: string, wrapper?: Wrapper): relationalStore.RdbPredicates {
  const predicates = new relationalStore.RdbPredicates(tableName)
  if (wrapper) {
    applyWrapper(predicates, wrapper)
  }
  return predicates
}

/**
 * 把 wrapper 的动作翻译到 RdbPredicates
 *
 * 大多数 action 通过 `ACTION_HANDLERS` 分发；`or`/`and` 需递归处理子 wrapper
 */
function applyWrapper(predicates: relationalStore.RdbPredicates, wrapper: Wrapper): void {
  const actions = wrapper.getActions()
  for (let i = 0; i < actions.length; i++) {
    const action = actions[i]
    const handler = ACTION_HANDLERS[action.type]
    if (handler) {
      handler(predicates, action, action.field)
    } else if (action.type === 'or') {
      predicates.or()
      applyLogicGroup(predicates, action.wrapper)
    } else if (action.type === 'and') {
      predicates.and()
      applyLogicGroup(predicates, action.wrapper)
    }
  }
}

function applyLogicGroup(predicates: relationalStore.RdbPredicates, wrapper?: Wrapper): void {
  if (!wrapper) {
    return
  }
  predicates.beginWrap()
  applyWrapper(predicates, wrapper)
  predicates.endWrap()
}
