import { Employee } from '../model/Employee'
import { relationalStore } from '@kit.ArkData'
import { RdbOrm, Wrapper } from '@dims/rdborm'
import taskpool from '@ohos.taskpool'
import router from '@ohos.router'
import emitter from '@ohos.events.emitter'

/**
 * 压力测试页：ORM vs 原生 relationalStore
 *
 * 两个 @Concurrent worker 按顺序执行（先 ORM，再原生），共用同一个数据库 / 同一张 t_emp 表：
 *   - ormWorker：走 ORM（db.insert / db.select）
 *   - nativeWorker：走原生 relationalStore（store.insertSync / store.querySqlSync）
 *
 * 公平性说明：
 *   - 顺序执行、不并行；每次执行前先清空 t_emp，保证两条路径起点一致
 *   - 插入均在单事务内完成，抹平 fsync 代价，纯粹对比 ORM 的 bucket 装配开销
 *   - 查询直接跑在插入的数据上，用 QUERY_BASE_ROWS 作 LIMIT 控制返回行数，做 N 次
 *   - ORM 关闭 debugSql，避免 hilog 逐条打印污染基准
 */

const INSERT_SIZES: number[] = [1, 20000, 40000, 60000, 80000]
const QUERY_ITERS: number[] = [1, 200, 400, 600, 800]
const QUERY_BASE_ROWS: number = 1000
/** worker → UI 进度上报的事件 ID（两个 worker 共用） */
const PROGRESS_EVENT_ID: number = 9527
/** 总步数 = 两个 worker × (插入档数 + 查询档数) */
const TOTAL_STEPS: number = (INSERT_SIZES.length + QUERY_ITERS.length) * 2

/** 单个 worker 的结果。error 非空表示失败（此时数组为空） */
export interface WorkerResult {
  insertMs: number[]
  queryMs: number[]
  error: string
}

/** 两个 worker 执行结果的合并快照 */
export interface StressTestSnapshot {
  orm: WorkerResult
  native: WorkerResult
}

// ---------- ORM worker ----------

@Concurrent
async function ormWorker(
  context: Context,
  insertSizes: number[],
  queryIters: number[],
  queryBaseRows: number,
  startProgress: number,
  progressEventId: number,
): Promise<WorkerResult> {
  try {
    const orm = RdbOrm.build({
      context: context,
      class: Employee,
      config: {
        name: 'StressTest.db',
        securityLevel: relationalStore.SecurityLevel.S3,
      },
      debugSql: false,
    })
    const db = await orm.getDBHelper()
    db.createTable()
    // 每次执行前清空表
    db.clear()

    // 预生成最大数据量所需的源数据（50000）
    const maxRows: number = insertSizes[insertSizes.length - 1]
    const names: string[] = []
    const ages: number[] = []
    const dous: number[] = []
    const bools: boolean[] = []
    for (let i = 0; i < maxRows; i++) {
      names.push(`user_${i}`)
      ages.push(18 + (i % 50))
      dous.push(1.5 + (i % 100) * 0.1)
      bools.push(i % 2 === 0)
    }

    // ---------- 插入测试：每个数据量 ----------
    const insertMs: number[] = []
    for (let s = 0; s < insertSizes.length; s++) {
      const n = insertSizes[s]
      db.clear()
      const start = Date.now()
      db.transaction<number>(() => {
        let cnt = 0
        for (let i = 0; i < n; i++) {
          const e = new Employee()
          e.name = names[i]
          e.age = ages[i]
          e.dou = dous[i]
          e.bool = bools[i]
          if (db.insert(e) > 0) {
            cnt++
          }
        }
        return cnt
      })
      insertMs.push(Date.now() - start)
      emitter.emit({ eventId: progressEventId + startProgress + s + 1 })
    }

    // 查询直接跑在插入的数据上（表里现有最后一档插入的数据），用 queryBaseRows 作 LIMIT
    // 预热
    db.select(new Wrapper().gte('age', 18).orderByDesc('id').limit(queryBaseRows))

    // ---------- 查询测试：每个迭代次数 ----------
    const queryMs: number[] = []
    for (let q = 0; q < queryIters.length; q++) {
      const iters = queryIters[q]
      const start = Date.now()
      for (let i = 0; i < iters; i++) {
        db.select(new Wrapper().gte('age', 18).orderByDesc('id').limit(queryBaseRows))
      }
      queryMs.push(Date.now() - start)
      emitter.emit({ eventId: progressEventId + startProgress + insertSizes.length + q + 1 })
    }

    return { insertMs, queryMs, error: '' }
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error)
    return { insertMs: [], queryMs: [], error: msg }
  }
}

