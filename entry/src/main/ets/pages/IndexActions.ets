import { Employee } from '../model/Employee'
import { relationalStore } from '@kit.ArkData'
import taskpool from '@ohos.taskpool'
import { showDialog } from '../util/MessageDialog'
import { RdbOrm, Wrapper } from '@dims/rdborm'

/**
 * Index 页面的所有按钮回调函数都拆到这里。
 * 每个 testXxx 接收当前 RdbOrm 实例（可能为 undefined），自己处理 try/catch 与弹窗。
 */

// ---------- 工具函数 ----------

async function getDb(orm?: RdbOrm<Employee>) {
  if (!orm) {
    throw new Error('ORM 尚未初始化')
  }
  try {
    return await orm.getDBHelper()
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error)
    throw new Error(`DBHelper 初始化失败：${msg}`)
  }
}

function getErrorMessage(error: Object): string {
  if (error instanceof Error) {
    return error.message
  }
  const text = JSON.stringify(error, null, 2)
  if (text && text !== '{}') {
    return text
  }
  return String(error)
}

function createEmployee(name: string, age: number, dou: number, bool: boolean): Employee {
  const employee = new Employee()
  employee.name = name
  employee.age = age
  employee.dou = dou
  employee.bool = bool
  return employee
}

// ---------- TaskPool worker（@Concurrent 必须 top-level 自包含） ----------

@Concurrent
async function taskpoolInsertEmployee(context: Context): Promise<number> {
  let orm = RdbOrm.build({
    context: context,
    class: Employee,
    config: {
      name: 'RdbTest.db',
      securityLevel: relationalStore.SecurityLevel.S3,
    },
    debugSql: true,
  })
  const db = await orm.getDBHelper()
  const employee = new Employee()
  employee.name = 'TaskPool Tom'
  employee.age = 26
  employee.dou = 93.6
  employee.bool = true
  return db.insert(employee)
}

@Concurrent
async function taskpoolQueryEmployee(context: Context): Promise<string> {
  let orm = RdbOrm.build({
    context: context,
    class: Employee,
    config: {
      name: 'RdbTest.db',
      securityLevel: relationalStore.SecurityLevel.S3,
    },
    debugSql: true,
  })
  const db = await orm.getDBHelper()
  const list = db.select()
  return JSON.stringify(list, null, 2)
}

// ---------- 测试函数 ----------

export async function testCreateTable(orm?: RdbOrm<Employee>): Promise<void> {
  try {
    const db = await getDb(orm)
    // 版本管理
    const version = db.getVersion()
    if (version == 0) {
      db.createTable()
      db.setVersion(1)
    } else if (version == 1) {
      //   ... ...
    }
    showDialog('建表完成（已根据装饰器自动生成 CREATE TABLE）')
  } catch (error) {
    showDialog(getErrorMessage(error))
  }
}

export async function testClearTable(orm?: RdbOrm<Employee>): Promise<void> {
  try {
    const db = await getDb(orm)
    const count = db.clear()
    showDialog(`清空完成，删除 ${count} 条`)
  } catch (error) {
    showDialog(getErrorMessage(error))
  }
}

export async function testDropTable(orm?: RdbOrm<Employee>): Promise<void> {
  try {
    const db = await getDb(orm)
    db.dropTable()
    showDialog('删除数据库表完成')
  } catch (error) {
    showDialog(getErrorMessage(error))
  }
}

export async function testInsert(orm?: RdbOrm<Employee>): Promise<void> {
  try {
    const db = await getDb(orm)
    const employee = createEmployee('Tom', 24, 88.5, true)
    employee.other = '不会入库'
    const rowId = db.insert(employee)
    showDialog(`插入成功，rowId=${rowId}`)
  } catch (error) {
    showDialog(getErrorMessage(error))
  }
}

