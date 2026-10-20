import { router } from '@kit.ArkUI';
import { findWord } from '../data/WordData';
import { Store } from '../store/Store';
import { Theme } from '../common/Theme';
import { Word } from '../model/WordModel';

// 日历格子：day 为 0 表示空白占位
interface DayCell {
  day: number;
  key: string;
}

interface MeaningPart {
  pos: string;
  text: string;
}

const WEEKDAYS: string[] = ['日', '一', '二', '三', '四', '五', '六'];

// 拆分释义中的词性与释义，如 "v. 放弃，抛弃" -> "v." + "放弃，抛弃"
function splitMeaning(raw: string): MeaningPart {
  let i = 0;
  let lastDot = -1;
  while (i < raw.length) {
    const ch = raw.charAt(i);
    const isLetter = (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
    if (isLetter || ch === '.' || ch === '/') {
      if (ch === '.') {
        lastDot = i;
      }
      i += 1;
    } else {
      break;
    }
  }
  if (lastDot > 0) {
    const part: MeaningPart = {
      pos: raw.substring(0, lastDot + 1),
      text: raw.substring(i).trim()
    };
    return part;
  }
  const fallback: MeaningPart = { pos: '', text: raw };
  return fallback;
}

// 学习日历：日历视图 + 选中日期当天所学单词列表
@Entry
@Component
struct CalendarPage {
  @State year: number = 2026;
  @State month: number = 1;
  @State cells: DayCell[] = [];
  @State selectedKey: string = '';
  @State selectedWords: Word[] = [];
  @State learnedDays: number = 0;
  // 深色模式开关：双向绑定 AppStorage，切换后页面配色同步刷新
  @StorageLink('darkMode') isDark: boolean = false;
  private store: Store = Store.get();

  aboutToAppear(): void {
    const now = new Date();
    this.year = now.getFullYear();
    this.month = now.getMonth() + 1;
    this.learnedDays = this.store.learnedDays;
    this.rebuildCalendar();
    // 默认选中今天
    this.selectDate(this.keyOf(this.year, this.month, now.getDate()));
  }

  // 生成与 Store.today() 一致的 YYYY-M-D 键（无补零）
  private keyOf(y: number, m: number, d: number): string {
    return `${y}-${m}-${d}`;
  }

  // 重建当前月份的日历格子：开头补空白，只含当月日期
  private rebuildCalendar(): void {
    const firstWeekday = new Date(this.year, this.month - 1, 1).getDay();
    const daysInMonth = new Date(this.year, this.month, 0).getDate();
    const cells: DayCell[] = [];
    for (let i = 0; i < firstWeekday; i++) {
      const blank: DayCell = { day: 0, key: '' };
      cells.push(blank);
    }
    for (let d = 1; d <= daysInMonth; d++) {
      const cell: DayCell = { day: d, key: this.keyOf(this.year, this.month, d) };
      cells.push(cell);
    }
    this.cells = cells;
  }

  private prevMonth(): void {
    this.month -= 1;
    if (this.month < 1) {
      this.month = 12;
      this.year -= 1;
    }
    this.rebuildCalendar();
  }

  private nextMonth(): void {
    this.month += 1;
    if (this.month > 12) {
      this.month = 1;
      this.year += 1;
    }
    this.rebuildCalendar();
  }

  // 取第 idx 个格子，越界返回空白格
  private cellAt(idx: number): DayCell {
    if (idx < this.cells.length) {
      return this.cells[idx];
    }
    const blank: DayCell = { day: 0, key: '' };
    return blank;
  }

  // 该日期是否有学习记录
  private hasRecord(key: string): boolean {
    if (key === '') {
      return false;
    }
    const list = this.store.learnedLog[key];
    return list !== undefined && list.length > 0;
  }

  private isToday(key: string): boolean {
    const now = new Date();
    return key === this.keyOf(now.getFullYear(), now.getMonth() + 1, now.getDate());
  }

  // 选中日期并加载当天所学单词
  private selectDate(key: string): void {
    if (key === '') {
      return;
    }
    this.selectedKey = key;
    const ids = this.store.learnedLog[key] ?? [];
    const words: Word[] = [];
    for (let i = 0; i < ids.length; i++) {
      const w = findWord(ids[i]);
      if (w) {
        words.push(w);
      }
    }
    this.selectedWords = words;
  }

  // 选中日期的中文标签，如 "10月5日"
  private selectedLabel(): string {
    const parts = this.selectedKey.split('-');
    if (parts.length === 3) {
      return `${Number(parts[1])}月${Number(parts[2])}日`;
    }
    return '';
  }

  // 单个日期格：选中高亮、今天描边、有学习记录显示圆点
  @Builder
  DayCellView(idx: number) {
    Column() {
      Text(this.cellAt(idx).day > 0 ? `${this.cellAt(idx).day}` : ' ')
        .width(34)
        .height(34)
        .textAlign(TextAlign.Center)
        .fontSize(14)
        .fontColor(this.selectedKey === this.cellAt(idx).key ? Color.White :
          (this.isToday(this.cellAt(idx).key) ? Theme.accent(this.isDark) : Theme.inkSecondary(this.isDark)))
        .backgroundColor(this.selectedKey === this.cellAt(idx).key ? Theme.accent(this.isDark) : Color.Transparent)
        .borderRadius(17)
      if (this.cellAt(idx).day > 0) {
        if (this.hasRecord(this.cellAt(idx).key)) {
          Circle({ width: 4, height: 4 })
            .fill(this.selectedKey === this.cellAt(idx).key ? Color.White : Theme.accent(this.isDark))
            .margin({ top: 3 })
        } else {
          Circle({ width: 4, height: 4 })
            .fill(Color.Transparent)
            .margin({ top: 3 })
        }
      }
    }
    .layoutWeight(1)
    .height(48)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.selectDate(this.cellAt(idx).key);
    })
  }

  // 日历的一行（7 列）
  @Builder
  DayRow(row: number) {
    Row() {
      ForEach([0, 1, 2, 3, 4, 5, 6], (col: number) => {
        this.DayCellView(row * 7 + col)
      }, (col: number) => `${row}-${col}`)
    }
    .width('100%')
  }

  // 单词卡片：单词 + 音标 + 词性胶囊 + 释义
  @Builder
  WordCard(word: Word) {
    Column() {
      Row() {
        Text(word.word)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.ink(this.isDark))
        Text(word.phonetic)
          .fontSize(12)
          .fontColor(Theme.inkSecondary(this.isDark))
          .margin({ left: 8 })
        Blank()
        if (splitMeaning(word.meaning).pos !== '') {
          Text(splitMeaning(word.meaning).pos)
            .fontSize(11)
            .fontColor(Theme.accent(this.isDark))
            .backgroundColor(Theme.accentSoft(this.isDark))
            .borderRadius(8)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
        }
      }
      .width('100%')
      Text(splitMeaning(word.meaning).text)
        .fontSize(13)
        .fontColor(Theme.inkSecondary(this.isDark))
        .width('100%')
        .margin({ top: 6 })
    }
    .alignItems(HorizontalAlign.Start)
    // 与首页一致的玻璃质感：半透明底 + 背景模糊 + 高光描边 + 悬空阴影
    .backgroundColor(Theme.glass(this.isDark))
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Theme.glassBorder(this.isDark) })
    .borderRadius(16)
    .shadow({ radius: 12, color: 'rgba(27,30,40,0.12)', offsetX: 0, offsetY: 6 })
    .padding(16)
    .width('100%')
    .margin({ top: 10 })
  }

  build() {
    Stack() {
      // 背景：顶部三分之一为欢迎页同款渐变（#0077ff → #000000，52°），下方三分之二为纯白（深色下为深灰）
      Column() {
        Column()
          .width('100%')
          .height('33.3%')
          .linearGradient({
            angle: 52,
            colors: [['#0077ff', 0.0], ['#000000', 1.0]]
          })
        Column()
          .width('100%')
          .layoutWeight(1)
          .backgroundColor(Theme.surface(this.isDark))
      }
      .width('100%')
      .height('100%')

      Column() {
        // 头部：返回 + 月份标题居中 + 右侧翻月按钮（白色圆形小按钮，参考头栏样式）
        Row() {
          Column() {
            SymbolGlyph($r('sys.symbol.chevron_left'))
              .fontSize(20)
              .fontColor([Color.White])
          }
          .width(40)
          .height(40)
          .borderRadius(20)
          .justifyContent(FlexAlign.Center)
          .onClick(() => {
            router.back();
          })
          Text(`${this.year}年${this.month}月`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .margin({ left: 4 })
          Blank()
          Row({ space: 8 }) {
            Column() {
              SymbolGlyph($r('sys.symbol.chevron_left'))
                .fontSize(16)
                .fontColor([Theme.ink(this.isDark)])
            }
            .width(32)
            .height(32)
            .borderRadius(16)
            .backgroundColor(Theme.glass(this.isDark))
            .border({ width: 1, color: Theme.glassBorder(this.isDark) })
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.prevMonth();
            })
            Column() {
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(16)
                .fontColor([Theme.ink(this.isDark)])
            }
            .width(32)
            .height(32)
            .borderRadius(16)
            .backgroundColor(Theme.glass(this.isDark))
            .border({ width: 1, color: Theme.glassBorder(this.isDark) })
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              this.nextMonth();
            })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 12 })

        // 日历卡片：星期表头 + 日期网格，纯白背景 + 阴影（左右留空展示背景；深色下为深灰卡片）
        Column() {
          // 星期表头
          Row() {
            ForEach(WEEKDAYS, (d: string) => {
              Text(d)
                .fontSize(12)
                .fontColor(Theme.inkTertiary(this.isDark))
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
            }, (d: string) => d)
          }
          .width('100%')
          .margin({ top: 10 })

          // 日历主体
          Column() {
            ForEach([0, 1, 2, 3, 4, 5], (row: number) => {
              this.DayRow(row)
            }, (row: number) => `${row}`)
          }
          .width('100%')
          .margin({ bottom: 10 })
        }
        .width('90%')
        // 玻璃日历卡：渐变背景上的半透明玻璃，模糊透出背景色
        .backgroundColor(Theme.glass(this.isDark))
        .backgroundBlurStyle(BlurStyle.Thin)
        .border({ width: 1, color: Theme.glassBorder(this.isDark) })
        .borderRadius(20)
        .shadow({ radius: 16, color: 'rgba(27, 30, 40, 0.1)', offsetY: 4 })
        .margin({ left: 24, right: 24, top: 16 })



      // 选中日期标题与坚持天数：左侧日期信息，右侧靠右展示坚持天数
      Row() {
        Text(`${this.selectedLabel()} · 学了 ${this.selectedWords.length} 个单词`)
          .fontSize(14)
          .fontColor(Theme.inkSecondary(this.isDark))
          .layoutWeight(1)
        Row() {
          SymbolGlyph($r('sys.symbol.flame'))
            .fontSize(15)
            .fontColor([Theme.accent(this.isDark)])
          Text(`${this.learnedDays}`)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.accent(this.isDark))
            .margin({ left: 6 })
          Text('天')
            .fontSize(12)
            .fontColor(Theme.inkSecondary(this.isDark))
        }
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 12 })

      // 当天所学单词列表
      Scroll() {
        Column() {
          if (this.selectedWords.length === 0) {
            Column() {
              SymbolGlyph($r('sys.symbol.calendar'))
                .fontSize(40)
                .fontColor([Theme.inkTertiary(this.isDark)])
              Text('这一天还没有学习记录')
                .fontSize(13)
                .fontColor(Theme.inkSecondary(this.isDark))
                .margin({ top: 10 })
              Text('日历中带圆点的日期有学习记录，点击看看吧')
                .fontSize(12)
                .fontColor(Theme.inkTertiary(this.isDark))
                .margin({ top: 4 })
            }
            .width('100%')
            .padding({ top: 36 })
          } else {
            ForEach(this.selectedWords, (word: Word) => {
              this.WordCard(word)
            }, (word: Word) => word.id)
          }
        }
        .padding({ left: 24, right: 24, bottom: 24 })
        .width('100%')
      }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .margin({ top: 4 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
