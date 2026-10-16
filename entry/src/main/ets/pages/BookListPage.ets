import { router } from '@kit.ArkUI';
import { BookListView } from '../view/BookListView';
import { Theme } from '../common/Theme';
import { ThemeToggle } from '../view/ThemeToggle';

// 词库页面：由“我的-当前词书”或首页“切换”按钮进入
@Entry
@Component
struct BookListPage {
  @State tick: number = 0;
  // 深色模式开关：双向绑定 AppStorage，切换后页面配色同步刷新
  @StorageLink('darkMode') isDark: boolean = false;

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
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        // 右上角月亮按钮：与标题行对齐，点击切换深色/浅色模式
        ThemeToggle()
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