// ---------- 原生 worker ----------

@Concurrent
async function nativeWorker(
  context: Context,
  insertSizes: number[],
  queryIters: number[],
  queryBaseRows: number,
  startProgress: number,
  progressEventId: number,
): Promise<WorkerResult> {
  try {
    const store = await relationalStore.getRdbStore(context, {
      name: 'StressTest.db',
      securityLevel: relationalStore.SecurityLevel.S3,
    })
    const createSql: string =
      'CREATE TABLE IF NOT EXISTS t_emp (id INTEGER PRIMARY KEY AUTOINCREMENT, age INTEGER, name TEXT, dou REAL, bool INTEGER)'
    const querySql: string = 'SELECT * FROM t_emp WHERE age >= ? ORDER BY id DESC LIMIT ?'
    store.executeSync(createSql)
    // 每次执行前清空表
    store.executeSync('DELETE FROM t_emp')

    const maxRows: number = insertSizes[insertSizes.length - 1]
    const names: string[] = []
    const ages: number[] = []
    const dous: number[] = []
    const bools: boolean[] = []
    for (let i = 0; i < maxRows; i++) {
      names.push(`user_${i}`)
      ages.push(18 + (i % 50))
      dous.push(1.5 + (i % 100) * 0.1)
      bools.push(i % 2 === 0)
    }
    const queryArgs: Array<relationalStore.ValueType> = [18, queryBaseRows]

    // ---------- 插入测试：每个数据量 ----------
    const insertMs: number[] = []
    for (let s = 0; s < insertSizes.length; s++) {
      const n = insertSizes[s]
      store.executeSync('DELETE FROM t_emp')
      const start = Date.now()
      store.beginTransaction()
      try {
        for (let i = 0; i < n; i++) {
          const bucket: relationalStore.ValuesBucket = {}
          bucket['name'] = names[i]
          bucket['age'] = ages[i]
          bucket['dou'] = dous[i]
          bucket['bool'] = bools[i]
          store.insertSync('t_emp', bucket)
        }
        store.commit()
      } catch (e) {
        store.rollBack()
        throw e as Error
      }
      insertMs.push(Date.now() - start)
      emitter.emit({ eventId: progressEventId + startProgress + s + 1 })
    }

    // 查询直接跑在插入的数据上（表里现有最后一档插入的数据），用 queryBaseRows 作 LIMIT
    // 预热
    const warmRs = store.querySqlSync(querySql, queryArgs)
    try {
      while (warmRs.goToNextRow()) {
        warmRs.getRow()
      }
    } finally {
      warmRs.close()
    }

    // ---------- 查询测试：每个迭代次数 ----------
    const queryMs: number[] = []
    for (let q = 0; q < queryIters.length; q++) {
      const iters = queryIters[q]
      const start = Date.now()
      for (let i = 0; i < iters; i++) {
        const rs = store.querySqlSync(querySql, queryArgs)
        try {
          while (rs.goToNextRow()) {
            rs.getRow()
          }
        } finally {
          rs.close()
        }
      }
      queryMs.push(Date.now() - start)
      emitter.emit({ eventId: progressEventId + startProgress + insertSizes.length + q + 1 })
    }

    return { insertMs, queryMs, error: '' }
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error)
    return { insertMs: [], queryMs: [], error: msg }
  }
}

