# 10 · App 错词本与间隔复习

> 背景：用户要求“先改 APP，把 APP 功能完善”（2026-11-16）。此前 App 只有「学词（滑卡）」和「选择题复习」两种模式，答错的词只会被标记为“学习中”，没有错词本、也没有按遗忘曲线的复习计划。本轮补上这两块，并打通跨设备同步。

## 1. 功能定义

| 功能 | 行为 |
| --- | --- |
| 错词本 | 学词/选择题复习中回答“不认识/答错”的词自动进入；列表按最近答错时间倒序，显示累计答错次数、复习等级、所属词书 |
| 间隔复习 | 每个错词有 0–6 级；答对升 1 级，下次复习间隔按 `1 / 2 / 4 / 7 / 15 / 30` 天顺延；升到第 6 级视为真正掌握，自动移出错词本 |
| 答错处理 | 等级清零，次日重新到期；累计答错次数 +1 |
| 今日复习 | 只取“到期日 ≤ 今天”的词，单次最多 30 个；卡片先回忆、点开看释义，再选“认识/不认识” |
| 手动掌握 | 错词本每项右侧“已掌握”，直接把词标为 `STATUS_MASTERED` 并移出错词本 |
| 入口 | 「我的」页“错词本”一行，显示错词数；有到期词时追加“N 个待复习”角标 |

## 2. 数据与算法

`Store.ets` 新增 4 个持久化字段（`PersistData` / `ProgressSnapshot` 同名）：

| 字段 | 类型 | 含义 |
| --- | --- | --- |
| `wrongMap` | `Record<string, string>` | wordId → 最近答错日期 `YYYY-M-D` |
| `wrongCount` | `Record<string, number>` | wordId → 累计答错次数（只增） |
| `reviewLevel` | `Record<string, number>` | wordId → 连续答对等级（0–6） |
| `reviewDue` | `Record<string, string>` | wordId → 下次到期日 |

关键方法（均在 `entry/src/main/ets/store/Store.ets`）：

- `markWrong(wordId)`：私有；`wrongMap=today`、`wrongCount++`、`reviewLevel=0`、`reviewDue=today`。由 `markLearned(wordId,false)` 调用。
- `wrongWordIds()`：错词本列表，过滤已掌握，按 `wrongMap` 倒序、次数降序。
- `dueWordIds()`：到期队列；`dateRank()` 把未补零的 `YYYY-M-D` 转数字比较（**不能直接字符串比较**，`2026-11-6` 会大于 `2026-11-16`），兼容“在错词本但无复习计划”的历史数据。
- `reviewWord(wordId, known)`：返回 `{mastered, level, due}`；答对升级并按 `REVIEW_INTERVALS` 顺延，满 6 级写 `statusMap=STATUS_MASTERED` 并清出错词本；答错回 0 级、次日到期。
- `masterWord(wordId)`：手动掌握。
- `removeWrong(wordId)`：ArkTS 不支持 `delete`，重建 4 个 `Record` 移除键。

## 3. 页面

| 文件 | 说明 |
| --- | --- |
| `entry/src/main/ets/pages/WrongWordsPage.ets` | 错词本：统计卡（错词数 / 今日待复习）、开始复习按钮、列表、“已掌握”按钮、空态 |
| `entry/src/main/ets/pages/ReviewPage.ets` | 今日复习：顶部进度、翻卡看释义、认识/不认识、完成页（认识/不认识/掌握数/剩余到期） |
| `entry/src/main/ets/view/MineView.ets` | “我的”页新增错词本入口，`syncFromStore()` 里算 `wrongTotal()` 与 `dueCount()` |
| `entry/src/main/ets/pages/LearnPage.ets` | 完成页文案改为“答错的词已加入错词本” |
| `entry/src/main/resources/base/profile/main_pages.json` | 注册 `pages/WrongWordsPage`、`pages/ReviewPage` |

页面视觉沿用现有玻璃质感：`Theme.glass` + `backgroundBlurStyle(BlurStyle.Thin)` + `Theme.glassBorder` + 18/24 圆角与悬空阴影。

## 4. 跨端同步

`ProgressSnapshot`（`model/ProgressModel.ets`）新增 4 个可选字段，`toSnapshot()` / `applySnapshot()` 已接入；`CloudSync` 自动带上，不需要改。

后端 `server/src/progress.js`：

1. `sanitizeSnapshot` 增加白名单清洗：`wrongMap`（合法日期）、`wrongCount`（0–100000）、`reviewLevel`（0–20）、`reviewDue`（合法日期），均受 `MAX_WORDS` 限制；
2. `hasMeaningfulData` 把 `wrongMap` 计入；
3. `mergeSnapshots`：`wrongMap`/`reviewDue` 取较晚日期、`wrongCount`/`reviewLevel` 取较大值，避免多设备来回覆盖。

验证（node 直接调用）：

```
sanitized {"wrongMap":{"abandon":"2026-11-16"},"wrongCount":{"abandon":3},"reviewLevel":{"abandon":2},"reviewDue":{"abandon":"2026-11-18"}}
merged    {"wrongMap":{"beta":"2026-11-10","abandon":"2026-11-16"},"wrongCount":{"beta":2,"abandon":3},...}
```

已知取舍：一端“手动掌握”后本地删掉了错词，另一端快照里仍有该词时，合并会把它并回来（下次答对 6 级才会再移除）。错词本属于弱一致数据，可接受；要彻底解决需给每条记录加 `updatedAt` 并做删除墓碑。

## 5. 构建与验证

- 环境：`hvigorw 6.24.5`；`PackageHap` 需要 `java`，本机 PATH 没有 JDK，`JAVA_HOME` 指到带空格的 `C:\Program Files\...` 仍报 `spawn java ENOENT`，最终用 junction 解决：
  `powershell -NoProfile -Command "New-Item -ItemType Junction -Path 'C:\hmsjbr' -Target 'C:\Program Files\Huawei\huawei\DevEco Studio\jbr'"`
  再 `export JAVA_HOME=C:/hmsjbr; export PATH=/c/hmsjbr/bin:$PATH`。
- 命令：`hvigorw assembleHap --mode module -p product=default -p buildMode=debug --no-daemon`
- 结果：`BUILD SUCCESSFUL`，产物 `entry/build/default/outputs/default/entry-default-unsigned.hap`（约 1.4 MB，未签名）。
- 仅剩 `ProfileEditPage` 的 `showToast`/`router.back` deprecated 警告，与本次改动无关。
- 尚未真机验证：`hdc list targets` 为空，没有连接设备/模拟器；翻卡、复习间隔、跨天到期需要在设备上回归。

## 6. 后续可做

1. 首页/学习页增加“今日到期 N 词”直达入口（目前只在「我的」里）；
2. 复习结果记录 `lastReviewedAt`，做“连续答对 X 次”成就；
3. 升级 FSRS：按每个词的难度/稳定性动态算间隔，替代固定 `1/2/4/7/15/30`；
4. 错词本支持按词书筛选、批量移除、发音；
5. 删除墓碑/`updatedAt`，解决上面提到的多端“复活”问题。