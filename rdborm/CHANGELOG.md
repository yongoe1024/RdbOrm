# 版本记录

## 2.0.0

### 主要变化

- `@Field({ id: true })` 改为 `@Field + @Id` 叠加——`@Field` 管列定义、`@Id` 仅标主键
- `Wrapper.set` 删除，`db.update` 改为 `update(values, wrapper)` 两参数分离
- `db.delete(wrapper)` 必须传 wrapper；新增 `db.clear()` 显式清空全表
- `RdbOrm.debugSql` 从全局静态改为 `BuildParams.debugSql` 实例选项
- 移除手动事务三件套（`beginTransaction / commit / rollBack`），统一用 `transaction(fn)`

### 新增

- `createTable()` / `dropTable()` 自动建表删表
- `transaction(fn)` 事务包装（抛错回滚）
- `selectOne(wrapper?)` 查询单条
- `clear()` 清空全表
- `@Field({ enableBoolMapper: true })` boolean 字段读取转换

## 1.0.0

- 初版发布
