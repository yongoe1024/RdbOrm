import { Employee } from '../model/Employee'
import { relationalStore } from '@kit.ArkData'
import { showDialog } from '../util/MessageDialog'
import { RdbOrm, Wrapper } from '@dims/rdborm'

@Entry
@Component
struct Index {
  orm?: RdbOrm<Employee>
  private readonly tableName: string = 't_emp'

  aboutToAppear(): void {
    RdbOrm.debugSql = true
    try {
      this.orm = RdbOrm.build({
        context: getContext(),
        class: Employee,
        config: {
          name: 'RdbTest.db',
          securityLevel: relationalStore.SecurityLevel.S3, // 数据库安全级别
        },
      })
    } catch (error) {
      showDialog('初始化失败')
    }
  }

  private async getDb() {
    try {
      const db = await this.orm?.getDBHelper()
      return db!
    } catch (error) {
      throw new Error('DBHelper 初始化失败')
    }
  }

  private getErrorMessage(error: Object): string {
    return JSON.stringify(error, null, 2)
  }

  private createEmployee(name: string, age: number, dou: number, bool: boolean): Employee {
    const employee = new Employee()
    employee.name = name
    employee.age = age
    employee.dou = dou
    employee.bool = bool
    return employee
  }

  private async testCreateTable(): Promise<void> {
    try {
      const db = await this.getDb()
      const res = db.executeSql(`
        create table if not exists ${this.tableName} (
          id integer primary key autoincrement,
          age integer,
          name text,
          dou double,
          bool integer
        )
      `)
      showDialog(`建表完成\n${JSON.stringify(res, null, 2)}`)
    } catch (error) {
      showDialog(this.getErrorMessage(error))
    }
  }

  private async testClearTable(): Promise<void> {
    try {
      const db = await this.getDb()
      const count = db.delete()
      showDialog(`清空完成，删除 ${count} 条`)
    } catch (error) {
      showDialog(this.getErrorMessage(error))
    }
  }

  private async testDropTable(): Promise<void> {
    try {
      const db = await this.getDb()
      const res = db.executeSql(`drop table if exists ${this.tableName}`)
      showDialog(`删除数据库表完成\n${JSON.stringify(res, null, 2)}`)
    } catch (error) {
      showDialog(this.getErrorMessage(error))
    }
  }

  private async testInsert(): Promise<void> {
    try {
      const db = await this.getDb()
      const employee = this.createEmployee('Tom', 24, 88.5, true)
      employee.other = '不会入库'
      const rowId = db.insert(employee)
      showDialog(`插入成功，rowId=${rowId}`)
    } catch (error) {
      showDialog(this.getErrorMessage(error))
    }
  }

  private async testBatchInsert(): Promise<void> {
    try {
      const db = await this.getDb()
      const count = db.batchInsert([
        this.createEmployee('Lucy', 28, 91.2, true),
        this.createEmployee('Jack', 31, 75.6, false)
      ])
      showDialog(`批量插入成功，count=${count}`)
    } catch (error) {
      showDialog(this.getErrorMessage(error))
    }
  }

  private async testSelect(): Promise<void> {
    try {
      const db = await this.getDb()
      const list = db.select(
        new Wrapper()
          .gte('age', 18)
          .orderByDesc('id')
          .limit(10)
      )
      const total = db.count()
      showDialog(`查询成功，总数=${total}\n${JSON.stringify(list, null, 2)}`)
    } catch (error) {
      showDialog(this.getErrorMessage(error))
    }
  }

  private async testUpdate(): Promise<void> {
    try {
      const db = await this.getDb()
      const count = db.update(
        new Wrapper()
          .set('name', 'Updated By Wrapper')
          .set('dou', 99.9)
          .eq('name', 'Tom')
      )
      showDialog(`条件更新成功，影响 ${count} 条`)
    } catch (error) {
      showDialog(this.getErrorMessage(error))
    }
  }

  private async testUpdateById(): Promise<void> {
    try {
      const db = await this.getDb()
      const list = db.select(new Wrapper().orderByDesc('id').limit(1))
      if (list.length === 0) {
        showDialog('没有可更新的数据，请先插入')
        return
      }
      const employee = list[0]
      employee.name = 'Updated By Id'
      employee.age = (employee.age ?? 0) + 1
      const count = db.updateById(employee)
      showDialog(`按主键更新成功，影响 ${count} 条\n${JSON.stringify(employee, null, 2)}`)
    } catch (error) {
      showDialog(this.getErrorMessage(error))
    }
  }

  private async testDeleteById(): Promise<void> {
    try {
      const db = await this.getDb()
      const list = db.select(new Wrapper().orderByDesc('id').limit(1))
      if (list.length === 0) {
        showDialog('没有可删除的数据')
        return
      }
      const id = list[0].id
      const count = db.deleteById(id!)
      showDialog(`按主键删除成功，id=${id}，影响 ${count} 条`)
    } catch (error) {
      showDialog(this.getErrorMessage(error))
    }
  }

