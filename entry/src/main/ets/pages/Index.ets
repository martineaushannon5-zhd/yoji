import { common } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';
import { Store } from '../store/Store';
import { Theme } from '../common/Theme';
import { MineView } from '../view/MineView';
import { VideoListView } from '../view/VideoListView';
import { STATUS_LEARNING, STATUS_MASTERED } from '../model/WordModel';
import { getBook } from '../data/WordData';

interface TabItem {
  label: string;
  icon: Resource;
}

// 词库学习进度统计
interface BookStats {
  name: string;
  subtitle: string;
  mastered: number;
  learning: number;
  total: number;
}

const TABS: TabItem[] = [
  { label: '今日要记', icon: $r('sys.symbol.sun_max') },
  { label: '视频学习', icon: $r('sys.symbol.play_circle') },
  { label: '我的Yoji', icon: $r('sys.symbol.person') }
];

@Entry
@Component
struct Index {
  @State activeTab: number = 0;
  // tick 变化（onPageShow、学习数据变更）时通过 @Watch 同步快照，驱动首页数据刷新
  @State @Watch('syncFromStore') tick: number = 0;
  // 首页展示数据快照：Store 为非响应式单例，UI 需读取 @State 才能实时刷新
  @State todayLearned: number = 0;
  @State dailyTarget: number = 10;
  @State streak: number = 0;
  @State totalLearned: number = 0;
  @State masteredCount: number = 0;
  @State learningCount: number = 0;
  @State stats: BookStats = { name: '', subtitle: '', mastered: 0, learning: 0, total: 0 };
  private store: Store = Store.get();

  aboutToAppear(): void {
    this.syncFromStore();
    this.initStore();
  }

  // 从学习页返回时刷新今日进度与词库进度
  onPageShow(): void {
    this.tick += 1;
  }

  private async initStore(): Promise<void> {
    const ctx = getContext(this) as common.UIAbilityContext;
    await this.store.init(ctx);
    this.tick += 1;
  }

  private mutate(): void {
    this.tick += 1;
  }

  // 从 Store 同步首页展示数据（初始化与 tick 变化时调用）
  private syncFromStore(): void {
    this.todayLearned = this.store.todayLearned;
    this.dailyTarget = this.store.dailyTarget;
    this.streak = this.store.streak;
    this.totalLearned = this.store.totalLearned;
    this.masteredCount = this.countStatus(STATUS_MASTERED);
    this.learningCount = this.countStatus(STATUS_LEARNING);
    this.stats = this.bookStats();
  }

  private startLearn(mode: string): void {
    router.pushUrl({
      url: 'pages/LearnPage',
      params: { bookId: this.store.currentBookId, mode: mode }
    });
  }

  private openMasteredList(): void {
    router.pushUrl({
      url: 'pages/WordListPage',
      params: { status: STATUS_MASTERED }
    });
  }

  private openLearningList(): void {
    router.pushUrl({
      url: 'pages/WordListPage',
      params: { status: STATUS_LEARNING }
    });
  }

  private countStatus(status: number): number {
    let n = 0;
    const keys = Object.keys(this.store.statusMap);
    for (let i = 0; i < keys.length; i++) {
      if (this.store.statusMap[keys[i]] === status) {
        n += 1;
      }
    }
    return n;
  }

  // 当前词库的学习进度统计
  private bookStats(): BookStats {
    const book = getBook(this.store.currentBookId);
    let mastered = 0;
    let learning = 0;
    for (let i = 0; i < book.words.length; i++) {
      const s = this.store.statusOf(book.words[i].id);
      if (s === STATUS_MASTERED) {
        mastered += 1;
      } else if (s === STATUS_LEARNING) {
        learning += 1;
      }
    }
    const stats: BookStats = {
      name: book.name,
      subtitle: book.subtitle,
      mastered: mastered,
      learning: learning,
      total: book.words.length
    };
    return stats;
  }

  private dateLabel(): string {
    const d = new Date();
    const week: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return `今天是 ${d.getMonth() + 1}月${d.getDate()}日 · ${week[d.getDay()]}`;
  }