export async function testBatchInsert(orm?: RdbOrm<Employee>): Promise<void> {
  try {
    const db = await getDb(orm)
    const count = db.batchInsert([
      createEmployee('Lucy', 28, 91.2, true),
      createEmployee('Jack', 31, 75.6, false)
    ])
    showDialog(`批量插入成功，count=${count}`)
  } catch (error) {
    showDialog(getErrorMessage(error))
  }
}

export async function testTransactionInsert(orm?: RdbOrm<Employee>): Promise<void> {
  try {
    const db = await getDb(orm)
    const inserted = db.transaction<number>(() => {
      let n = 0
      n += db.insert(createEmployee('Tx-Alice', 22, 60.0, true)) > 0 ? 1 : 0
      n += db.insert(createEmployee('Tx-Bob', 33, 80.0, false)) > 0 ? 1 : 0
      return n
    })
    showDialog(`事务插入完成，成功 ${inserted} 条`)
  } catch (error) {
    showDialog(getErrorMessage(error))
  }
}

export async function testSelect(orm?: RdbOrm<Employee>): Promise<void> {
  try {
    const db = await getDb(orm)
    const list = db.select(
      new Wrapper()
        .gte('age', 18)
        .orderByDesc('id')
        .limit(10)
    )
    const total = db.count()
    showDialog(`查询成功，总数=${total}\n${JSON.stringify(list, null, 2)}`)
  } catch (error) {
    showDialog(getErrorMessage(error))
  }
}

export async function testSelectOne(orm?: RdbOrm<Employee>): Promise<void> {
  try {
    const db = await getDb(orm)
    const one = db.selectOne(new Wrapper().orderByDesc('id'))
    showDialog(one ? `单条查询成功\n${JSON.stringify(one, null, 2)}` : '没有数据')
  } catch (error) {
    showDialog(getErrorMessage(error))
  }
}

export async function testBoolReadConvert(orm?: RdbOrm<Employee>): Promise<void> {
  try {
    const db = await getDb(orm)
    // enableBoolMapper 验证：
    // 1) 写入 entity.bool=true / false → HarmonyOS 底层存为 1 / 0
    // 2) 查询条件 eq('bool', true / false) → HarmonyOS 底层接受 JS boolean
    // 3) 读回时 enableBoolMapper 把 1/0 转回 true/false（typeof 应为 'boolean'）
    const trueOnly = db.select(new Wrapper().eq('bool', true).orderByDesc('id'))
    const falseOnly = db.select(new Wrapper().eq('bool', false).orderByDesc('id'))
    const preview = trueOnly
      .slice(0, 2)
      .map((e: Employee) => `id=${e.id} name=${e.name} bool=${e.bool} (typeof=${typeof e.bool})`)
      .join('\n')
    showDialog(
      `bool=true 共 ${trueOnly.length} 条；bool=false 共 ${falseOnly.length} 条\n` +
        `字段类型预览（应为 boolean）：\n${preview}`
    )
  } catch (error) {
    showDialog(getErrorMessage(error))
  }
}

export async function testTaskpoolInsert(): Promise<void> {
  try {
    const rowId = await taskpool.execute(taskpoolInsertEmployee, getContext())
    showDialog(`TaskPool 插入成功，rowId=${rowId}`)
  } catch (error) {
    showDialog(getErrorMessage(error))
  }
}

export async function testTaskpoolQuery(): Promise<void> {
  try {
    const result = await taskpool.execute(taskpoolQueryEmployee, getContext())
    showDialog(`TaskPool 查询成功\n${result}`)
  } catch (error) {
    showDialog(getErrorMessage(error))
  }
}

export async function testUpdate(orm?: RdbOrm<Employee>): Promise<void> {
  try {
    const db = await getDb(orm)
    const updateValues = new Employee()
    updateValues.name = 'Updated By Wrapper'
    updateValues.dou = 99.9
    const count = db.update(updateValues, new Wrapper().eq('name', 'Tom'))
    showDialog(`条件更新成功，影响 ${count} 条`)
  } catch (error) {
    showDialog(getErrorMessage(error))
  }
}

