import { Field, Table } from "@dims/rdborm"

@Table('t_emp')
export class Employee {
  // 大数
  @Field()
  id?: number
  // 整数
  @Field()
  age?: number
  // 字符串
  @Field()
  name?: string
  // 浮点
  @Field()
  dou?: number
  // 布尔
  @Field()
  bool?: boolean
  // 多余
  other?: string


}