  @Builder
  TabBar() {
    Row() {
      ForEach(TABS, (item: TabItem, idx: number) => {
        Column() {
          // 选中态胶囊：图标 + 文字
          Column() {
            SymbolGlyph(item.icon)
              .fontSize(22)
              .fontWeight(this.activeTab === idx ? FontWeight.Medium : FontWeight.Normal)
              .fontColor([this.activeTab === idx ? Theme.accent : Theme.inkTertiary])
              .scale({
                x: this.activeTab === idx ? 1.08 : 1,
                y: this.activeTab === idx ? 1.08 : 1
              })
              .animation({ duration: 250, curve: Curve.Friction })
            Text(item.label)
              .fontSize(11)
              .fontWeight(this.activeTab === idx ? FontWeight.Medium : FontWeight.Normal)
              .fontColor(this.activeTab === idx ? Theme.accent : Theme.inkTertiary)
              .margin({ top: 3 })
              .animation({ duration: 200, curve: Curve.EaseOut })
          }
          .padding({ top: 6, bottom: 6, left: 14, right: 14 })
          .borderRadius(20)
          .backgroundColor(this.activeTab === idx ? Theme.accentSoft : Color.Transparent)
          .animation({ duration: 200, curve: Curve.EaseOut })
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.activeTab = idx;
        })
      }, (item: TabItem) => item.label)
    }
    .padding({ top: 8, bottom: 12 })
    .backgroundColor(Theme.card)
    .borderRadius({ topLeft: 24, topRight: 24 })
    .shadow({ radius: 24, color: 'rgba(27, 30, 40, 0.08)', offsetY: -4 })
    // 背景延伸到系统底部导航条下方，避免底部出现割裂色带
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }

  // 当前词库与学习进度卡片
  @Builder
  CurrentBookCard() {
    Column() {
      Row() {
        SymbolGlyph($r('sys.symbol.book'))
          .fontSize(26)
          .fontColor([Theme.accent])
        Column() {
          Text(this.stats.name)
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.ink)
          Text(this.stats.subtitle)
            .fontSize(12)
            .fontColor(Theme.inkSecondary)
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 12 })
        Button('切换')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .type(ButtonType.Capsule)
          .backgroundColor(Theme.accentSoft)
          .fontColor(Theme.accent)
          .height(30)
          .padding({ left: 14, right: 14 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/BookListPage' });
          })
      }
      .width('100%')

      // 学习进度条：已掌握 + 学习中
      Progress({
        value: this.stats.mastered + this.stats.learning,
        total: this.stats.total,
        type: ProgressType.Linear
      })
        .style({ strokeWidth: 8 })
        .color(Theme.accent)
        .backgroundColor(Theme.line)
        .width('100%')
        .margin({ top: 18 })

      Row() {
        Circle({ width: 6, height: 6 })
          .fill(Theme.success)
        Text(`已掌握 ${this.stats.mastered}`)
          .fontSize(12)
          .fontColor(Theme.inkSecondary)
          .margin({ left: 5 })
        Blank()
        Circle({ width: 6, height: 6 })
          .fill(Theme.warning)
        Text(`学习中 ${this.stats.learning}`)
          .fontSize(12)
          .fontColor(Theme.inkSecondary)
          .margin({ left: 5 })
        Blank()
        Circle({ width: 6, height: 6 })
          .fill(Theme.inkTertiary)
        Text(`未学 ${this.stats.total - this.stats.mastered - this.stats.learning}`)
          .fontSize(12)
          .fontColor(Theme.inkSecondary)
          .margin({ left: 5 })
      }
      .width('100%')
      .margin({ top: 14 })
    }
    .backgroundColor(Theme.card)
    .borderRadius(24)
    .padding(20)
    .width('100%')
    .margin({ top: 16 })
  }

  // 已掌握卡片：可点击进入已掌握单词列表
  @Builder
  MasteredCard() {
    Stack({ alignContent: Alignment.End }) {
      // 背景奖杯图案：与数字同色、略微倾斜的水印样式
      SymbolGlyph($r('sys.symbol.star_trophy'))
        .fontSize(64)
        .fontColor([Theme.success])
        .opacity(0.35)
        .rotate({ angle: -15 })
        .margin({ right: 4 })

      Column() {
        Row() {
          Text(`${this.masteredCount}`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.success)
          Blank()
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(14)
            .fontColor([Theme.success])
        }
        .width('100%')
        Text('已掌握')
          .fontSize(13)
          .fontColor(Theme.inkSecondary)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    .backgroundColor(Theme.successSoft)
    .borderRadius(18)
    .padding(18)
    .layoutWeight(1)
    .onClick(() => {
      this.openMasteredList();
    })
  }

  // 学习中卡片：可点击进入学习中单词列表
  @Builder
  LearningCard() {
    Stack({ alignContent: Alignment.End }) {
      // 背景书本图案：与数字同色、略微倾斜的水印样式
      SymbolGlyph($r('sys.symbol.book'))
        .fontSize(64)
        .fontColor([Theme.warning])
        .opacity(0.35)
        .rotate({ angle: -15 })
        .margin({ right: 4 })

      Column() {
        Row() {
          Text(`${this.learningCount}`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.warning)
          Blank()
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(14)
            .fontColor([Theme.warning])
        }
        .width('100%')
        Text('学习中')
          .fontSize(13)
          .fontColor(Theme.inkSecondary)
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
    }
    .backgroundColor(Theme.warningSoft)
    .borderRadius(18)
    .padding(18)
    .layoutWeight(1)
    .onClick(() => {
      this.openLearningList();
    })
  }

  @Builder
  HomeView() {
    Column() {
      Row() {
        Column() {
          Text('今日Yoji.')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.ink)
          Text(this.dateLabel())
            .fontSize(14)
            .fontColor(Theme.inkSecondary)
            .margin({ top: 6 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24, bottom: 8 })

      Scroll() {
        Column() {
          // 今日进度卡
          Column() {
            Row() {
              Column() {
                Text('今日目标')
                  .fontSize(14)
                  .fontColor(Theme.inkSecondary)
                Row() {
                  Text(`${this.todayLearned}`)
                    .fontSize(44)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.ink)
                  Text(` / ${this.dailyTarget}`)
                    .fontSize(20)
                    .fontColor(Theme.inkTertiary)
                    .margin({ bottom: 8 })
                }
                .alignItems(VerticalAlign.Bottom)
                .margin({ top: 10 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Progress({
                value: this.todayLearned,
                total: this.dailyTarget,
                type: ProgressType.Ring
              })
                .style({ strokeWidth: 10 })
                .color(Theme.accent)
                .backgroundColor(Theme.line)
                .width(76)
                .height(76)
            }
            .width('100%')

            Row() {
              Text(`连续学习 ${this.streak} 天`)
                .fontSize(13)
                .fontColor(Theme.inkSecondary)
              Blank()
              Text(`累计掌握 ${this.totalLearned} 词`)
                .fontSize(13)
                .fontColor(Theme.inkSecondary)
            }
            .width('100%')
            .margin({ top: 20 })
          }
          .backgroundColor(Theme.card)
          .borderRadius(24)
          .padding(24)
          .width('100%')

          // 当前词库与学习进度
          this.CurrentBookCard()

          // 学习入口
          Row({ space: 12 }) {
            Button('开始学习')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .type(ButtonType.Capsule)
              .backgroundColor(Theme.accent)
              .layoutWeight(1)
              .height(52)
              .onClick(() => {
                this.startLearn('learn');
              })
            Button('快速复习')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .type(ButtonType.Capsule)
              .backgroundColor(Theme.accentSoft)
              .fontColor(Theme.accent)
              .layoutWeight(1)
              .height(52)
              .onClick(() => {
                this.startLearn('review');
              })
          }
          .width('100%')
          .margin({ top: 16 })

          // 掌握情况
          Text('掌握情况')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.ink)
            .margin({ top: 28 })
            .width('100%')

          Row({ space: 12 }) {
            this.MasteredCard()
            this.LearningCard()
          }
          .width('100%')
          .margin({ top: 12 })
        }
        .padding({ left: 24, right: 24, bottom: 24 })
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Column() {
      if (this.activeTab === 0) {
        this.HomeView()
      } else if (this.activeTab === 1) {
        VideoListView()
      } else {
        MineView({ tick: this.tick, onMutate: (): void => {
          this.mutate();
        } })
      }
      this.TabBar()
    }
    .width('100%')
    .height('95%')
    .backgroundColor(Theme.bg)
  }
}
