import { router } from '@kit.ArkUI';
import { Store } from '../store/Store';
import { Theme } from '../common/Theme';
import { getBook } from '../data/WordData';

const TARGET_OPTIONS: number[] = [5, 10, 15, 20, 30, 50];

// 自定义每日目标弹窗
@CustomDialog
struct TargetInputDialog {
  controller: CustomDialogController;
  onConfirm: (value: number) => void = (): void => {};
  @State value: string = '';

  build() {
    Column({ space: 16 }) {
      Text('自定义每日目标')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.ink)
      TextInput({ placeholder: '请输入每天学习的单词数（5-50）', text: this.value })
        .type(InputType.Number)
        .height(48)
        .fontSize(15)
        .backgroundColor(Theme.bg)
        .borderRadius(12)
        .padding({ left: 14, right: 14 })
        .onChange((v: string) => {
          this.value = v;
        })
      Row({ space: 12 }) {
        Button('取消')
          .fontSize(15)
          .type(ButtonType.Capsule)
          .backgroundColor(Theme.bg)
          .fontColor(Theme.ink)
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            this.controller.close();
          })
        Button('确定')
          .fontSize(15)
          .type(ButtonType.Capsule)
          .backgroundColor(Theme.accent)
          .layoutWeight(1)
          .height(44)
          .onClick(() => {
            const v = Number(this.value);
            if (v >= 5 && v <= 50) {
              this.onConfirm(v);
              this.controller.close();
            }
          })
      }
      .width('100%')
    }
    .padding(24)
  }
}

@Component
export struct MineView {
  // tick 由首页在 onPageShow（如从词库页返回）时自增，@Watch 触发快照同步刷新 UI
  @Prop @Watch('syncFromStore') tick: number = 0;
  @State target: number = 0;
  // 展示数据快照：Store 为非响应式单例，需同步到 @State 才能驱动刷新
  @State bookName: string = '';
  @State isLoggedIn: boolean = false;
  @State nickname: string = '';
  @State totalLearned: number = 0;
  @State learnedDays: number = 0;
  @State favCount: number = 0;
  onMutate: () => void = (): void => {};

  private store: Store = Store.get();
  private targetDialog: CustomDialogController | undefined = undefined;

  aboutToAppear(): void {
    this.syncFromStore();
    this.targetDialog = new CustomDialogController({
      builder: TargetInputDialog({
        onConfirm: (v: number): void => {
          this.store.setDailyTarget(v);
          this.target = v;
          this.onMutate();
        }
      }),
      autoCancel: true
    });
  }

  // 从 Store 同步最新展示数据（进入页面与 tick 变化时调用）
  private syncFromStore(): void {
    this.target = this.store.dailyTarget;
    this.bookName = getBook(this.store.currentBookId).name;
    this.isLoggedIn = this.store.isLoggedIn;
    this.nickname = this.store.nickname;
    this.totalLearned = this.store.totalLearned;
    this.learnedDays = this.store.learnedDays;
    this.favCount = Object.keys(this.store.favorites).length;
  }

  // 当前目标是否为自定义值（不在预设选项内）
  private isCustomTarget(): boolean {
    return TARGET_OPTIONS.indexOf(this.target) < 0;
  }

  // 未登录时跳转登录页
  private goLogin(): void {
    router.pushUrl({ url: 'pages/LoginPage' });
  }

  // 用户信息卡：头像 + 昵称（或“请先登录”），下方为学习数据统计
  @Builder
  UserCard() {
    Column() {
      Row() {
        // ⚠️【头像占位】接入后端后，若 this.store.avatar 非空，可改为：
        //   Image(this.store.avatar).width(64).height(64).borderRadius(32)
        Column() {
          SymbolGlyph($r('sys.symbol.person'))
            .fontSize(28)
            .fontColor([Color.White])
        }
        .width(64)
        .height(64)
        .borderRadius(32)
        .backgroundColor(this.isLoggedIn ? Theme.accent : '#B8C0CE')
        .justifyContent(FlexAlign.Center)

        Column() {
          Text(this.isLoggedIn ? this.nickname : '请先登录')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.ink)
          Text(this.isLoggedIn ? '已登录' : '登录后同步你的学习进度')
            .fontSize(12)
            .fontColor(Theme.inkSecondary)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 14 })

        if (!this.isLoggedIn) {
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(18)
            .fontColor([Theme.inkSecondary])
        }
      }
      .width('100%')
      .onClick(() => {
        if (!this.isLoggedIn) {
          this.goLogin();
        }
      })

