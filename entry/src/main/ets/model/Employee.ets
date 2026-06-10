import { Field, Id, Table } from '@dims/rdborm'

@Table('t_emp')
export class Employee {
  // 主键
  @Field({ type: 'INTEGER' })
  @Id()
  id?: number
  // 整数
  @Field({ type: 'INTEGER' })
  age?: number
  // 字符串
  @Field({ type: 'TEXT' })
  name?: string
  // 浮点
  @Field({ type: 'REAL' })
  dou?: number
  // 布尔（SQLite 用 INTEGER 存；enableBoolMapper 让查询结果自动从 1/0 转回 boolean）
  @Field({ type: 'INTEGER', enableBoolMapper: true })
  bool?: boolean
  // 多余 - 未装饰，不会入库
  other?: string

  constructor() {
  }
}
