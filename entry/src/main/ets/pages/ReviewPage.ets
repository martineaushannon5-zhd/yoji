import { router } from '@kit.ArkUI';
import { BOOKS } from '../data/WordData';
import { Store } from '../store/Store';
import { Theme } from '../common/Theme';
import { Word } from '../model/WordModel';

// 复习队列项
interface ReviewItem {
  word: Word;
  count: number;
  level: number;
}

// 单次复习最多多少个词，避免一次排队几百个
const SESSION_LIMIT: number = 30;
// 与 Store.REVIEW_INTERVALS 对应的总级数
const MAX_LEVEL: number = 6;

// 今日复习：从到期队列取词，认识则升级并顺延，不认识则打回 0 级
@Entry
@Component
struct ReviewPage {
  @State queue: ReviewItem[] = [];
  @State idx: number = 0;
  @State revealed: boolean = false;
  @State finished: boolean = false;
  @State knownCount: number = 0;
  @State unknownCount: number = 0;
  @State masteredCount: number = 0;
  @State totalDue: number = 0;
  @State answering: boolean = false;
  @StorageLink('darkMode') isDark: boolean = false;
  private store: Store = Store.get();

  aboutToAppear(): void {
    const wordIndex: Record<string, Word> = {};
    for (let b = 0; b < BOOKS.length; b++) {
      const book = BOOKS[b];
      for (let w = 0; w < book.words.length; w++) {
        wordIndex[book.words[w].id] = book.words[w];
      }
    }
    const dueIds = this.store.dueWordIds();
    this.totalDue = dueIds.length;
    const list: ReviewItem[] = [];
    const limit = Math.min(dueIds.length, SESSION_LIMIT);
    for (let i = 0; i < limit; i++) {
      const word = wordIndex[dueIds[i]];
      if (word === undefined) {
        continue;
      }
      const item: ReviewItem = {
        word: word,
        count: this.store.wrongCount[dueIds[i]] ?? 0,
        level: this.store.reviewLevel[dueIds[i]] ?? 0
      };
      list.push(item);
    }
    this.queue = list;
    if (list.length === 0) {
      this.finished = true;
    }
  }

  private async answer(known: boolean): Promise<void> {
    if (this.answering || this.finished || this.idx >= this.queue.length) {
      return;
    }
    this.answering = true;
    const item = this.queue[this.idx];
    const result = await this.store.reviewWord(item.word.id, known);
    if (result.mastered) {
      this.masteredCount += 1;
    }
    if (known) {
      this.knownCount += 1;
    } else {
      this.unknownCount += 1;
    }
    this.revealed = false;
    this.answering = false;
    if (this.idx + 1 >= this.queue.length) {
      this.finished = true;
    } else {
      this.idx += 1;
    }
  }

  @Builder
  TopBar() {
    Row() {
      Text('‹')
        .fontSize(28)
        .fontColor(Theme.ink(this.isDark))
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          router.back();
        })
      Column() {
        Progress({ value: this.queue.length === 0 ? 100 : this.idx * 100 / this.queue.length, total: 100, type: ProgressType.Linear })
          .style({ strokeWidth: 6 })
          .color(Theme.accent(this.isDark))
          .backgroundColor(Theme.line(this.isDark))
          .width('100%')
      }
      .layoutWeight(1)

