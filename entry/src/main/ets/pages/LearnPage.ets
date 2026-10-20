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
  // 滑动交互：卡片水平偏移与判定锁（飞出动画期间忽略新手势）
  @State offsetX: number = 0;
  @State answering: boolean = false;
  // 首次进入学词的滑动引导：黑屏遮罩 + 方向箭头往复动效
  @State showSwipeGuide: boolean = false;
  @State guideOpacity: number = 0;
  @State guidePhase: boolean = false;
  // 深色模式开关：双向绑定 AppStorage，切换后页面配色同步刷新
  @StorageLink('darkMode') isDark: boolean = false;
  private guideTimer: number = -1;
  private guideClosing: boolean = false;
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
    // 首次进入学词模式时展示滑动引导（仅一次，Store 持久化标记）
    if (this.mode === 'learn' && !this.store.hasSeenSwipeGuide()) {
      this.showSwipeGuide = true;
      this.store.markSwipeGuideSeen();
      this.playSwipeGuide();
    }
  }

  aboutToDisappear(): void {
    if (this.guideTimer >= 0) {
      clearInterval(this.guideTimer);
      this.guideTimer = -1;
    }
  }

  // 播放引导动效：箭头往复滑动，淡入后自动关闭
  private playSwipeGuide(): void {
    this.guideTimer = setInterval(() => {
      this.guidePhase = !this.guidePhase;
    }, 650);
    setTimeout(() => {
      animateTo({ duration: 450, curve: Curve.EaseOut }, () => {
        this.guideOpacity = 1;
      });
    }, 120);
    setTimeout(() => {
      this.dismissGuide();
    }, 3200);
  }

  // 淡出并移除引导遮罩
  private dismissGuide(): void {
    if (this.guideClosing) {
      return;
    }
    this.guideClosing = true;
    animateTo({ duration: 380, curve: Curve.EaseIn }, () => {
      this.guideOpacity = 0;
    });
    setTimeout(() => {
      this.showSwipeGuide = false;
      if (this.guideTimer >= 0) {
        clearInterval(this.guideTimer);
        this.guideTimer = -1;
      }
    }, 400);
  }

  private total(): number {
    return this.mode === 'learn' ? this.queue.length : this.quizItems.length;
  }

  private progressValue(): number {
    return this.total() === 0 ? 100 : Math.round((this.mode === 'learn' ? this.idx : this.quizIdx) * 100 / this.total());
  }

  private answerLearn(known: boolean): void {
    if (this.idx >= this.queue.length) {
      this.finished = true;
      return;
    }
    const word = this.queue[this.idx];
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
    // 先同步切换卡片，持久化异步进行，避免 await 阻塞滑动动画衔接
    this.store.markLearned(word.id, known);
  }

  // 左滑 = 不认识，右滑 = 认识；超过阈值飞出卡片，否则回弹
  private swipeSettle(endX: number): void {
    const threshold = 90;
    if (endX <= -threshold) {
      this.flyAway(false);
    } else if (endX >= threshold) {
      this.flyAway(true);
    } else {
      animateTo({ duration: 180, curve: Curve.EaseOut }, () => {
        this.offsetX = 0;
      });
    }
  }

  // 卡片飞出屏幕后切入下一个单词
  private flyAway(known: boolean): void {
    this.answering = true;
    animateTo({ duration: 220, curve: Curve.EaseIn }, () => {
      this.offsetX = known ? 900 : -900;
    });
    setTimeout(() => {
      this.offsetX = 0;
      this.answering = false;
      this.answerLearn(known);
    }, 240);
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

  private optionColor(opt: QuizOption, optionIdx: number, dark: boolean): string {
    if (this.selectedIdx < 0) {
      return Theme.glass(dark);
    }
    if (opt.isAnswer) {
      return Theme.successSoft(dark);
    }
    if (optionIdx === this.selectedIdx) {
      return Theme.dangerSoft(dark);
    }
    return Theme.glass(dark);
  }

  private optionTextColor(opt: QuizOption, optionIdx: number, dark: boolean): string {
    if (this.selectedIdx < 0) {
      return Theme.ink(dark);
    }
    if (opt.isAnswer) {
      return Theme.success(dark);
    }
    if (optionIdx === this.selectedIdx) {
      return Theme.danger(dark);
    }
    return Theme.ink(dark);
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
        Progress({ value: this.progressValue(), total: 100, type: ProgressType.Linear })
          .style({ strokeWidth: 6 })
          .color(Theme.accent(this.isDark))
          .backgroundColor(Theme.line(this.isDark))
          .width('100%')
      }
      .layoutWeight(1)

      Text(this.mode === 'learn' ? '学词' : '复习')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(Theme.inkSecondary(this.isDark))
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
        .fontColor(Theme.inkTertiary(this.isDark))
        .margin({ bottom: 12 })

      Stack({ alignContent: Alignment.TopEnd }) {
        Column() {
          if (!this.revealed) {
            Column() {
              Text(this.queue[this.idx].word)
                .fontSize(38)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.ink(this.isDark))
              Text(this.queue[this.idx].phonetic)
                .fontSize(15)
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
              Text(this.queue[this.idx].word)
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.ink(this.isDark))
              Text(this.queue[this.idx].meaning)
                .fontSize(18)
                .fontColor(Theme.inkSecondary(this.isDark))
                .margin({ top: 12 })
                .textAlign(TextAlign.Center)
              Divider()
                .color(Theme.line(this.isDark))
                .margin({ top: 22, bottom: 18 })
              Text(this.queue[this.idx].example)
                .fontSize(14)
                .fontColor(Theme.ink(this.isDark))
                .textAlign(TextAlign.Center)
              Text(this.queue[this.idx].exampleCn)
                .fontSize(13)
                .fontColor(Theme.inkTertiary(this.isDark))
                .margin({ top: 6 })
                .textAlign(TextAlign.Center)
            }
            .justifyContent(FlexAlign.Center)
          }
        }
        .width('100%')
        .height('100%')
        // 与首页一致的玻璃质感：半透明底 + 背景模糊 + 高光描边 + 悬空阴影
        .backgroundColor(Theme.glass(this.isDark))
        .backgroundBlurStyle(BlurStyle.Thin)
        .border({ width: 1, color: Theme.glassBorder(this.isDark) })
        .borderRadius(28)
        .shadow({ radius: 18, color: 'rgba(27,30,40,0.14)', offsetX: 0, offsetY: 8 })
        .padding(28)
        .onClick(() => {
          this.revealed = !this.revealed;
        })

        // 收藏星标：点击切换收藏，收藏后为实心黄色
        Column() {
          SymbolGlyph(this.favorited ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
            .fontSize(22)
            .fontColor([this.favorited ? Theme.accent(this.isDark) : Theme.inkTertiary(this.isDark)])
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
      .translate({ x: this.offsetX })
      .rotate({ angle: this.offsetX / 18 })
    }
    .layoutWeight(1)
    .padding(24)
    .gesture(
      PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 5 })
        .onActionUpdate((event: GestureEvent) => {
          if (this.answering) {
            return;
          }
          this.offsetX = event.offsetX;
        })
        .onActionEnd((event: GestureEvent) => {
          if (this.answering) {
            return;
          }
          this.swipeSettle(event.offsetX);
        })
    )
  }

  @Builder
  QuizView() {
    Column() {
      Row() {
        Text(`${this.quizIdx + 1} / ${this.quizItems.length}`)
          .fontSize(13)
          .fontColor(Theme.inkTertiary(this.isDark))
        Blank()
        // 收藏星标：点击切换收藏，收藏后为实心蓝色
        SymbolGlyph(this.favorited ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
          .fontSize(22)
          .fontColor([this.favorited ? Theme.accent(this.isDark) : Theme.inkTertiary(this.isDark)])
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
          .fontColor(Theme.inkSecondary(this.isDark))
        Text(this.quizItems[this.quizIdx].word.word)
          .fontSize(36)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.ink(this.isDark))
          .margin({ top: 10 })
      }
      .width('100%')
      .padding({ top: 10, bottom: 24 })

      Column({ space: 12 }) {
        ForEach(this.quizItems[this.quizIdx].options, (opt: QuizOption, i: number) => {
          Row() {
            Text(opt.meaning)
              .fontSize(15)
              .fontColor(this.optionTextColor(opt, i, this.isDark))
              .layoutWeight(1)
          }
          .width('100%')
          .padding(18)
          .borderRadius(18)
          .backgroundColor(this.optionColor(opt, i, this.isDark))
          .border({ width: 1, color: Theme.line(this.isDark) })
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
        .fontColor(Theme.success(this.isDark))
        .width(84)
        .height(84)
        .textAlign(TextAlign.Center)
        .backgroundColor(Theme.successSoft(this.isDark))
        .borderRadius(42)
      Text(this.mode === 'learn' ? '本轮学完！' : '复习完成！')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.ink(this.isDark))
        .margin({ top: 24 })

      if (this.mode === 'learn') {
        Text(`认识 ${this.knownCount} 个 · 不认识 ${this.unknownCount} 个`)
          .fontSize(15)
          .fontColor(Theme.inkSecondary(this.isDark))
          .margin({ top: 10 })
      } else {
        Text('答错的单词已标记为「学习中」，下次复习会出现')
          .fontSize(15)
          .fontColor(Theme.inkSecondary(this.isDark))
          .margin({ top: 10 })
          .textAlign(TextAlign.Center)
      }

      Button('返回首页')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .type(ButtonType.Capsule)
        .backgroundColor(Theme.accentGlassStrong(this.isDark))
        .backgroundBlurStyle(BlurStyle.Thin)
        .border({ width: 1, color: Theme.accentGlassBorder(this.isDark) })
        .fontColor(Theme.accent(this.isDark))
        .shadow({
          radius: 16,
          color: this.isDark ? 'rgba(123,147,255,0.35)' : 'rgba(61,90,241,0.30)',
          offsetX: 0,
          offsetY: 6
        })
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

  // 首次进入学词的黑屏滑动引导：箭头往复动效，轻触或超时自动关闭
  @Builder
  SwipeGuideOverlay() {
    Column() {
      Text('滑动卡片作答')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
        .margin({ bottom: 60 })

      // 左滑：不认识
      Row({ space: 14 }) {
        SymbolGlyph($r('sys.symbol.arrow_left'))
          .fontSize(32)
          .fontColor([Color.White])
          .translate({ x: this.guidePhase ? -30 : 0 })
          .opacity(this.guidePhase ? 1 : 0.45)
          .animation({ duration: 550, curve: Curve.EaseInOut })
        Text('左滑：不认识')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
      }
      .margin({ bottom: 32 })

      // 右滑：认识
      Row({ space: 14 }) {
        Text('右滑：认识')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
        SymbolGlyph($r('sys.symbol.arrow_right'))
          .fontSize(32)
          .fontColor([Color.White])
          .translate({ x: this.guidePhase ? 30 : 0 })
          .opacity(this.guidePhase ? 1 : 0.45)
          .animation({ duration: 550, curve: Curve.EaseInOut })
      }

      Text('轻触任意处关闭')
        .fontSize(13)
        .fontColor('#B3FFFFFF')
        .margin({ top: 72 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2000000')
    .justifyContent(FlexAlign.Center)
    .opacity(this.guideOpacity)
    .onClick(() => {
      this.dismissGuide();
    })
  }

  build() {
    Stack() {
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
                  .fontColor(Theme.inkSecondary(this.isDark))
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
                  .fontColor(Theme.inkSecondary(this.isDark))
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
      .backgroundColor(Theme.bg(this.isDark))

      // 首次进入学词的黑屏滑动引导：仅在显示时渲染，隐藏后不拦截触摸事件
      if (this.showSwipeGuide) {
        this.SwipeGuideOverlay()
      }
    }
    .width('100%')
    .height('100%')
  }
}
