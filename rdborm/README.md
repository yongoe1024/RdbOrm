# RdbOrm

轻量级 RDB ORM，使用装饰器完成实体映射，构造查询条件，简单无需SQL操作。  
联系邮箱 121887765@qq.com

## 特性

- 使用 `@Table`、`@Field` 维护表名和字段映射
- 通过 `RdbOrm.build()` 创建表级操作对象
- 通过 `DBHelper` 执行增删改查、事务、备份恢复
- 通过 `Wrapper` 链式拼接查询与更新条件
- 可开启 `RdbOrm.debugSql` 输出 SQL 调试日志

## 下载安装

1. 安装最新版 `ohpm i @dims/rdborm`
2. 升级版本 `ohpm update @dims/rdborm`，建议使用最新版避免bug

OpenHarmony ohpm
环境配置等更多内容，请参考[如何安装 OpenHarmony ohpm 包](https://ohpm.openharmony.cn/#/cn/help/downloadandinstall)

[工程版本升级教程](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-integrated-project-migration)

## 完整流程

### 1. 定义实体

使用 `@Table` 声明表名，使用 `@Field` 声明字段映射。

```ts
import { Field, Table } from '@dims/rdborm'

@Table('t_emp')
export class Employee {
  @Field({ id: true })
  id?: number

  @Field()
  age?: number

  @Field()
  name?: string

  @Field()
  salary?: number

  @Field({ name: 'is_on_job' })
  onJob?: boolean

  constructor() {
  }
}
```

说明：

- `@Table('t_emp')` 对应数据库表名。
- `@Field()` 使用属性名作为字段名。
- `@Field({ name: 'xxx' })` 可指定数据库字段名。
- `@Field({ id: true })` 标记主键字段，供 `updateById`、`deleteById` 使用。
- 未添加 `@Field` 的属性不会参与插入和实体映射。

### 2. 构建 ORM 对象

```ts
import { RdbOrm } from '@dims/rdborm'
import { relationalStore } from '@kit.ArkData'

const orm = RdbOrm.build<Employee>({
  context: getContext(),
  class: Employee,
  config: {
    name: 'RdbTest.db',
    securityLevel: relationalStore.SecurityLevel.S3
  }
})
```

说明：

- `class` 传实体类本身，不是实例。
- `context` 一般传 `getContext()`。
- `config` 是 HarmonyOS RDB 的 `StoreConfig`。

### 3. 获取 DBHelper

```ts
const db = await orm.getDBHelper()
```

如果在 taskpool 或特殊上下文中，也可以显式传入 `context`：

```ts
const db = await orm.getDBHelper(context)
```

### 4. 建表

当前项目没有自动建表功能，需要自己执行建表 SQL。

```ts
db.executeSql(`
  create table if not exists t_emp (
    id integer primary key autoincrement,
    age integer,
    name text,
    salary double,
    is_on_job integer
  )
`)
```

### 5. 插入数据

```ts
const emp = new Employee()
emp.age = 24
emp.name = 'Tom'
emp.salary = 12000
emp.onJob = true

const rowId = db.insert(emp)
```

批量插入：

```ts
const list: Employee[] = []

const e1 = new Employee()
e1.name = 'Tom'
e1.age = 24
list.push(e1)

const e2 = new Employee()
e2.name = 'Lucy'
e2.age = 28
list.push(e2)

const count = db.batchInsert(list)
```

### 6. 查询数据

查询全部：

```ts
const allList = db.select()
```

带条件查询：

```ts
const list = db.select(
  new Wrapper()
    .gte('age', 18)
    .like('name', '%o%')
    .orderByDesc('id')
    .limit(20)
)
```

指定查询列：

```ts
const list = db.select(
  new Wrapper().orderByAsc('id'),
  ['id', 'name', 'age']
)
```

统计数量：

```ts
const total = db.count(new Wrapper().eq('is_on_job', true))
```

原生 SQL 查询：

```ts
const rows = db.querySql(
  'select id, name from t_emp where age > ?',
  [18]
)
```

### 7. 更新数据

按条件更新：

```ts
const affectRows = db.update(
  new Wrapper()
    .set('name', 'New Name')
    .set('age', 30)
    .eq('id', 1)
)
```

按主键更新：

```ts
const emp = new Employee()
emp.id = 1
emp.name = 'Tom'
emp.age = 25

const affectRows = db.updateById(emp)
```

### 8. 删除数据

按条件删除：

```ts
const affectRows = db.delete(new Wrapper().lt('age', 18))
```

按主键删除：

```ts
const affectRows = db.deleteById(1)
```

### 9. 事务

```ts
db.beginTransaction()
try {
  db.insert(emp1)
  db.insert(emp2)
  db.commit()
} catch (error) {
  db.rollBack()
  throw error
}
```

### 10. 备份、恢复、关闭

```ts
await db.backup('RdbTest.db.bak')
await db.restore('RdbTest.db.bak')
db.close()
```

## 调试日志

开启 SQL 日志：

```ts
RdbOrm.debugSql = true
```

开启后，`executeSql`、`querySql`、`select`、`count`、`insert`、`update`、`updateById`、`delete` 等会通过 `hilog` 输出 SQL 与参数。

## DBHelper 函数表

| 方法                                     | 参数                               | 返回值                        | 说明                               |
|----------------------------------------|----------------------------------|----------------------------|----------------------------------|
| `DBHelper.create<T>(params, context?)` | `TableParams<T>`, `Context?`     | `Promise<DBHelper<T>>`     | 创建一个新的数据库帮助对象                    |
| `getVersion()`                         | 无                                | `number`                   | 获取数据库版本                          |
| `updateVersion(v)`                     | `number`                         | `void`                     | 更新数据库版本                          |
| `getStore()`                           | 无                                | `relationalStore.RdbStore` | 获取底层 `RdbStore`                  |
| `executeSql(sql, args?)`               | `string`, `ValueType[]?`         | `ValueType`                | 执行原生 SQL                         |
| `querySql(sql, args?)`                 | `string`, `ValueType[]?`         | `ValuesBucket[]`           | 执行原生查询 SQL，返回原始结果                |
| `select(wrapper?, columns?)`           | `Wrapper?`, `string[]?`          | `T[]`                      | 按条件查询实体列表                        |
| `count(wrapper?)`                      | `Wrapper?`                       | `number`                   | 查询记录数                            |
| `insert(obj, conflict?)`               | `T`, `ConflictResolution?`       | `number`                   | 插入单条数据，成功时返回行 ID                 |
| `batchInsert(list, conflict?)`         | `T[]`, `ConflictResolution?`     | `number`                   | 批量插入，成功时返回插入数量                   |
| `update(wrapper, conflict?)`           | `Wrapper`, `ConflictResolution?` | `number`                   | 按条件更新，`Wrapper` 中必须包含 `set(...)` |
| `delete(wrapper?)`                     | `Wrapper?`                       | `number`                   | 按条件删除；不传条件时会删除整表数据               |
| `updateById(obj, conflict?)`           | `T`, `ConflictResolution?`       | `number`                   | 按主键更新实体，实体必须包含主键属性值              |
| `deleteById(id)`                       | `ValueType`                      | `number`                   | 按主键删除，要求实体定义主键字段                 |
| `beginTransaction()`                   | 无                                | `void`                     | 开启事务                             |
| `commit()`                             | 无                                | `void`                     | 提交事务                             |
| `rollBack()`                           | 无                                | `void`                     | 回滚事务                             |
| `backup(fileName)`                     | `string`                         | `Promise<void>`            | 备份数据库                            |
| `restore(fileName)`                    | `string`                         | `Promise<void>`            | 恢复数据库                            |
| `close()`                              | 无                                | `void`                     | 关闭数据库连接                          |

## Wrapper 函数表

`Wrapper` 用于构造查询条件、排序、分页、更新字段和逻辑分组，方法均支持链式调用。

### 基础方法

| 方法                              | 参数                                | 说明           |
|---------------------------------|-----------------------------------|--------------|
| `getActions()`                  | 无                                 | 获取内部动作列表的浅拷贝 |
| `set(field, value, condition?)` | `string`, `ValueType`, `boolean?` | 更新时设置字段值     |

### 比较条件

| 方法                                          | 参数                                             | 说明          |
|---------------------------------------------|------------------------------------------------|-------------|
| `eq(field, value, condition?)`              | `string`, `ValueType`, `boolean?`              | 等于          |
| `notEq(field, value, condition?)`           | `string`, `ValueType`, `boolean?`              | 不等于         |
| `lt(field, value, condition?)`              | `string`, `ValueType`, `boolean?`              | 小于          |
| `lte(field, value, condition?)`             | `string`, `ValueType`, `boolean?`              | 小于等于        |
| `gt(field, value, condition?)`              | `string`, `ValueType`, `boolean?`              | 大于          |
| `gte(field, value, condition?)`             | `string`, `ValueType`, `boolean?`              | 大于等于        |
| `between(field, start, end, condition?)`    | `string`, `ValueType`, `ValueType`, `boolean?` | 区间匹配        |
| `notBetween(field, start, end, condition?)` | `string`, `ValueType`, `ValueType`, `boolean?` | 非区间匹配       |
| `in(field, value, condition?)`              | `string`, `ValueType[]`, `boolean?`            | 在集合中        |
| `notIn(field, value, condition?)`           | `string`, `ValueType[]`, `boolean?`            | 不在集合中       |
| `isNull(field, condition?)`                 | `string`, `boolean?`                           | 字段为 `null`  |
| `isNotNull(field, condition?)`              | `string`, `boolean?`                           | 字段不为 `null` |

### 字符串条件

| 方法                                      | 参数                             | 说明          |
|-----------------------------------------|--------------------------------|-------------|
| `contains(field, value, condition?)`    | `string`, `string`, `boolean?` | 包含字符串       |
| `notContains(field, value, condition?)` | `string`, `string`, `boolean?` | 不包含字符串      |
| `beginsWith(field, value, condition?)`  | `string`, `string`, `boolean?` | 以字符串开头      |
| `endsWith(field, value, condition?)`    | `string`, `string`, `boolean?` | 以字符串结尾      |
| `like(field, value, condition?)`        | `string`, `string`, `boolean?` | `LIKE` 模糊查询 |
| `notLike(field, value, condition?)`     | `string`, `string`, `boolean?` | `NOT LIKE`  |
| `glob(field, value, condition?)`        | `string`, `string`, `boolean?` | `GLOB` 匹配   |

### 排序、分页、分组

| 方法                                          | 参数                                             | 说明      |
|---------------------------------------------|------------------------------------------------|---------|
| `orderByAsc(field, condition?)`             | `string`, `boolean?`                           | 升序排序    |
| `orderByDesc(field, condition?)`            | `string`, `boolean?`                           | 降序排序    |
| `distinct(condition?)`                      | `boolean?`                                     | 去重      |
| `limit(value, condition?)`                  | `number`, `boolean?`                           | 限制返回数量  |
| `offset(value, condition?)`                 | `number`, `boolean?`                           | 设置偏移量   |
| `groupBy(fields, condition?)`               | `string \| string[]`, `boolean?`               | 分组      |
| `having(sql, argsOrCondition?, condition?)` | `string`, `ValueType[] \| boolean`, `boolean?` | 分组后过滤条件 |
| `indexedBy(field, condition?)`              | `string`, `boolean?`                           | 指定索引列   |

### 逻辑条件

| 方法                         | 参数                    | 说明                 |
|----------------------------|-----------------------|--------------------|
| `or(wrapper, condition?)`  | `Wrapper`, `boolean?` | 追加 `OR (...)` 逻辑块  |
| `and(wrapper, condition?)` | `Wrapper`, `boolean?` | 追加 `AND (...)` 逻辑块 |

### 分布式设备条件

| 方法                               | 参数                     | 说明        |
|----------------------------------|------------------------|-----------|
| `inDevices(devices, condition?)` | `string[]`, `boolean?` | 指定同步设备    |
| `inAllDevices(condition?)`       | `boolean?`             | 指定所有已连接设备 |

## Wrapper 示例

### 条件查询

```ts
const wrapper = new Wrapper()
  .gte('age', 18)
  .lte('age', 35)
  .eq('is_on_job', true)
  .orderByDesc('id')
  .limit(10)

const list = db.select(wrapper)
```

### 逻辑分组

```ts
const wrapper = new Wrapper()
  .eq('is_on_job', true)
  .and(
    new Wrapper()
      .gte('age', 18)
      .lte('age', 30)
  )
  .or(
    new Wrapper()
      .like('name', '%Tom%')
  )
```

### 条件更新

```ts
const wrapper = new Wrapper()
  .set('name', 'Jerry')
  .set('salary', 15000)
  .eq('id', 1)

db.update(wrapper)
```

### 动态条件拼接

所有 `Wrapper` 方法都支持最后一个 `condition?: boolean` 参数，可用于按条件决定是否拼接：

```ts
const hasName = true
const hasAge = false

const wrapper = new Wrapper()
  .like('name', '%Tom%', hasName)
  .gte('age', 18, hasAge)
  .orderByDesc('id')
```

## 实际行为说明

根据当前实现，使用时建议注意以下几点：

- 需要先自行建表，实体装饰器只负责映射，不负责自动建表。
- `delete()` 不传条件时会删除当前表的全部数据，使用前请确认。
- `update()` 的 `Wrapper` 必须至少包含一个 `set(...)`，否则会抛错。
- `updateById()` 和 `deleteById()` 依赖主键字段，实体中必须有 `@Field({ id: true })`。
- `updateById(obj)` 会使用实体主键属性作为查询条件，并更新已映射字段。
- `select(columns)` 支持指定查询列；如果查询结果中包含未映射到实体字段的列，当前实现会直接挂到返回对象上。
- 插入或按主键更新时，只会处理实体实例中当前存在且带 `@Field` 的属性。

## 最小示例

```ts
import { relationalStore } from '@kit.ArkData'
import { Field, RdbOrm, Table, Wrapper } from '@dims/rdborm'

@Table('t_user')
class User {
  @Field({ id: true })
  id?: number

  @Field()
  name?: string

  @Field()
  age?: number
}

async function demo(context: Context) {
  const orm = RdbOrm.build<User>({
    context,
    class: User,
    config: {
      name: 'demo.db',
      securityLevel: relationalStore.SecurityLevel.S3
    }
  })

  const db = await orm.getDBHelper()

  db.executeSql(`
    create table if not exists t_user (
      id integer primary key autoincrement,
      name text,
      age integer
    )
  `)

  const user = new User()
  user.name = 'Alice'
  user.age = 20
  db.insert(user)

  const list = db.select(new Wrapper().gte('age', 18).orderByDesc('id'))
  return list
}
```
