数据库中常驻有4个读连接和1个写连接
数据库同一时间只能支持一个写操作，防止冲突
ArkTS侧支持的基本数据类型：number、string、二进制类型数据、boolean，数据库侧不支持布尔值
由于共享内存的大小限制为2MB，因此单条数据的大小也必须严格小于2MB，建议一条数据不要超过2M。超出该大小，插入成功，读取失败
不同的应用上下文，会产生多个数据库，例如每个UIAbility都有各自的上下文
单次查询数据量不超过5000条。
在TaskPool中查询。
拼接SQL语句尽量简洁。
合理地分批次查询
由于共享内存的大小限制为2MB，因此单条数据的大小也必须严格小于2MB
实体类需要一个空构造函数


getValue 符合ValueType，否则返回14800000，超出integer范围会丢精度，可用getString
getBlob INTEGER、DOUBLE、TEXT、BLOB类型，会转成字节数组类型返回指定值，如果该列内容为空时，会返回空字节数组，其他类型则返回14800000
getString INTEGER、DOUBLE、TEXT、BLOB类型，会以字符串形式返回指定值 空INTEGER为空串，DOUBLE会精度丢失
getLong INTEGER、DOUBLE、TEXT、BLOB类型，会转成Long
getDouble 为INTEGER、DOUBLE、TEXT、BLOB类型，会转成double类型返回指定值,空为0.0
getAsset Asset或null

| ArkTs类型      | RDB类型            | 说明                                                                                                 |
|--------------|------------------|----------------------------------------------------------------------------------------------------|
| null         | null             | null                                                                                               |
| number       | INTEGER、DOUBLE   | 数字                                                                                                 |
| string       | TEXT             | 字符串                                                                                                |
| boolean      |                  | 布尔值                                                                                                |
| Uint8Array   | BLOB             | Uint8类型的数组                                                                                         |
| Asset        | ASSET            | 创表语句中，类型应当为：ASSET                                                                                  |
| Assets       | ASSETS           | 创表语句中，类型应当为：ASSETS                                                                                 |
| Float32Array | floatvector(128) | 浮点数组  ,创表语句中，类型应当为：floatvector(128)                                                                |
| bigint       | UNLIMITED INT    | 长整数， 创表语句中，类型应当为：UNLIMITED INT，查询条件不能比较大小、排序 ，ArkTs侧为'let data = BigInt(1234)'或'let data = 1234n'。 |
