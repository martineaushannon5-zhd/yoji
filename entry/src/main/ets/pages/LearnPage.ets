import { router } from '@kit.ArkUI';
import { getBook } from '../data/WordData';
import { Store } from '../store/Store';
import { Theme } from '../common/Theme';
import { QuizOption, STATUS_MASTERED, Word } from '../model/WordModel';

interface PageParams {
  bookId: string;
  mode: string;
}

interface QuizItem {
  word: Word;
  options: QuizOption[];
}

function shuffle<T>(arr: T[]): T[] {
  const copy: T[] = arr.slice();
  for (let i = copy.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    const tmp = copy[i];
    copy[i] = copy[j];
    copy[j] = tmp;
  }
  return copy;
}

@Entry
@Component
struct LearnPage {
  @State mode: string = 'learn';
  @State queue: Word[] = [];
  @State idx: number = 0;
  @State revealed: boolean = false;
  @State knownCount: number = 0;
  @State unknownCount: number = 0;
  @State quizItems: QuizItem[] = [];
  @State quizIdx: number = 0;
  @State selectedIdx: number = -1;
  @State finished: boolean = false;
  @State favorited: boolean = false;
  private store: Store = Store.get();
  private bookName: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as PageParams;
    const book = getBook(params.bookId);
    this.bookName = book.name;
    this.mode = params.mode;
    if (this.mode === 'learn') {
      const pending: Word[] = book.words.filter((wItem: Word): boolean => {
        return this.store.statusOf(wItem.id) !== STATUS_MASTERED;
      });
      const shuffled = shuffle(pending);
      const take = Math.min(this.store.dailyTarget, shuffled.length);
      this.queue = shuffled.slice(0, take);
    } else {
      const candidates: Word[] = book.words.filter((wItem: Word): boolean => {
        return this.store.statusOf(wItem.id) !== 0;
      });
      this.quizItems = shuffle(candidates).slice(0, 10).map((word: Word): QuizItem => {
        const distractors: Word[] = shuffle(book.words.filter((o: Word): boolean => {
          return o.id !== word.id;
        })).slice(0, 3);
        const options: QuizOption[] = distractors.map((d: Word): QuizOption => {
          const opt: QuizOption = { wordId: d.id, meaning: d.meaning, isAnswer: false };
          return opt;
        });
        options.push({ wordId: word.id, meaning: word.meaning, isAnswer: true });
        const item: QuizItem = { word: word, options: shuffle(options) };
        return item;
      });
    }
    this.syncFavState();
  }

  private total(): number {
    return this.mode === 'learn' ? this.queue.length : this.quizItems.length;
  }

  private progressValue(): number {
    return this.total() === 0 ? 100 : Math.round((this.mode === 'learn' ? this.idx : this.quizIdx) * 100 / this.total());
  }

  private async answerLearn(known: boolean): Promise<void> {
    if (this.idx >= this.queue.length) {
      this.finished = true;
      return;
    }
    const word = this.queue[this.idx];
    await this.store.markLearned(word.id, known);
    if (known) {
      this.knownCount += 1;
    } else {
      this.unknownCount += 1;
    }
    this.revealed = false;
    this.idx += 1;
    this.syncFavState();
    if (this.idx >= this.queue.length) {
      this.finished = true;
    }
  }

  // 当前展示的单词（学词取队列当前项，复习取测验当前项）
  private currentFavWord(): Word | undefined {
    if (this.mode === 'learn') {
      return this.idx < this.queue.length ? this.queue[this.idx] : undefined;
    }
    return this.quizIdx < this.quizItems.length ? this.quizItems[this.quizIdx].word : undefined;
  }

  // 依据当前单词同步收藏星标状态
  private syncFavState(): void {
    const word = this.currentFavWord();
    this.favorited = word !== undefined && this.store.isFavorite(word.id);
  }

  // 切换当前单词的收藏状态
  private async toggleFav(): Promise<void> {
    const word = this.currentFavWord();
    if (word === undefined) {
      return;
    }
    this.favorited = await this.store.toggleFavorite(word.id);
  }

  private async answerQuiz(optionIdx: number): Promise<void> {
    if (this.selectedIdx >= 0) {
      return;
    }
    this.selectedIdx = optionIdx;
    const item = this.quizItems[this.quizIdx];
    const correct = item.options[optionIdx].isAnswer;
    if (!correct) {
      // 答错降级为学习中，强化记忆
      await this.store.markLearned(item.word.id, false);
    }
    setTimeout(() => {
      this.selectedIdx = -1;
      this.quizIdx += 1;
      this.syncFavState();
      if (this.quizIdx >= this.quizItems.length) {
        this.finished = true;
      }
    }, 650);
  }

  private optionColor(opt: QuizOption, optionIdx: number): string {
    if (this.selectedIdx < 0) {
      return Theme.card;
    }
    if (opt.isAnswer) {
      return Theme.successSoft;
    }
    if (optionIdx === this.selectedIdx) {
      return '#FDEAEA';
    }
    return Theme.card;
  }

  private optionTextColor(opt: QuizOption, optionIdx: number): string {
    if (this.selectedIdx < 0) {
      return Theme.ink;
    }
    if (opt.isAnswer) {
      return Theme.success;
    }
    if (optionIdx === this.selectedIdx) {
      return '#DC2626';
    }
    return Theme.ink;
  }

  @Builder
  TopBar() {
    Row() {
      Text('‹')
        .fontSize(28)
        .fontColor(Theme.ink)
        .width(44)
        .height(44)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          router.back();
        })
      Column() {
        Progress({ value: this.progressValue(), total: 100, type: ProgressType.Linear })
          .style({ strokeWidth: 6 })
          .color(Theme.accent)
          .backgroundColor(Theme.line)
          .width('100%')
      }
      .layoutWeight(1)

      Text(this.mode === 'learn' ? '学词' : '复习')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.inkSecondary)
        .margin({ left: 12 })
    }
    .width('100%')
    .padding({ left: 8, right: 20, top: 8 })
  }

  @Builder
  Flashcard() {
    Column() {
      Text(`${this.idx + 1} / ${this.queue.length}`)
        .fontSize(13)
        .fontColor(Theme.inkTertiary)
        .margin({ bottom: 12 })

      Stack({ alignContent: Alignment.TopEnd }) {
        Column() {
          if (!this.revealed) {
            Column() {
              Text(this.queue[this.idx].word)
                .fontSize(38)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.ink)
              Text(this.queue[this.idx].phonetic)
                .fontSize(15)
                .fontColor(Theme.inkTertiary)
                .margin({ top: 10 })
              Text('点击卡片查看释义')
                .fontSize(13)
                .fontColor(Theme.accent)
                .margin({ top: 28 })
            }
            .justifyContent(FlexAlign.Center)
          } else {
            Column() {
              Text(this.queue[this.idx].word)
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.ink)
              Text(this.queue[this.idx].meaning)
                .fontSize(18)
                .fontColor(Theme.inkSecondary)
                .margin({ top: 12 })
                .textAlign(TextAlign.Center)
              Divider()
                .color(Theme.line)
                .margin({ top: 22, bottom: 18 })
              Text(this.queue[this.idx].example)
                .fontSize(14)
                .fontColor(Theme.ink)
                .textAlign(TextAlign.Center)
              Text(this.queue[this.idx].exampleCn)
                .fontSize(13)
                .fontColor(Theme.inkTertiary)
                .margin({ top: 6 })
                .textAlign(TextAlign.Center)
            }
            .justifyContent(FlexAlign.Center)
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor(Theme.card)
        .borderRadius(28)
        .padding(28)
        .onClick(() => {
          this.revealed = !this.revealed;
        })

        // 收藏星标：点击切换收藏，收藏后为实心黄色
        Column() {
          SymbolGlyph(this.favorited ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
            .fontSize(22)
            .fontColor([this.favorited ? Theme.accent : Theme.inkTertiary])
            .animation({ duration: 200, curve: Curve.EaseOut })
        }
        .width(44)
        .height(44)
        .borderRadius(22)
        .justifyContent(FlexAlign.Center)
        .margin({ top: 12, right: 12 })
        .onClick(() => {
          this.toggleFav();
        })
      }
      .width('100%')
      .layoutWeight(1)

      // 认识 / 不认识
      Row({ space: 12 }) {
        Button('不认识')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .type(ButtonType.Capsule)
          .backgroundColor(Theme.warningSoft)
          .fontColor(Theme.warning)
          .layoutWeight(1)
          .height(52)
          .onClick(() => {
            this.answerLearn(false);
          })
        Button('认识')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .type(ButtonType.Capsule)
          .backgroundColor(this.revealed ? Theme.success : Theme.accent)
          .fontColor(Color.White)
          .layoutWeight(1)
          .height(52)
          .onClick(() => {
            this.answerLearn(true);
          })
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .layoutWeight(1)
    .padding(24)
  }

  @Builder
  QuizView() {
    Column() {
      Row() {
        Text(`${this.quizIdx + 1} / ${this.quizItems.length}`)
          .fontSize(13)
          .fontColor(Theme.inkTertiary)
        Blank()
        // 收藏星标：点击切换收藏，收藏后为实心蓝色
        SymbolGlyph(this.favorited ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
          .fontSize(22)
          .fontColor([this.favorited ? Theme.accent : Theme.inkTertiary])
          .animation({ duration: 200, curve: Curve.EaseOut })
          .onClick(() => {
            this.toggleFav();
          })
      }
      .width('100%')
      .margin({ bottom: 12 })

      Column() {
        Text('选择正确的释义')
          .fontSize(14)
          .fontColor(Theme.inkSecondary)
        Text(this.quizItems[this.quizIdx].word.word)
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.ink)
          .margin({ top: 10 })
      }
      .width('100%')
      .padding({ top: 10, bottom: 24 })

      Column({ space: 12 }) {
        ForEach(this.quizItems[this.quizIdx].options, (opt: QuizOption, i: number) => {
          Row() {
            Text(opt.meaning)
              .fontSize(15)
              .fontColor(this.optionTextColor(opt, i))
              .layoutWeight(1)
          }
          .width('100%')
          .padding(18)
          .borderRadius(18)
          .backgroundColor(this.optionColor(opt, i))
          .border({ width: 1, color: Theme.line })
          .onClick(() => {
            this.answerQuiz(i);
          })
        }, (opt: QuizOption) => `${opt.wordId}-${this.quizIdx}`)
      }
      .layoutWeight(1)
    }
    .layoutWeight(1)
    .padding(24)
  }

  @Builder
  DoneView() {
    Column() {
      Text('✓')
        .fontSize(40)
        .fontColor(Theme.success)
        .width(84)
        .height(84)
        .textAlign(TextAlign.Center)
        .backgroundColor(Theme.successSoft)
        .borderRadius(42)
      Text(this.mode === 'learn' ? '本轮学完！' : '复习完成！')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.ink)
        .margin({ top: 24 })

      if (this.mode === 'learn') {
        Text(`认识 ${this.knownCount} 个 · 不认识 ${this.unknownCount} 个`)
          .fontSize(15)
          .fontColor(Theme.inkSecondary)
          .margin({ top: 10 })
      } else {
        Text('答错的单词已标记为「学习中」，下次复习会出现')
          .fontSize(15)
          .fontColor(Theme.inkSecondary)
          .margin({ top: 10 })
          .textAlign(TextAlign.Center)
      }

      Button('返回首页')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .type(ButtonType.Capsule)
        .backgroundColor(Theme.accent)
        .height(52)
        .width('60%')
        .margin({ top: 40 })
        .onClick(() => {
          router.back();
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(32)
  }

  build() {
    Column() {
      if (this.finished) {
        this.DoneView()
      } else {
        this.TopBar()
        if (this.mode === 'learn') {
          if (this.queue.length > 0) {
            this.Flashcard()
          } else {
            Column() {
              Text('这个词书已经全部掌握啦')
                .fontSize(17)
                .fontColor(Theme.inkSecondary)
              Button('返回首页')
                .margin({ top: 24 })
                .onClick(() => {
                  router.back();
                })
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          }
        } else {
          if (this.quizItems.length > 0) {
            this.QuizView()
          } else {
            Column() {
              Text('还没有可复习的单词\n先去学习几个新词吧')
                .fontSize(17)
                .fontColor(Theme.inkSecondary)
                .textAlign(TextAlign.Center)
                .lineHeight(26)
              Button('返回首页')
                .margin({ top: 24 })
                .onClick(() => {
                  router.back();
                })
            }
            .width('100%')
            .layoutWeight(1)
            .justifyContent(FlexAlign.Center)
          }
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg)
  }
}