      Divider()
        .strokeWidth(1)
        .color('#EEF0F4')
        .margin({ top: 16, bottom: 14 })

      // 学习数据统计
      Row() {
        // 学习单词：右下角绿色书本水印（与首页“学习中”图案一致），点击跳转已掌握列表
        Stack() {
          SymbolGlyph($r('sys.symbol.book'))
            // ⚠️【图案大小】修改此 fontSize 即可调整图案大小（当前 56）
            .fontSize(56)
            .fontColor([Theme.success])
            .opacity(0.35)
            .rotate({ angle: -15 })
            .margin({ right: 4 })
            .align(Alignment.BottomEnd)
          Column() {
            Text(`${this.totalLearned}`)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.ink)
            Text('学习单词')
              .fontSize(12)
              .fontColor(Theme.inkSecondary)
              .margin({ top: 4 })
          }
          .width('100%')
        }
        // 固定高度 + 裁剪：图案改大也不会撑大按钮，超出部分显示不全
        .height(52)
        .clip(true)
        .layoutWeight(1)
        .onClick(() => {
          // 点击“学习单词”跳转到已掌握单词列表页
          router.pushUrl({ url: 'pages/WordListPage' });
        })

        Divider()
          .vertical(true)
          .height(36)
          .strokeWidth(1)
          .color('#EEF0F4')