export async function testUpdateById(orm?: RdbOrm<Employee>): Promise<void> {
  try {
    const db = await getDb(orm)
    const employee = db.selectOne(new Wrapper().orderByDesc('id'))
    if (!employee) {
      showDialog('没有可更新的数据，请先插入')
      return
    }
    employee.name = 'Updated By Id'
    employee.age = (employee.age ?? 0) + 1
    const count = db.updateById(employee)
    showDialog(`按主键更新成功，影响 ${count} 条\n${JSON.stringify(employee, null, 2)}`)
  } catch (error) {
    showDialog(getErrorMessage(error))
  }
}

export async function testDeleteById(orm?: RdbOrm<Employee>): Promise<void> {
  try {
    const db = await getDb(orm)
    const target = db.selectOne(new Wrapper().orderByDesc('id'))
    if (!target || target.id === undefined) {
      showDialog('没有可删除的数据')
      return
    }
    const count = db.deleteById(target.id)
    showDialog(`按主键删除成功，id=${target.id}，影响 ${count} 条`)
  } catch (error) {
    showDialog(getErrorMessage(error))
  }
}

export async function testAllInOne(orm?: RdbOrm<Employee>): Promise<void> {
  try {
    const db = await getDb(orm)
    const logs: string[] = []

    db.createTable()
    logs.push('1. 自动建表完成')

    const clearCount = db.clear()
    logs.push(`2. 清空完成，删除 ${clearCount} 条`)

    const first = createEmployee('Tom', 24, 88.5, true)
    first.other = '不会入库'
    const firstRowId = db.insert(first)
    logs.push(`3. 单条插入完成，rowId=${firstRowId}`)

    const batchCount = db.batchInsert([
      createEmployee('Lucy', 28, 91.2, true),
      createEmployee('Jack', 31, 75.6, false)
    ])
    logs.push(`4. 批量插入完成，count=${batchCount}`)

    const txInserted = db.transaction<number>(() => {
      let n = 0
      n += db.insert(createEmployee('Tx-Alice', 22, 60.0, true)) > 0 ? 1 : 0
      n += db.insert(createEmployee('Tx-Bob', 33, 80.0, false)) > 0 ? 1 : 0
      return n
    })
    logs.push(`5. 事务插入完成，成功 ${txInserted} 条`)

    const beforeUpdate = db.select(new Wrapper().orderByDesc('id'))
    logs.push(`6. 初次查询完成，count=${beforeUpdate.length}`)

    const updateValues = new Employee()
    updateValues.name = 'Updated By Wrapper'
    updateValues.dou = 99.9
    const updateCount = db.update(updateValues, new Wrapper().eq('name', 'Tom'))
    logs.push(`7. 条件更新完成，影响 ${updateCount} 条`)

    const latest = db.selectOne(new Wrapper().orderByDesc('id'))
    if (latest) {
      latest.name = 'Updated By Id'
      latest.age = (latest.age ?? 0) + 1
      const updateByIdCount = db.updateById(latest)
      logs.push(`8. 主键更新完成，影响 ${updateByIdCount} 条，id=${latest.id}`)
    } else {
      logs.push('8. 主键更新跳过，没有可更新数据')
    }

    const deleteTarget = db.selectOne(new Wrapper().orderByDesc('id'))
    if (deleteTarget && deleteTarget.id !== undefined) {
      const deleteCount = db.deleteById(deleteTarget.id)
      logs.push(`9. 主键删除完成，影响 ${deleteCount} 条，id=${deleteTarget.id}`)
    } else {
      logs.push('9. 主键删除跳过，没有可删除数据')
    }

    const finalList = db.select(new Wrapper().orderByDesc('id'))
    const finalTotal = db.count()
    logs.push(`10. 最终查询完成，总数=${finalTotal}`)
    logs.push(JSON.stringify(finalList, null, 2))

    showDialog(logs.join('\n'))
  } catch (error) {
    showDialog(getErrorMessage(error))
  }
}