// ---------- 对外入口（UI 线程调用，顺序起两个 worker） ----------

export async function runStressTest(): Promise<StressTestSnapshot> {
  // 按顺序执行：先 ORM，完成后再原生（不并行）
  // startProgress 让两个 worker 的进度计数拼成连续的 1..TOTAL_STEPS
  const halfSteps: number = INSERT_SIZES.length + QUERY_ITERS.length
  const ormRaw = await taskpool.execute(ormWorker, getContext(), INSERT_SIZES, QUERY_ITERS, QUERY_BASE_ROWS, 0, PROGRESS_EVENT_ID)
  const nativeRaw = await taskpool.execute(nativeWorker, getContext(), INSERT_SIZES, QUERY_ITERS, QUERY_BASE_ROWS, halfSteps, PROGRESS_EVENT_ID)
  return {
    orm: ormRaw as ESObject as WorkerResult,
    native: nativeRaw as ESObject as WorkerResult,
  }
}

// ---------- 页面 ----------

@Entry
@Component
struct StressTest {
  @State running: boolean = false
  @State done: boolean = false
  @State errorMsg: string = ''
  @State progressCount: number = 0
  @State ormResult: WorkerResult = { insertMs: [], queryMs: [], error: '' }
  @State nativeResult: WorkerResult = { insertMs: [], queryMs: [], error: '' }

  aboutToAppear(): void {
    // 每一步对应一个 eventId（PROGRESS_EVENT_ID + step），worker 跑完一步就 emit 对应的 eventId
    for (let step = 1; step <= TOTAL_STEPS; step++) {
      const s = step
      emitter.on({ eventId: PROGRESS_EVENT_ID + s }, () => {
        this.progressCount = s
      })
    }
  }

  aboutToDisappear(): void {
    for (let step = 1; step <= TOTAL_STEPS; step++) {
      emitter.off(PROGRESS_EVENT_ID + step)
    }
  }

  async start(): Promise<void> {
    this.running = true
    this.errorMsg = ''
    this.progressCount = 0
    try {
      const r = await runStressTest()
      this.ormResult = r.orm
      this.nativeResult = r.native
      this.done = true
      if (r.orm.error.length > 0) {
        this.errorMsg = `ORM worker 失败：${r.orm.error}`
      } else if (r.native.error.length > 0) {
        this.errorMsg = `原生 worker 失败：${r.native.error}`
      }
    } catch (e) {
      this.errorMsg = e instanceof Error ? e.message : String(e)
    } finally {
      this.running = false
    }
  }

  /** 差距（毫秒）：ORM - 原生；正数=ORM 更慢，负数=更快 */
  private diffMs(ormMs: number, nativeMs: number): string {
    const diff = ormMs - nativeMs
    const sign = diff >= 0 ? '+' : ''
    return `${sign}${diff} ms`
  }

  @Builder
  private cell(text: string, w: string, bold: boolean) {
    Text(text)
      .width(w)
      .fontSize(13)
      .fontWeight(bold ? FontWeight.Bold : FontWeight.Normal)
      .fontColor('#182431')
      .textAlign(TextAlign.Center)
      .padding({ top: 9, bottom: 9 })
  }