        // 坚持天数：右下角橙色火焰水印（与学习日历坚持天数图标一致），点击跳转学习日历
        Stack() {
          SymbolGlyph($r('sys.symbol.flame'))
            // ⚠️【图案大小】修改此 fontSize 即可调整图案大小（当前 52）
            .fontSize(52)
            .fontColor([Theme.warning])
            .opacity(0.35)
            .rotate({ angle: -15 })
            .margin({ right: 4 })
            .align(Alignment.BottomEnd)
          Column() {
            Text(`${this.learnedDays}`)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(Theme.ink)
            Text('坚持天数')
              .fontSize(12)
              .fontColor(Theme.inkSecondary)
              .margin({ top: 4 })
          }
          .width('100%')
        }
        // 固定高度 + 裁剪：图案改大也不会撑大按钮，超出部分显示不全
        .height(52)
        .clip(true)
        .layoutWeight(1)
        .onClick(() => {
          // 点击“坚持天数”跳转到学习日历页
          router.pushUrl({ url: 'pages/CalendarPage' });
        })
      }
      .width('100%')
    }
    .backgroundColor(Theme.card)
    .borderRadius(18)
    .padding(20)
    .width('100%')
  }

  build() {
    Column() {
      Text('我的')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.ink)
        .padding({ left: 24, top: 24, bottom: 8 })
        .width('100%')

      Scroll() {
        Column() {
          // 用户信息与学习数据
          this.UserCard()

          // 学习日历入口
          Row() {
            SymbolGlyph($r('sys.symbol.calendar'))
              .fontSize(20)
              .fontColor([Theme.accent])
            Text('学习日历')
              .fontSize(15)
              .fontColor(Theme.ink)
              .layoutWeight(1)
              .margin({ left: 12 })
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(14)
              .fontColor([Theme.inkTertiary])
          }
          .width('100%')
          .backgroundColor(Theme.card)
          .borderRadius(18)
          .padding(20)
          .margin({ top: 14 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/CalendarPage' });
          })

          // 单词本入口：查看收藏的单词
          Row() {
            SymbolGlyph($r('sys.symbol.star'))
              .fontSize(20)
              .fontColor([Theme.accent])
            Text('单词本')
              .fontSize(15)
              .fontColor(Theme.ink)
              .layoutWeight(1)
              .margin({ left: 12 })
            Text(`已收藏 ${this.favCount}个单词`)
              .fontSize(15)
              .fontColor(Theme.inkSecondary)
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(14)
              .fontColor([Theme.inkTertiary])
              .margin({ left: 6 })
          }
          .width('100%')
          .backgroundColor(Theme.card)
          .borderRadius(18)
          .padding(20)
          .margin({ top: 14 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/FavoritePage' });
          })

          // 当前词书：点击进入词库
          Row() {
            SymbolGlyph($r('sys.symbol.book'))
              .fontSize(20)
              .fontColor([Theme.accent])
            Text('当前词库')
              .fontSize(15)
              .fontColor(Theme.ink)
              .layoutWeight(1)
              .margin({ left: 12 })
            Text(this.bookName)
              .fontSize(15)
              .fontColor(Theme.inkSecondary)
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(14)
              .fontColor([Theme.inkTertiary])
              .margin({ left: 6 })
          }
          .width('100%')
          .backgroundColor(Theme.card)
          .borderRadius(18)
          .padding(20)
          .margin({ top: 14 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/BookListPage' });
          })

          // 每日目标
          Column() {
            Row() {
              SymbolGlyph($r('sys.symbol.flag'))
                .fontSize(20)
                .fontColor([Theme.accent])
              Text('每日目标')
                .fontSize(15)
                .fontColor(Theme.ink)
                .margin({ left: 12 })
            }
            .width('100%')
            Row({ space: 10 }) {
              ForEach(TARGET_OPTIONS, (n: number) => {
                Text(`${n}`)
                  .fontSize(14)
                  .fontColor(this.target === n ? Color.White : Theme.inkSecondary)
                  .backgroundColor(this.target === n ? Theme.accent : Theme.bg)
                  .borderRadius(12)
                  .textAlign(TextAlign.Center)
                  .height(36)
                  .layoutWeight(1)
                  .onClick(() => {
                    // 保存到全局存储，并更新本地状态立即高亮；onMutate 通知今日页同步刷新
                    this.store.setDailyTarget(n);
                    this.target = n;
                    this.onMutate();
                  })
              }, (n: number) => `${n}`)
            }
            .width('100%')
            .margin({ top: 14 })

            // 自定义目标入口：目标不在预设内时高亮提示
            Row() {
              Text(this.isCustomTarget() ? `自定义目标：${this.target} 词` : '自定义目标')
                .fontSize(14)
                .fontColor(this.isCustomTarget() ? Theme.accent : Theme.inkSecondary)
                .fontWeight(this.isCustomTarget() ? FontWeight.Medium : FontWeight.Normal)
                .layoutWeight(1)
              SymbolGlyph($r('sys.symbol.chevron_right'))
                .fontSize(14)
                .fontColor([this.isCustomTarget() ? Theme.accent : Theme.inkTertiary])
            }
            .width('100%')
            .margin({ top: 14 })
            .onClick(() => {
              if (this.targetDialog) {
                this.targetDialog.open();
              }
            })
          }
          .backgroundColor(Theme.card)
          .borderRadius(18)
          .padding(20)
          .width('100%')
          .margin({ top: 14 })

          // 关于与数据入口
          Row() {
            SymbolGlyph($r('sys.symbol.info_circle'))
              .fontSize(20)
              .fontColor([Theme.accent])
            Text('关于与数据')
              .fontSize(15)
              .fontColor(Theme.ink)
              .layoutWeight(1)
              .margin({ left: 12 })
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(14)
              .fontColor([Theme.inkTertiary])
          }
          .width('100%')
          .backgroundColor(Theme.card)
          .borderRadius(18)
          .padding(20)
          .margin({ top: 14, bottom: 24 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/AboutPage' });
          })
        }
        .padding({ left: 24, right: 24 })
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
}
