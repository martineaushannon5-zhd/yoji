import { router } from '@kit.ArkUI';
import { BOOKS } from '../data/WordData';
import { Store } from '../store/Store';
import { Theme } from '../common/Theme';
import { Word } from '../model/WordModel';

// 错词本列表项
interface WrongItem {
  word: Word;
  bookName: string;
  count: number;
  lastAt: string;
  level: number;
}

// 错词本：汇总学习/复习中答错过的单词，并提供「开始复习」入口
@Entry
@Component
struct WrongWordsPage {
  @State items: WrongItem[] = [];
  @State dueCount: number = 0;
  @StorageLink('darkMode') isDark: boolean = false;
  private store: Store = Store.get();
  private wordIndex: Record<string, Word> = {};
  private bookIndex: Record<string, string> = {};

  aboutToAppear(): void {
    this.buildIndex();
    this.rebuild();
  }

  onPageShow(): void {
    this.rebuild();
  }

  // 建立 wordId -> 单词 / 词书名的索引，避免逐条遍历全部词库
  private buildIndex(): void {
    const wordIndex: Record<string, Word> = {};
    const bookIndex: Record<string, string> = {};
    for (let b = 0; b < BOOKS.length; b++) {
      const book = BOOKS[b];
      for (let w = 0; w < book.words.length; w++) {
        const word = book.words[w];
        wordIndex[word.id] = word;
        bookIndex[word.id] = book.name;
      }
    }
    this.wordIndex = wordIndex;
    this.bookIndex = bookIndex;
  }

  private rebuild(): void {
    const ids = this.store.wrongWordIds();
    const list: WrongItem[] = [];
    for (let i = 0; i < ids.length; i++) {
      const id = ids[i];
      const word = this.wordIndex[id];
      if (word === undefined) {
        continue;
      }
      const item: WrongItem = {
        word: word,
        bookName: this.bookIndex[id] ?? '',
        count: this.store.wrongCount[id] ?? 0,
        lastAt: this.store.wrongMap[id] ?? '',
        level: this.store.reviewLevel[id] ?? 0
      };
      list.push(item);
    }
    this.items = list;
    this.dueCount = this.store.dueCount();
  }

  private async onMaster(item: WrongItem): Promise<void> {
    await this.store.masterWord(item.word.id);
    this.rebuild();
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
      Text('错词本')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.ink(this.isDark))
      Blank()
      Text(`${this.items.length} 词`)
        .fontSize(13)
        .fontColor(Theme.inkSecondary(this.isDark))
    }
    .width('100%')
    .padding({ left: 8, right: 24, top: 8, bottom: 8 })
  }

  // 顶部统计 + 开始复习按钮
  @Builder
  Summary() {
    Column() {
      Row({ space: 28 }) {
        Column() {
          Text(`${this.items.length}`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.ink(this.isDark))
          Text('错词')
            .fontSize(12)
            .fontColor(Theme.inkTertiary(this.isDark))
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)

        Column() {
          Text(`${this.dueCount}`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.dueCount > 0 ? Theme.accent(this.isDark) : Theme.ink(this.isDark))
          Text('今日待复习')
            .fontSize(12)
            .fontColor(Theme.inkTertiary(this.isDark))
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')

      Text('按遗忘曲线安排复习：答对一次延长间隔，走完 6 级即视为真正掌握。')
        .fontSize(12)
        .fontColor(Theme.inkTertiary(this.isDark))
        .margin({ top: 10 })
        .width('100%')

      Button(this.dueCount > 0 ? `开始复习（${this.dueCount}）` : '今天没有待复习的词')
        .width('100%')
        .height(46)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor(this.dueCount > 0 ? Theme.accent(this.isDark) : Theme.line(this.isDark))
        .borderRadius(23)
        .margin({ top: 16 })
        .enabled(this.dueCount > 0)
        .onClick(() => {
          router.pushUrl({ url: 'pages/ReviewPage' });
        })
    }
    .width('100%')
    .padding(20)
    .backgroundColor(Theme.glass(this.isDark))
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Theme.glassBorder(this.isDark) })
    .borderRadius(18)
    .shadow({ radius: 12, color: 'rgba(27,30,40,0.12)', offsetX: 0, offsetY: 6 })
    .margin({ left: 24, right: 24, bottom: 14 })
  }

  @Builder
  EmptyView() {
    Column() {
      SymbolGlyph($r('sys.symbol.checkmark_circle'))
        .fontSize(48)
        .fontColor([Theme.inkTertiary(this.isDark)])
      Text('错词本还是空的')
        .fontSize(16)
        .fontColor(Theme.inkSecondary(this.isDark))
        .margin({ top: 16 })
      Text('学习或复习时答错的词会自动收进来')
        .fontSize(13)
        .fontColor(Theme.inkTertiary(this.isDark))
        .margin({ top: 6 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column() {
      this.TopBar()
      this.Summary()
      if (this.items.length > 0) {
        List({ space: 12 }) {
          ForEach(this.items, (item: WrongItem) => {
            ListItem() {
              Row() {
                Column() {
                  Row() {
                    Text(item.word.word)
                      .fontSize(18)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Theme.ink(this.isDark))
                    Text(item.word.phonetic)
                      .fontSize(12)
                      .fontColor(Theme.inkTertiary(this.isDark))
                      .margin({ left: 8 })
                    Text(`错 ${item.count} 次`)
                      .fontSize(10)
                      .fontColor(Theme.danger(this.isDark))
                      .backgroundColor(Theme.dangerSoft(this.isDark))
                      .borderRadius(6)
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .margin({ left: 8 })
                  }
                  .alignItems(VerticalAlign.Center)

                  Text(item.word.meaning)
                    .fontSize(14)
                    .fontColor(Theme.inkSecondary(this.isDark))
                    .margin({ top: 8 })
                    .width('100%')

                  Row() {
                    Text(item.bookName)
                      .fontSize(11)
                      .fontColor(Theme.inkTertiary(this.isDark))
                    Text(`复习等级 ${item.level}/6`)
                      .fontSize(11)
                      .fontColor(Theme.inkTertiary(this.isDark))
                      .margin({ left: 10 })
                    if (item.lastAt !== '') {
                      Text(`最近答错 ${item.lastAt}`)
                        .fontSize(11)
                        .fontColor(Theme.inkTertiary(this.isDark))
                        .margin({ left: 10 })
                    }
                  }
                  .width('100%')
                  .margin({ top: 8 })
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Text('已掌握')
                  .fontSize(12)
                  .fontColor(Theme.accent(this.isDark))
                  .backgroundColor(Theme.accentSoft(this.isDark))
                  .borderRadius(14)
                  .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                  .margin({ left: 8 })
                  .onClick(() => {
                    this.onMaster(item);
                  })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              .backgroundColor(Theme.glass(this.isDark))
              .backgroundBlurStyle(BlurStyle.Thin)
              .border({ width: 1, color: Theme.glassBorder(this.isDark) })
              .borderRadius(18)
              .shadow({ radius: 12, color: 'rgba(27,30,40,0.12)', offsetX: 0, offsetY: 6 })
              .padding(16)
            }
          }, (item: WrongItem) => `${item.word.id}-${item.count}-${item.level}`)
        }
        .layoutWeight(1)
        .padding({ left: 24, right: 24, bottom: 24 })
        .scrollBar(BarState.Off)
      } else {
        this.EmptyView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg(this.isDark))
  }
}