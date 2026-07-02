import { Employee } from '../model/Employee'
import { relationalStore } from '@kit.ArkData'
import { showDialog } from '../util/MessageDialog'
import { RdbOrm } from '@dims/rdborm'
import {
  testAllInOne,
  testBatchInsert,
  testClearTable,
  testCreateTable,
  testDeleteById,
  testDropTable,
  testInsert,
  testBoolReadConvert,
  testSelect,
  testSelectOne,
  testTaskpoolInsert,
  testTaskpoolQuery,
  testTransactionInsert,
  testUpdate,
  testUpdateById,
} from './IndexActions'
import router from '@ohos.router'

const DATABASE_NAME: string = 'RdbTest.db'

@Entry
@Component
struct Index {
  orm?: RdbOrm<Employee>

  aboutToAppear(): void {
    try {
      this.orm = RdbOrm.build({
        context: getContext(),
        class: Employee,
        config: {
          name: DATABASE_NAME,
          securityLevel: relationalStore.SecurityLevel.S3, // 数据库安全级别
        },
        debugSql: true,
      })
    } catch (error) {
      showDialog(`初始化失败：${error instanceof Error ? error.message : String(error)}`)
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
      .onClick(() => {
        action()
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
            Text('装饰器自动建表 + 链式条件 + 事务封装，零 SQL 完成 CRUD。')
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
              await testAllInOne(this.orm)
            })

            this.buildActionButton('自动建表', '#36A269', async () => {
              await testCreateTable(this.orm)
            })

            this.buildActionButton('清空表', '#F39C12', async () => {
              await testClearTable(this.orm)
            })
          }
          .width('100%')
          .padding(20)
          .backgroundColor('#FDFDFD')
          .borderRadius(24)

          Column({ space: 12 }) {
            Text('压力测试')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#182431')
              .width('100%')

            this.buildActionButton('进入压力测试页', '#9B51E0', async () => {
              router.pushUrl({ url: 'pages/StressTest' })
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
              await testInsert(this.orm)
            })

            this.buildActionButton('批量插入', '#5B8FF9', async () => {
              await testBatchInsert(this.orm)
            })

            this.buildActionButton('事务插入', '#1F78B4', async () => {
              await testTransactionInsert(this.orm)
            })

            this.buildActionButton('查询统计', '#2AA899', async () => {
              await testSelect(this.orm)
            })

            this.buildActionButton('查询单条', '#0E9384', async () => {
              await testSelectOne(this.orm)
            })

            this.buildActionButton('Bool 读取转换验证', '#16A085', async () => {
              await testBoolReadConvert(this.orm)
            })

            this.buildActionButton('TaskPool 插入', '#1B5FA0', async () => {
              await testTaskpoolInsert()
            })

            this.buildActionButton('TaskPool 查询', '#157C72', async () => {
              await testTaskpoolQuery()
            })

            this.buildActionButton('条件更新', '#8E6AF5', async () => {
              await testUpdate(this.orm)
            })

            this.buildActionButton('主键更新', '#7C5CFA', async () => {
              await testUpdateById(this.orm)
            })

            this.buildActionButton('主键删除', '#E86A5F', async () => {
              await testDeleteById(this.orm)
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
          await testDropTable(this.orm)
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F3F6FB')
  }
}
