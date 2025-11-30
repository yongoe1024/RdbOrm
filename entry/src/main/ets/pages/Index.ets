import { Employee } from '../model/Employee'
import { relationalStore } from '@kit.ArkData'
import { showDialog } from '../util/MessageDialog'
import { RdbOrm } from '@dims/rdborm'

@Entry
@Component
struct Index {
  orm?: RdbOrm<Employee>

  aboutToAppear(): void {
    RdbOrm.debugSql = true
    this.orm = RdbOrm.build({
      context: getContext(),
      class: Employee,
      config: {
        name: 'RdbTest.db',
        securityLevel: relationalStore.SecurityLevel.S3, // 数据库安全级别
      },
    })
  }

  build() {
    Flex({ wrap: FlexWrap.Wrap }) {
      Button('建表').onClick((event: ClickEvent) => {
        this.orm?.start(db => {
          let a = db.executeSql(`
          create table if not exists t_emp (
                    id  integer primary key autoincrement,
                    age INTEGER,
                    name text,
                    dou DOUBLE,
                    bool INTEGER
          )`)
          showDialog(JSON.stringify(a, null, 2))
        })
      })
      Button('删表').onClick((event: ClickEvent) => {
        this.orm?.start(db => {
          let a = db.executeSql(`DROP TABLE t_emp`)
          showDialog(JSON.stringify(a, null, 2))
        })
      })
      Button('save a、b').onClick((event: ClickEvent) => {
        this.orm?.start(db => {
          let a = db.batchInsert([
            {
              age: 10,
              name: 'a',
              dou: 1.134,
              bool: false,
              other: 'other'
            },
            {
              age: 11,
              name: 'b',
              dou: 2.134,
              bool: true,
              other: 'other'
            }
          ])
          showDialog(JSON.stringify(a, null, 2))
        })
      })
      Button('getAll').onClick((event: ClickEvent) => {
        this.orm?.start(db => {
          let empList = db.select()
          showDialog(JSON.stringify(empList, null, 2))
        })
      })
      // Button('update name=a').onClick((event: ClickEvent) => {
      //   this.orm?.start(db => {
      //     let a = db.update({
      //       age: 100,
      //       name: '修改',
      //       dou: 1.134,
      //       bool: true,
      //       other: 'otherxxx'
      //     }, item => item.equalTo('name', 'a'))
      //     showDialog(JSON.stringify(a, null, 2))
      //   })
      // })
      Button('delete name=b').onClick((event: ClickEvent) => {
        this.orm?.start(async (db) => {
          let a = db.delete(item => {
            item.equalTo('name', 'b')
          })
          showDialog(JSON.stringify(a, null, 2))
        })
      })
      Button('deleteAll').onClick((event: ClickEvent) => {
        this.orm?.start(db => {
          let a = db.delete()
          showDialog(JSON.stringify(a, null, 2))
        })
      })
    }
    .height('100%')
    .width('100%')
  }
}