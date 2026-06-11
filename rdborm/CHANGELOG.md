# 版本记录

## 2.0.0

- 装饰器实体映射：`@Table` / `@Field` / `@Id`，支持 `@Field({ enableBoolMapper: true })` 布尔字段读取转换
- 自动建表 / 删表：`createTable()` / `dropTable()`
- 完整 CRUD：`insert` / `batchInsert` / `select` / `selectOne` / `count` / `update` / `updateById` / `delete` / `deleteById` / `clear`
- 链式查询条件构造器 `Wrapper`
- 事务包装 `transaction(fn)`（抛错自动回滚）
