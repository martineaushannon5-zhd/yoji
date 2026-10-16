import { router } from '@kit.ArkUI';
import { BOOKS, getBook } from '../data/WordData';
import { Store } from '../store/Store';
import { Theme } from '../common/Theme';
import { STATUS_MASTERED, WordBook } from '../model/WordModel';

@Component
export struct BookListView {
  @Prop tick: number = 0;
  // 作为独立页面使用时，由页面顶栏展示标题，此处隐藏内置标题
  @Prop showTitle: boolean = true;
  onMutate: () => void = (): void => {};

  private store: Store = Store.get();

  private learnedCount(book: WordBook): number {
    let n = 0;
    for (let i = 0; i < book.words.length; i++) {
      if (this.store.statusOf(book.words[i].id) === STATUS_MASTERED) {
        n += 1;
      }
    }
    return n;
  }

  private selectBook(bookId: string): void {
    this.store.setCurrentBook(bookId);
    this.onMutate();
  }

  private startLearn(bookId: string): void {
    this.store.setCurrentBook(bookId);
    router.pushUrl({
      url: 'pages/LearnPage',
      params: { bookId: bookId, mode: 'learn' }
    });
  }

  build() {
    Column() {
      if (this.showTitle) {
        Text('词库')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.ink)
          .padding({ left: 24, top: 24, bottom: 8 })
          .width('100%')
      }

      Scroll() {
        Column({ space: 14 }) {
          ForEach(BOOKS, (book: WordBook) => {
            Column() {
              Row() {
                Column() {
                  Text(book.name)
                    .fontSize(19)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.ink)
                  Text(book.subtitle)
                    .fontSize(13)
                    .fontColor(Theme.inkSecondary)
                    .margin({ top: 5 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                if (this.store.currentBookId === book.id) {
                  Text('使用中')
                    .fontSize(12)
                    .fontColor(Theme.accent)
                    .backgroundColor(Theme.accentSoft)
                    .borderRadius(10)
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                } else {
                  Text('选择')
                    .fontSize(12)
                    .fontColor(Theme.inkSecondary)
                    .border({ width: 1, color: Theme.line, radius: 10 })
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                }
              }
              .width('100%')

              // 进度条
              Stack({ alignContent: Alignment.Start }) {
                Row()
                  .width('100%')
                  .height(6)
                  .borderRadius(3)
                  .backgroundColor(Theme.line)
                Row()
                  .width(`${Math.round(this.learnedCount(book) * 100 / book.words.length)}%`)
                  .height(6)
                  .borderRadius(3)
                  .backgroundColor(Theme.accent)
              }
              .width('100%')
              .margin({ top: 18 })

              Row() {
                Text(`已掌握 ${this.learnedCount(book)} / ${book.words.length}`)
                  .fontSize(13)
                  .fontColor(Theme.inkSecondary)
                Blank()
                Button('开始学习')
                  .fontSize(13)
                  .type(ButtonType.Capsule)
                  .backgroundColor(Theme.accent)
                  .height(34)
                  .padding({ left: 16, right: 16 })
                  .onClick(() => {
                    this.startLearn(book.id);
                  })
              }
              .width('100%')
              .margin({ top: 12 })
            }
            .backgroundColor(Theme.card)
            .borderRadius(22)
            .padding(20)
            .width('100%')
            .onClick(() => {
              this.selectBook(book.id);
            })
          }, (book: WordBook) => `${book.id}-${this.tick}`)
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
}
