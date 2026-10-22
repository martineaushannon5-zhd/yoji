import { common } from '@kit.AbilityKit';
import { router, curves } from '@kit.ArkUI';
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
  // 深色模式开关：双向绑定 AppStorage，切换后页面配色同步刷新
  @StorageLink('darkMode') isDark: boolean = false;
  // 云端同步完成标记：CloudSync 应用云端快照后自增，驱动首页重新读取 Store
  @StorageLink('syncTick') @Watch('onCloudSync') syncTick: number = 0;
  // 底部导航栏滚动联动：内容上滑时收起，下滑时恢复
  @State tabBarHidden: boolean = false;
  // tick 变化（onPageShow、学习数据变更）时通过 @Watch 同步快照，驱动首页数据刷新
  @State @Watch('syncFromStore') tick: number = 0;
  // 首页展示数据快照：Store 为非响应式单例，UI 需读取 @State 才能实时刷新
  @State todayLearned: number = 0;
  @State dailyTarget: number = 10;
  @State streak: number = 0;
  @State totalLearned: number = 0;
  @State masteredCount: number = 0;
  @State learningCount: number = 0;
  // 今天是否为用户生日（当天标题换成“生日快乐”并展示蛋糕水印）
  @State isBirthday: boolean = false;
  @State stats: BookStats = { name: '', subtitle: '', mastered: 0, learning: 0, total: 0 };
  private store: Store = Store.get();
  // 记录最近一次滚动位置，用于判断滚动方向
  private lastScrollY: number = 0;
  // 首页模块入场动画开关：首次进入或切回“今日要记”时触发错峰上浮
  @State homeEnter: boolean = false;
  // 今日目标达成态：圆环满后中心展示奖杯图案
  @State goalDone: boolean = false;
  // 奖杯入场缩放与摆动角度（keyframeAnimateTo 驱动）
  @State trophyScale: number = 0;
  @State trophyRotate: number = 0;
  // 底部导航栏交互动效：拖拽时原地轻微形变（位置固定不动）
  @State tabScaleX: number = 1;
  @State tabScaleY: number = 1;
  // 悬浮胶囊拖拽：拖拽中的额外位移与拖拽标记（拖拽时关闭弹簧动画以实时跟手）
  @State capsuleDragX: number = 0;
  @State capsuleDragging: boolean = false;

  aboutToAppear(): void {
    this.syncFromStore();
    this.initStore();
    // 延迟一帧触发入场动画，保证首帧以隐藏态渲染后再过渡
    setTimeout(() => {
      this.homeEnter = true;
    }, 120);
  }

  // 从学习页返回时刷新今日进度与词库进度
  onPageShow(): void {
    this.tick += 1;
  }

  // 云端进度已应用：立即刷新首页统计
  private onCloudSync(): void {
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

  // 滚动联动：内容向上滑动时收起导航栏，向下滑动或回到顶部时恢复
  private handleScroll(y: number): void {
    const dy = y - this.lastScrollY;
    this.lastScrollY = y;
    if (y < 60) {
      if (this.tabBarHidden) {
        this.tabBarHidden = false;
      }
      return;
    }
    if (dy > 6 && !this.tabBarHidden) {
      this.tabBarHidden = true;
    } else if (dy < -6 && this.tabBarHidden) {
      this.tabBarHidden = false;
    }
  }

  // 切换到指定标签页（点击与拖拽胶囊共用）：切回“今日要记”时重播入场动画，并复位滚动/导航栏状态
  private selectTab(idx: number): void {
    if (idx === this.activeTab) {
      return;
    }
    if (idx === 0) {
      this.homeEnter = false;
      setTimeout(() => {
        this.homeEnter = true;
      }, 80);
    }
    this.activeTab = idx;
    this.lastScrollY = 0;
    this.tabBarHidden = false;
  }

  // 从 Store 同步首页展示数据（初始化与 tick 变化时调用）
  private syncFromStore(): void {
    this.todayLearned = this.store.todayLearned;
    this.dailyTarget = this.store.dailyTarget;
    this.streak = this.store.streak;
    this.totalLearned = this.store.totalLearned;
    this.masteredCount = this.countStatus(STATUS_MASTERED);
    this.learningCount = this.countStatus(STATUS_LEARNING);
    this.isBirthday = this.store.isBirthdayToday();
    this.stats = this.bookStats();
    // 目标达成上升沿检测：首次达成触发奖杯入场动效（重复刷新不重播）
    const done = this.dailyTarget > 0 && this.todayLearned >= this.dailyTarget;
    if (done && !this.goalDone) {
      this.goalDone = true;
      this.playTrophyAnim();
    } else if (!done && this.goalDone) {
      // 目标重置（如次日清零）：隐藏奖杯并复位动效参数
      this.goalDone = false;
      this.trophyScale = 0;
    }
  }

  // 今日目标达成动效：奖杯弹跳摆入
  private playTrophyAnim(): void {
    // 奖杯弹跳入场：先缩小再放大回弹并左右摆动（与爱心弹跳同款关键帧写法）
    this.getUIContext().keyframeAnimateTo({
      iterations: 1
    }, [
      {
        duration: 100,
        curve: Curve.EaseIn,
        event: () => {
          this.trophyScale = 0.2;
          this.trophyRotate = -20;
        }
      },
      {
        duration: 190,
        curve: Curve.EaseOut,
        event: () => {
          this.trophyScale = 1.35;
          this.trophyRotate = 12;
        }
      },
      {
        duration: 130,
        curve: Curve.EaseIn,
        event: () => {
          this.trophyScale = 0.88;
          this.trophyRotate = -5;
        }
      },
      {
        duration: 90,
        curve: Curve.EaseOut,
        event: () => {
          this.trophyScale = 1.0;
          this.trophyRotate = 0;
        }
      }
    ]);
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
    return `${d.getMonth() + 1}月${d.getDate()}日 · ${week[d.getDay()]}`;
  }

  // 液态玻璃顶部受光边缘：与底部导航栏同款高光线
  @Builder
  GlassHighlight(widthPercent: string) {
    Row()
      .width(widthPercent)
      .height(1)
      .linearGradient({
        angle: 90,
        colors: [['rgba(255,255,255,0)', 0],
          [this.isDark ? 'rgba(255,255,255,0.22)' : 'rgba(255,255,255,0.95)', 0.5],
          ['rgba(255,255,255,0)', 1]]
      })
  }

  // 底部悬浮导航栏：玻璃质感胶囊 + 悬空阴影，随内容滚动联动收起/展开
  @Builder
  TabBar() {
    Stack({ alignContent: Alignment.Top }) {
      // 玻璃高光：胶囊顶部受光边缘（深色下减弱高光）
      this.GlassHighlight('56%')
      // 悬浮选中指示胶囊：透明液态玻璃质感，随选中项平滑滞动到对应位置
      Column()
        .width(80)
        .height(48)
        .borderRadius(24)
        .backgroundColor(Theme.accentGlass(this.isDark))
        .backgroundBlurStyle(BlurStyle.Thin)
        .border({ width: 1, color: Theme.accentGlassBorder(this.isDark) })
        .shadow({
          radius: 10,
          color: this.isDark ? 'rgba(123,147,255,0.28)' : 'rgba(61,90,241,0.22)',
          offsetX: 0,
          offsetY: 3
        })
        // 基准位置：对齐第一个标签胶囊（行内边距 6 + 居中外框内缩 4）
        .position({ x: 10, y: 6 })
        // 每个标签宽 88，按选中索引横向平移，并叠加拖拽位移
        .translate({ x: 88 * this.activeTab + this.capsuleDragX, y: 0 })
        // 拖拽中关闭动画以实时跟手，松手后用弹簧曲线吸附到最近标签
        .animation(this.capsuleDragging
          ? { duration: 0, curve: Curve.Linear }
          : { duration: 420, curve: curves.springMotion(0.42, 0.72) })
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal, distance: 3 })
            .onActionStart(() => {
              this.capsuleDragging = true;
            })
            .onActionUpdate((event: GestureEvent) => {
              const base = 88 * this.activeTab;
              const max = 88 * (TABS.length - 1);
              let target = base + event.offsetX;
              // 超出两端时加橡皮筋阻尼
              if (target < 0) {
                target = target * 0.35;
              } else if (target > max) {
                target = max + (target - max) * 0.35;
              }
              this.capsuleDragX = target - base;
            })
            .onActionEnd(() => {
              const current = 88 * this.activeTab + this.capsuleDragX;
              let idx = Math.round(current / 88);
              idx = Math.max(0, Math.min(TABS.length - 1, idx));
              // 先退出拖拽态，使吸附以弹簧动画过渡
              this.capsuleDragging = false;
              this.capsuleDragX = 0;
              this.selectTab(idx);
            })
        )
      Row() {
        ForEach(TABS, (item: TabItem, idx: number) => {
          Column() {
            // 图标 + 文字（选中态由悬浮胶囊统一指示，此处不再单独铺底色）
            Column() {
              SymbolGlyph(item.icon)
                .fontSize(22)
                .fontWeight(this.activeTab === idx ? FontWeight.Medium : FontWeight.Normal)
                .fontColor([this.activeTab === idx ? Theme.accent(this.isDark) : Theme.inkTertiary(this.isDark)])
                .scale({
                  x: this.activeTab === idx ? 1.12 : 1,
                  y: this.activeTab === idx ? 1.12 : 1
                })
                .animation({ duration: 250, curve: Curve.Friction })
              Text(item.label)
                .fontSize(11)
                .fontWeight(this.activeTab === idx ? FontWeight.Medium : FontWeight.Normal)
                .fontColor(this.activeTab === idx ? Theme.accent(this.isDark) : Theme.inkTertiary(this.isDark))
                .margin({ top: 3 })
                .animation({ duration: 200, curve: Curve.EaseOut })
            }
            .width(80)
            .height(48)
            .justifyContent(FlexAlign.Center)
          }
          .width(88)
          .justifyContent(FlexAlign.Center)
          // 透明命中：不阻挡位于下层的悬浮胶囊接收拖拽手势（点击仍正常切页）
          .hitTestBehavior(HitTestMode.Transparent)
          .onClick(() => {
            this.selectTab(idx);
          })
        }, (item: TabItem) => item.label)
      }
      .padding({ top: 6, bottom: 6, left: 6, right: 6 })
      // 透明命中：允许位于 Row 之下的悬浮胶囊接收拖拽手势
      .hitTestBehavior(HitTestMode.Transparent)
    }
    // 玻璃质感：半透明底 + 背景模糊 + 高光描边（深色下为深色玻璃）
    .backgroundColor(Theme.glass(this.isDark))
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Theme.glassBorder(this.isDark) })
    .borderRadius(35)
    // 悬空阴影
    .shadow({ radius: 18, color: 'rgba(27,30,40,0.14)', offsetX: 0, offsetY: 8 })
    .margin({ left: 32, right: 32, bottom: -10 })
    // 滚动联动：上滑收起（下滑移出 + 淡出），下滑恢复
    .translate({ x: 0, y: this.tabBarHidden ? 120 : 0 })
    .opacity(this.tabBarHidden ? 0 : 1)
    .animation({ duration: 320, curve: Curve.Friction })
    // 以下形变属性置于 .animation 之后，避免被隐式动画拖慢跟手，改由 animateTo 精确控制
    // 拖拽：仅围绕中心原地拉伸/压扁形变，位置（中心）保持固定，点击不再触发果冻回弹
    .scale({ x: this.tabScaleX, y: this.tabScaleY })
    .gesture(
      PanGesture({ direction: PanDirection.Horizontal, distance: 5 })
        .onActionUpdate((event: GestureEvent) => {
          // 仅根据拖拽距离做克制的形变，不改变导航栏位置
          const clamped = Math.max(-48, Math.min(48, event.offsetX));
          const t = Math.abs(clamped) / 48;
          this.tabScaleX = 1 + t * 0.05;
          this.tabScaleY = 1 - t * 0.05;
        })
        .onActionEnd(() => {
          // 松手后弹簧回位
          animateTo({ duration: 400, curve: curves.springMotion(0.38, 0.6) }, () => {
            this.tabScaleX = 1;
            this.tabScaleY = 1;
          });
        })
    )
  }

  // 当前词库与学习进度卡片：液态玻璃 + 高光边缘 + 错峰入场
  @Builder
  CurrentBookCard() {
    Stack({ alignContent: Alignment.Top }) {
      this.GlassHighlight('44%')
      Column() {
        Row() {
          SymbolGlyph($r('sys.symbol.book'))
            .fontSize(26)
            .fontColor([Theme.accent(this.isDark)])
          Column() {
            Text(this.stats.name)
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.ink(this.isDark))
            Text(this.stats.subtitle)
              .fontSize(12)
              .fontColor(Theme.inkSecondary(this.isDark))
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 12 })
          Button('切换')
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .type(ButtonType.Capsule)
            .backgroundColor(Theme.accentGlass(this.isDark))
            .border({ width: 1, color: Theme.accentGlassBorder(this.isDark) })
            .fontColor(Theme.accent(this.isDark))
            .height(30)
            .padding({ left: 14, right: 14 })
            .onClick(() => {
              router.pushUrl({ url: 'pages/BookListPage' });
            })
        }
        .width('100%')

        // 学习进度条：已掌握 + 学习中（数值变化时平滑过渡）
        Progress({
          value: this.stats.mastered + this.stats.learning,
          total: this.stats.total,
          type: ProgressType.Linear
        })
          .style({ strokeWidth: 8 })
          .color(Theme.accent(this.isDark))
          .backgroundColor(Theme.line(this.isDark))
          .width('100%')
          .margin({ top: 18 })
          .animation({ duration: 600, curve: Curve.EaseOut })

        Row() {
          Circle({ width: 6, height: 6 })
            .fill(Theme.success(this.isDark))
          Text(`已掌握 ${this.stats.mastered}`)
            .fontSize(12)
            .fontColor(Theme.inkSecondary(this.isDark))
            .margin({ left: 5 })
          Blank()
          Circle({ width: 6, height: 6 })
            .fill(Theme.warning(this.isDark))
          Text(`学习中 ${this.stats.learning}`)
            .fontSize(12)
            .fontColor(Theme.inkSecondary(this.isDark))
            .margin({ left: 5 })
          Blank()
          Circle({ width: 6, height: 6 })
            .fill(Theme.inkTertiary(this.isDark))
          Text(`未学 ${this.stats.total - this.stats.mastered - this.stats.learning}`)
            .fontSize(12)
            .fontColor(Theme.inkSecondary(this.isDark))
            .margin({ left: 5 })
        }
        .width('100%')
        .margin({ top: 14 })
      }
      .width('100%')
      .padding(20)
    }
    // 与底部导航栏一致的玻璃质感：半透明底 + 背景模糊 + 高光描边 + 悬空阴影
    .backgroundColor(Theme.glass(this.isDark))
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Theme.glassBorder(this.isDark) })
    .borderRadius(24)
    .clip(true)
    .shadow({ radius: 18, color: 'rgba(27,30,40,0.14)', offsetX: 0, offsetY: 8 })
    .width('100%')
    .margin({ top: 16 })
    .translate({ y: this.homeEnter ? 0 : 36 })
    .opacity(this.homeEnter ? 1 : 0)
    .animation({ duration: 500, curve: Curve.Friction, delay: 90 })
  }

  // 已掌握卡片：成功色液态玻璃 + 按压反馈 + 错峰入场，可点击进入已掌握单词列表
  @Builder
  MasteredCard() {
    Stack({ alignContent: Alignment.Top }) {
      this.GlassHighlight('46%')
      Stack({ alignContent: Alignment.End }) {
        // 背景奖杯图案：与数字同色、略微倾斜的水印样式
        SymbolGlyph($r('sys.symbol.star_trophy'))
          .fontSize(64)
          .fontColor([Theme.success(this.isDark)])
          .opacity(0.35)
          .rotate({ angle: -15 })
          .margin({ right: 4 })

        Column() {
          Row() {
            Text(`${this.masteredCount}`)
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.success(this.isDark))
            Blank()
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(14)
              .fontColor([Theme.success(this.isDark)])
          }
          .width('100%')
          Text('已掌握')
            .fontSize(13)
            .fontColor(Theme.inkSecondary(this.isDark))
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }
      .width('100%')
      .padding(18)
    }
    .backgroundColor(Theme.successGlass(this.isDark))
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Theme.successGlassBorder(this.isDark) })
    .borderRadius(18)
    .clip(true)
    .shadow({ radius: 14, color: 'rgba(27,30,40,0.12)', offsetX: 0, offsetY: 6 })
    .layoutWeight(1)
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .onClick(() => {
      this.openMasteredList();
    })
    .translate({ y: this.homeEnter ? 0 : 36 })
    .opacity(this.homeEnter ? 1 : 0)
    .animation({ duration: 500, curve: Curve.Friction, delay: 340 })
  }

  // 学习中卡片：警告色液态玻璃 + 按压反馈 + 错峰入场，可点击进入学习中单词列表
  @Builder
  LearningCard() {
    Stack({ alignContent: Alignment.Top }) {
      this.GlassHighlight('46%')
      Stack({ alignContent: Alignment.End }) {
        // 背景书本图案：与数字同色、略微倾斜的水印样式
        SymbolGlyph($r('sys.symbol.book'))
          .fontSize(64)
          .fontColor([Theme.warning(this.isDark)])
          .opacity(0.35)
          .rotate({ angle: -15 })
          .margin({ right: 4 })

        Column() {
          Row() {
            Text(`${this.learningCount}`)
              .fontSize(28)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.warning(this.isDark))
            Blank()
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(14)
              .fontColor([Theme.warning(this.isDark)])
          }
          .width('100%')
          Text('学习中')
            .fontSize(13)
            .fontColor(Theme.inkSecondary(this.isDark))
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }
      .width('100%')
      .padding(18)
    }
    .backgroundColor(Theme.warningGlass(this.isDark))
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Theme.warningGlassBorder(this.isDark) })
    .borderRadius(18)
    .clip(true)
    .shadow({ radius: 14, color: 'rgba(27,30,40,0.12)', offsetX: 0, offsetY: 6 })
    .layoutWeight(1)
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .onClick(() => {
      this.openLearningList();
    })
    .translate({ y: this.homeEnter ? 0 : 36 })
    .opacity(this.homeEnter ? 1 : 0)
    .animation({ duration: 500, curve: Curve.Friction, delay: 400 })
  }

  // onScrollY：滚动位置回调，用于底部导航栏的收起/展开联动
  @Builder
  HomeView(onScrollY: (y: number) => void) {
    Column() {
        Stack() {
          // 生日蛋糕水印：生日当天在标题右上角展示，斜置半透明（与“已掌握”卡奖杯图案一致）
          if (this.isBirthday) {
            SymbolGlyph($r('sys.symbol.cake'))
              .fontSize(72)
              .fontColor([Theme.warning(this.isDark)])
              .opacity(0.35)
              .rotate({ angle: -15 })
              .align(Alignment.TopEnd)
              .margin({ top: 2, right: -250 })
          }
          Row() {
            Column() {
              // 生日当天标题替换为“生日快乐”
              Text(this.isBirthday ? '生日快乐' : '今日Yoji.')
                .fontSize(30)
                .fontWeight(FontWeight.Bold)
                .fontColor(Theme.ink(this.isDark))
              Text(this.dateLabel())
                .fontSize(14)
                .fontColor(Theme.inkSecondary(this.isDark))
                .margin({ top: 6 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 24, right: 24, top: 24, bottom: 8 })
        }
        .width('100%')

        Scroll() {
          Column() {
            // 今日进度卡：液态玻璃 + 高光边缘 + 最先入场
            Stack({ alignContent: Alignment.Top }) {
              this.GlassHighlight('52%')
              Column() {
                Row() {
                  Column() {
                    Text('今日目标')
                      .fontSize(14)
                      .fontColor(Theme.inkSecondary(this.isDark))
                    Row() {
                      Text(`${this.todayLearned}`)
                        .fontSize(44)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Theme.ink(this.isDark))
                      Text(` / ${this.dailyTarget}`)
                        .fontSize(20)
                        .fontColor(Theme.inkTertiary(this.isDark))
                        .margin({ bottom: 8 })
                    }
                    .alignItems(VerticalAlign.Bottom)
                    .margin({ top: 10 })
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)

                  // 进度环：数值变化时平滑过渡；目标达成后中心展示金色奖杯
                  Stack() {
                    Progress({
                      value: this.todayLearned,
                      total: this.dailyTarget,
                      type: ProgressType.Ring
                    })
                      .style({ strokeWidth: 10 })
                      .color(this.goalDone ? Theme.warning(this.isDark) : Theme.accent(this.isDark))
                      .backgroundColor(Theme.line(this.isDark))
                      .width(76)
                      .height(76)
                      .animation({ duration: 600, curve: Curve.EaseOut })

                    if (this.goalDone) {
                      // 金色光晕：径向渐变圆形，静态常亮显示
                      Circle()
                        .width(66)
                        .height(66)
                        .radialGradient({
                          center: ['50%', '50%'],
                          radius: '50%',
                          colors: [[this.isDark ? 'rgba(251,191,36,0.55)' : 'rgba(245,158,11,0.45)', 0],
                            ['rgba(251,191,36,0)', 1]]
                        })
                        .opacity(1)
                        .scale({ x: this.trophyScale, y: this.trophyScale })
                      // 奖杯：金色填充符号，随入场动画缩放摆动
                      SymbolGlyph($r('sys.symbol.star_trophy_fill'))
                        .fontSize(32)
                        .fontColor([this.isDark ? '#FCD34D' : '#F59E0B'])
                        .scale({ x: this.trophyScale, y: this.trophyScale })
                        .rotate({ angle: this.trophyRotate })
                    }
                  }
                  .width(76)
                  .height(76)
                }
                .width('100%')

                Row() {
                  Text(`连续学习 ${this.streak} 天`)
                    .fontSize(13)
                    .fontColor(Theme.inkSecondary(this.isDark))
                  Blank()
                  Text(`累计掌握 ${this.totalLearned} 词`)
                    .fontSize(13)
                    .fontColor(Theme.inkSecondary(this.isDark))
                }
                .width('100%')
                .margin({ top: 20 })
              }
              .width('100%')
              .padding(24)
            }
            // 与底部导航栏一致的玻璃质感：半透明底 + 背景模糊 + 高光描边 + 悬空阴影
            .backgroundColor(Theme.glass(this.isDark))
            .backgroundBlurStyle(BlurStyle.Thin)
            .border({ width: 1, color: Theme.glassBorder(this.isDark) })
            .borderRadius(24)
            .clip(true)
            .shadow({ radius: 18, color: 'rgba(27,30,40,0.14)', offsetX: 0, offsetY: 8 })
            .width('100%')
            .translate({ y: this.homeEnter ? 0 : 36 })
            .opacity(this.homeEnter ? 1 : 0)
            .animation({ duration: 500, curve: Curve.Friction, delay: 0 })

            // 当前词库与学习进度
            this.CurrentBookCard()

            // 学习入口：液态玻璃按钮（主按钮带主色光晕阴影，保留原生按压动效）
            Row({ space: 12 }) {
              Button('开始学习')
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
                .layoutWeight(1)
                .height(52)
                .onClick(() => {
                  this.startLearn('learn');
                })
              Button('快速复习')
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .type(ButtonType.Capsule)
                .backgroundColor(Theme.glass(this.isDark))
                .backgroundBlurStyle(BlurStyle.Thin)
                .border({ width: 1, color: Theme.glassBorder(this.isDark) })
                .fontColor(Theme.accent(this.isDark))
                .shadow({ radius: 12, color: 'rgba(27,30,40,0.12)', offsetX: 0, offsetY: 6 })
                .layoutWeight(1)
                .height(52)
                .onClick(() => {
                  this.startLearn('review');
                })
            }
            .width('100%')
            .margin({ top: 16 })
            .translate({ y: this.homeEnter ? 0 : 36 })
            .opacity(this.homeEnter ? 1 : 0)
            .animation({ duration: 500, curve: Curve.Friction, delay: 180 })

            // 掌握情况（标题随模块一同入场）
            Text('掌握情况')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.ink(this.isDark))
              .margin({ top: 28 })
              .width('100%')
              .translate({ y: this.homeEnter ? 0 : 24 })
              .opacity(this.homeEnter ? 1 : 0)
              .animation({ duration: 500, curve: Curve.Friction, delay: 260 })

            Row({ space: 12 }) {
              this.MasteredCard()
              this.LearningCard()
            }
            .width('100%')
            .margin({ top: 12 })
          }
          // 底部留白加大，避免内容被悬浮导航栏遮挡
          .padding({ left: 24, right: 24, bottom: 104 })
          .constraintSize({ minHeight: '100%' })
          .justifyContent(FlexAlign.Start)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .onDidScroll((xOffset: number, yOffset: number, scrollState: ScrollState) => {
          onScrollY(yOffset);
        })
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        if (this.activeTab === 0) {
          this.HomeView((y: number): void => {
            this.handleScroll(y);
          })
        } else if (this.activeTab === 1) {
          VideoListView({ onScrollY: (y: number): void => {
            this.handleScroll(y);
          } })
        } else {
          MineView({
            tick: this.tick,
            onMutate: (): void => {
              this.mutate();
            },
            onScrollY: (y: number): void => {
              this.handleScroll(y);
            }
          })
        }
      }
      .width('100%')
      .height('100%')

      // 底部导航栏悬浮于内容之上，随滚动联动收起/展开
      this.TabBar()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg(this.isDark))
    // 背景延伸到系统底部导航条下方，避免底部出现割裂色带
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
