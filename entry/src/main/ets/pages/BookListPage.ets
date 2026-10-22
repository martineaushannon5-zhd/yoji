import { router } from '@kit.ArkUI';
import { BookListView } from '../view/BookListView';
import { Theme } from '../common/Theme';
import { loadRemoteWordBooks } from '../data/WordData';

// 词库页面：由“我的-当前词书”或首页“切换”按钮进入
@Entry
@Component
struct BookListPage {
  @State tick: number = 0;
  @State refreshing: boolean = false;
  // 深色模式开关：双向绑定 AppStorage，切换后页面配色同步刷新
  @StorageLink('darkMode') isDark: boolean = false;

  private async refreshWordBooks(): Promise<void> {
    if (this.refreshing) {
      return;
    }
    this.refreshing = true;
    await loadRemoteWordBooks();
    this.tick += 1;
    this.refreshing = false;
  }

  build() {
    Column() {
      // 顶栏：返回 + 标题
      Row() {
        Column() {
          SymbolGlyph($r('sys.symbol.chevron_left'))
            .fontSize(20)
            .fontColor([Theme.ink(this.isDark)])
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          router.back();
        })
        Text('词库')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.ink(this.isDark))
          .margin({ left: 4 })
        Blank()
        Text(this.refreshing ? '刷新中…' : '刷新')
          .fontSize(13)
          .fontColor(Theme.accent(this.isDark))
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .onClick(() => {
            this.refreshWordBooks();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 8, bottom: 4 })

      Column() {
        BookListView({
          tick: this.tick,
          showTitle: false,
          onMutate: (): void => {
            this.tick += 1;
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg(this.isDark))
  }
}