      Text('今日复习')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.inkSecondary(this.isDark))
        .margin({ left: 12 })
    }
    .width('100%')
    .padding({ left: 8, right: 20, top: 8 })
  }

  @Builder
  Card() {
    Column() {
      Text(`${this.idx + 1} / ${this.queue.length}`)
        .fontSize(13)
        .fontColor(Theme.inkTertiary(this.isDark))
        .margin({ bottom: 12 })

      Column() {
        if (!this.revealed) {
          Column() {
            Text(this.queue[this.idx].word.word)
              .fontSize(38)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.ink(this.isDark))
            Text(this.queue[this.idx].word.phonetic)
              .fontSize(15)
              .fontColor(Theme.inkTertiary(this.isDark))
              .margin({ top: 10 })
            Text(`复习等级 ${this.queue[this.idx].level}/${MAX_LEVEL} · 累计答错 ${this.queue[this.idx].count} 次`)
              .fontSize(12)
              .fontColor(Theme.inkTertiary(this.isDark))
              .margin({ top: 10 })
            Text('点击卡片查看释义')
              .fontSize(13)
              .fontColor(Theme.accent(this.isDark))
              .margin({ top: 28 })
          }
          .justifyContent(FlexAlign.Center)
        } else {
          Column() {
            Text(this.queue[this.idx].word.word)
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.ink(this.isDark))
            Text(this.queue[this.idx].word.meaning)
              .fontSize(17)
              .fontColor(Theme.inkSecondary(this.isDark))
              .margin({ top: 12 })
              .textAlign(TextAlign.Center)
            if (this.queue[this.idx].word.example !== '') {
              Divider()
                .color(Theme.line(this.isDark))
                .margin({ top: 20, bottom: 16 })
              Text(this.queue[this.idx].word.example)
                .fontSize(14)
                .fontColor(Theme.ink(this.isDark))
                .textAlign(TextAlign.Center)
              Text(this.queue[this.idx].word.exampleCn)
                .fontSize(13)
                .fontColor(Theme.inkTertiary(this.isDark))
                .margin({ top: 8 })
                .textAlign(TextAlign.Center)
            }
          }
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .padding(24)
      .backgroundColor(Theme.glass(this.isDark))
      .backgroundBlurStyle(BlurStyle.Thin)
      .border({ width: 1, color: Theme.glassBorder(this.isDark) })
      .borderRadius(24)
      .shadow({ radius: 18, color: 'rgba(27,30,40,0.16)', offsetX: 0, offsetY: 8 })
      .onClick(() => {
        this.revealed = true;
      })
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  Actions() {
    Column() {
      if (!this.revealed) {
        Button('查看释义')
          .width('100%')
          .height(50)
          .fontSize(16)
          .fontColor(Color.White)
          .backgroundColor(Theme.accent(this.isDark))
          .borderRadius(25)
          .onClick(() => {
            this.revealed = true;
          })
      } else {
        Row({ space: 14 }) {
          Button('不认识')
            .layoutWeight(1)
            .height(50)
            .fontSize(16)
            .fontColor(Theme.danger(this.isDark))
            .backgroundColor(Theme.dangerSoft(this.isDark))
            .borderRadius(25)
            .onClick(() => {
              this.answer(false);
            })
          Button('认识')
            .layoutWeight(1)
            .height(50)
            .fontSize(16)
            .fontColor(Color.White)
            .backgroundColor(Theme.accent(this.isDark))
            .borderRadius(25)
            .onClick(() => {
              this.answer(true);
            })
        }
        .width('100%')
      }
      Text('答对会顺延到 1 / 2 / 4 / 7 / 15 / 30 天后，答错则回到第 0 级。')
        .fontSize(11)
        .fontColor(Theme.inkTertiary(this.isDark))
        .margin({ top: 12 })
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 16, bottom: 24 })
  }

  @Builder
  DoneView() {
    Column() {
      Column() {
        SymbolGlyph($r('sys.symbol.checkmark_circle'))
          .fontSize(42)
          .fontColor([Theme.success(this.isDark)])
      }
      .width(96)
      .height(96)
      .justifyContent(FlexAlign.Center)
      .backgroundColor(Theme.successSoft(this.isDark))
      .borderRadius(48)
      Text(this.queue.length === 0 ? '今天没有待复习的词' : '复习完成！')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.ink(this.isDark))
        .margin({ top: 22 })

      if (this.queue.length > 0) {
        Text(`认识 ${this.knownCount} · 不认识 ${this.unknownCount}`)
          .fontSize(15)
          .fontColor(Theme.inkSecondary(this.isDark))
          .margin({ top: 10 })
        Text(`其中 ${this.masteredCount} 个走完全部间隔，已移出错词本`)
          .fontSize(13)
          .fontColor(Theme.inkTertiary(this.isDark))
          .margin({ top: 6 })
        if (this.totalDue > this.queue.length) {
          Text(`还有 ${this.totalDue - this.queue.length} 个待复习，明天再来一轮`)
            .fontSize(13)
            .fontColor(Theme.inkTertiary(this.isDark))
            .margin({ top: 6 })
        }
      }

      Button('返回错词本')
        .width('100%')
        .height(50)
        .fontSize(16)
        .fontColor(Color.White)
        .backgroundColor(Theme.accent(this.isDark))
        .borderRadius(25)
        .margin({ top: 32 })
        .onClick(() => {
          router.back();
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding(32)
  }

  build() {
    Column() {
      this.TopBar()
      if (this.finished) {
        this.DoneView()
      } else {
        this.Card()
        this.Actions()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg(this.isDark))
  }
}