  build() {
    Column({ space: 14 }) {
      Row() {
        Text('〈 返回')
          .fontSize(16)
          .fontColor('#2B6AF3')
          .onClick(() => router.back())
        Text('压力测试')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#182431')
          .margin({ left: 8 })
      }
      .width('100%')

      Text('ORM 与原生各起一个 TaskPool worker 顺序执行（共用同一数据库，每次执行前清空表）；插入均在单事务内完成。')
        .fontSize(12)
        .fontColor('#5B6570')
        .lineHeight(18)
        .width('100%')

      Button(this.running ? '测试中…' : '运行测试')
        .width('100%')
        .height(46)
        .fontSize(16)
        .fontColor(Color.White)
        .backgroundColor('#9B51E0')
        .borderRadius(12)
        .enabled(!this.running)
        .onClick(() => {
          this.start()
        })

      Scroll() {
        Column({ space: 18 }) {
          if (this.running) {
            Column({ space: 8 }) {
              Progress({ value: this.progressCount, total: TOTAL_STEPS, type: ProgressType.Linear })
                .width('100%')
                .color('#9B51E0')
                .backgroundColor('#EEF1F5')
                .borderRadius(6)
              Text(`${(this.progressCount / TOTAL_STEPS * 100).toFixed(0)}% （${this.progressCount}/${TOTAL_STEPS}）`)
                .fontSize(13)
                .fontColor('#5B6570')
                .width('100%')
              Text('顺序执行中…（插入 + 查询，请稍候）')
                .fontSize(12)
                .fontColor('#8A929C')
                .width('100%')
            }
          } else if (this.errorMsg.length > 0) {
            Text(`失败：${this.errorMsg}`)
              .fontSize(14)
              .fontColor('#D9485F')
              .width('100%')
          } else if (this.done) {
            // ---------- 插入表 ----------
            Column({ space: 8 }) {
              Text('插入（事务批量，单位 ms）')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#182431')
                .width('100%')
              Column() {
                Row() {
                  this.cell('数据量', '28%', true)
                  this.cell('ORM', '24%', true)
                  this.cell('原生', '24%', true)
                  this.cell('差距', '24%', true)
                }
                .width('100%')
                .backgroundColor('#EEF1F5')
                ForEach(INSERT_SIZES, (size: number, i: number) => {
                  Row() {
                    this.cell(`${size}`, '28%', false)
                    this.cell(`${this.ormResult.insertMs[i]}`, '24%', false)
                    this.cell(`${this.nativeResult.insertMs[i]}`, '24%', false)
                    this.cell(this.diffMs(this.ormResult.insertMs[i], this.nativeResult.insertMs[i]), '24%', false)
                  }
                  .width('100%')
                  .backgroundColor(i % 2 === 0 ? '#FFFFFF' : '#F7F9FB')
                }, (size: number) => `ins_${size}`)
              }
              .width('100%')
              .borderRadius(10)
              .clip(true)
              .borderWidth(1)
              .borderColor('#E5E8EC')
            }

            // ---------- 查询表 ----------
            Column({ space: 8 }) {
              Text(`查询（在插入的数据上，WHERE+ORDER BY+LIMIT ${QUERY_BASE_ROWS}，单位 ms）`)
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#182431')
                .width('100%')
              Column() {
                Row() {
                  this.cell('次数', '28%', true)
                  this.cell('ORM', '24%', true)
                  this.cell('原生', '24%', true)
                  this.cell('差距', '24%', true)
                }
                .width('100%')
                .backgroundColor('#EEF1F5')
                ForEach(QUERY_ITERS, (iters: number, i: number) => {
                  Row() {
                    this.cell(`${iters}`, '28%', false)
                    this.cell(`${this.ormResult.queryMs[i]}`, '24%', false)
                    this.cell(`${this.nativeResult.queryMs[i]}`, '24%', false)
                    this.cell(this.diffMs(this.ormResult.queryMs[i], this.nativeResult.queryMs[i]), '24%', false)
                  }
                  .width('100%')
                  .backgroundColor(i % 2 === 0 ? '#FFFFFF' : '#F7F9FB')
                }, (iters: number) => `q_${iters}`)
              }
              .width('100%')
              .borderRadius(10)
              .clip(true)
              .borderWidth(1)
              .borderColor('#E5E8EC')
            }

            Text('差距 = ORM - 原生（毫秒）；正数表示 ORM 更慢，负数表示更快。')
              .fontSize(11)
              .fontColor('#8A929C')
              .width('100%')
          } else {
            Text('点击「运行测试」开始')
              .fontSize(14)
              .fontColor('#5B6570')
              .width('100%')
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#F3F6FB')
  }
}