  private async testAllInOne(): Promise<void> {
    try {
      const db = await this.getDb()
      const logs: string[] = []

      db.executeSql(`
        create table if not exists ${this.tableName} (
          id integer primary key autoincrement,
          age integer,
          name text,
          dou double,
          bool integer
        )
      `)
      logs.push('1. 建表完成')

      const clearCount = db.delete()
      logs.push(`2. 清空完成，删除 ${clearCount} 条`)

      const first = this.createEmployee('Tom', 24, 88.5, true)
      first.other = '不会入库'
      const firstRowId = db.insert(first)
      logs.push(`3. 单条插入完成，rowId=${firstRowId}`)

      const batchCount = db.batchInsert([
        this.createEmployee('Lucy', 28, 91.2, true),
        this.createEmployee('Jack', 31, 75.6, false)
      ])
      logs.push(`4. 批量插入完成，count=${batchCount}`)

      const beforeUpdate = db.select(new Wrapper().orderByDesc('id'))
      logs.push(`5. 初次查询完成，count=${beforeUpdate.length}`)

      const updateCount = db.update(
        new Wrapper()
          .set('name', 'Updated By Wrapper')
          .set('dou', 99.9)
          .eq('name', 'Tom')
      )
      logs.push(`6. 条件更新完成，影响 ${updateCount} 条`)

      const latestList = db.select(new Wrapper().orderByDesc('id').limit(1))
      if (latestList.length > 0) {
        const employee = latestList[0]
        employee.name = 'Updated By Id'
        employee.age = (employee.age ?? 0) + 1
        const updateByIdCount = db.updateById(employee)
        logs.push(`7. 主键更新完成，影响 ${updateByIdCount} 条，id=${employee.id}`)
      } else {
        logs.push('7. 主键更新跳过，没有可更新数据')
      }

      const deleteTarget = db.select(new Wrapper().orderByDesc('id').limit(1))
      if (deleteTarget.length > 0 && deleteTarget[0].id !== undefined) {
        const deleteCount = db.deleteById(deleteTarget[0].id!)
        logs.push(`8. 主键删除完成，影响 ${deleteCount} 条，id=${deleteTarget[0].id}`)
      } else {
        logs.push('8. 主键删除跳过，没有可删除数据')
      }

      const finalList = db.select(new Wrapper().orderByDesc('id'))
      const finalTotal = db.count()
      logs.push(`9. 最终查询完成，总数=${finalTotal}`)
      logs.push(JSON.stringify(finalList, null, 2))

      showDialog(logs.join('\n'))
    } catch (error) {
      showDialog(this.getErrorMessage(error))
    }
  }

  @Builder
  private buildActionButton(label: string, background: string, action: () => Promise<void>) {
    Button(label)
      .width('100%')
      .height(48)
      .fontSize(16)
      .fontWeight(FontWeight.Medium)
      .fontColor(Color.White)
      .backgroundColor(background)
      .borderRadius(14)
      .onClick(async () => {
        await action()
      })
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      Scroll() {
        Column({ space: 18 }) {
          Column({ space: 10 }) {
            Text('RdbOrm 操作面板')
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor('#182431')
            Text('将常用数据库操作集中到更清晰的卡片视图中，测试、增删改查一目了然。')
              .fontSize(14)
              .lineHeight(22)
              .fontColor('#5B6570')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          Column({ space: 12 }) {
            Text('推荐操作')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#182431')
              .width('100%')

            this.buildActionButton('一键测试', '#2B6AF3', async () => {
              await this.testAllInOne()
            })

            this.buildActionButton('建表', '#36A269', async () => {
              await this.testCreateTable()
            })

            this.buildActionButton('清空表', '#F39C12', async () => {
              await this.testClearTable()
            })
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FDFDFD')
          .borderRadius(24)

          Column({ space: 12 }) {
            Text('数据操作')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#182431')
              .width('100%')

            this.buildActionButton('单条插入', '#4E7CF0', async () => {
              await this.testInsert()
            })

            this.buildActionButton('批量插入', '#5B8FF9', async () => {
              await this.testBatchInsert()
            })

            this.buildActionButton('查询统计', '#2AA899', async () => {
              await this.testSelect()
            })

            this.buildActionButton('条件更新', '#8E6AF5', async () => {
              await this.testUpdate()
            })

            this.buildActionButton('主键更新', '#7C5CFA', async () => {
              await this.testUpdateById()
            })

            this.buildActionButton('主键删除', '#E86A5F', async () => {
              await this.testDeleteById()
            })
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FDFDFD')
          .borderRadius(24)
        }
        .width('100%')
        .padding({
          left: 20,
          right: 20,
          top: 28,
          bottom: 110
        })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')

      Button('删除数据库表')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .backgroundColor('#D9485F')
        .borderRadius(20)
        .padding({
          left: 18,
          right: 18,
          top: 12,
          bottom: 12
        })
        .margin({ right: 20, bottom: 24 })
        .align(Alignment.BottomEnd)
        .onClick(async () => {
          await this.testDropTable()
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F6FB')
  }
}
