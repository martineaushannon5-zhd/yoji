import { router } from '@kit.ArkUI';
import { BOOKS } from '../data/WordData';
import { Store } from '../store/Store';
import { Theme } from '../common/Theme';
import { ThemeToggle } from '../view/ThemeToggle';
import { Word } from '../model/WordModel';

// 排序方式：0 收藏时间，1 首字母，2 词库
const SORT_OPTIONS: string[] = ['收藏时间', '首字母', '词库'];

// 单词本列表项
interface FavoriteItem {
  word: Word;
  bookName: string;
  order: number;
  pos: string;
  meaning: string;
  favoritedAt: string;
  favorited: boolean;
}

interface MeaningPart {
  pos: string;
  text: string;
}

// 拆分释义中的词性与释义，如 "v. 放弃，抛弃" -> "v." + "放弃，抛弃"
function splitMeaning(raw: string): MeaningPart {
  let i = 0;
  let lastDot = -1;
  while (i < raw.length) {
    const ch = raw.charAt(i);
    const isLetter = (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
    if (isLetter || ch === '.' || ch === '/') {
      if (ch === '.') {
        lastDot = i;
      }
      i += 1;
    } else {
      break;
    }
  }
  if (lastDot > 0) {
    const part: MeaningPart = {
      pos: raw.substring(0, lastDot + 1),
      text: raw.substring(i).trim()
    };
    return part;
  }
  const fallback: MeaningPart = { pos: '', text: raw };
  return fallback;
}

@Entry
@Component
struct FavoritePage {
  @State items: FavoriteItem[] = [];
  @State shown: FavoriteItem[] = [];
  @State keyword: string = '';
  @State sortMode: number = 0;
  // 深色模式开关：双向绑定 AppStorage，切换后页面配色同步刷新
  @StorageLink('darkMode') isDark: boolean = false;
  private store: Store = Store.get();

  aboutToAppear(): void {
    this.rebuild();
  }

  // 从 Store 收藏表重建列表数据
  private rebuild(): void {
    const list: FavoriteItem[] = [];
    let order = 0;
    for (let b = 0; b < BOOKS.length; b++) {
      const book = BOOKS[b];
      for (let w = 0; w < book.words.length; w++) {
        const word = book.words[w];
        if (this.store.isFavorite(word.id)) {
          const part = splitMeaning(word.meaning);
          const item: FavoriteItem = {
            word: word,
            bookName: book.name,
            order: order,
            pos: part.pos,
            meaning: part.text,
            favoritedAt: this.store.favorites[word.id] ?? '',
            favorited: true
          };
          order += 1;
          list.push(item);
        }
      }
    }
    this.items = list;
    this.applyFilterAndSort();
  }

  // 按搜索关键词过滤并按当前排序方式排序
  private applyFilterAndSort(): void {
    let list: FavoriteItem[] = this.items.slice();
    const kw = this.keyword.trim().toLowerCase();
    if (kw !== '') {
      list = list.filter((it: FavoriteItem): boolean => {
        return it.word.word.toLowerCase().indexOf(kw) >= 0 ||
          it.meaning.toLowerCase().indexOf(kw) >= 0;
      });
    }
    if (this.sortMode === 0) {
      // 按收藏日期从新到旧，无日期记录排最后
      list.sort((a: FavoriteItem, b: FavoriteItem): number => {
        if (a.favoritedAt === b.favoritedAt) {
          return a.order - b.order;
        }
        if (a.favoritedAt === '') {
          return 1;
        }
        if (b.favoritedAt === '') {
          return -1;
        }
        return a.favoritedAt < b.favoritedAt ? 1 : -1;
      });
    } else if (this.sortMode === 1) {
      // 按英文首字母升序
      list.sort((a: FavoriteItem, b: FavoriteItem): number => {
        const c = a.word.word.toLowerCase().localeCompare(b.word.word.toLowerCase());
        return c !== 0 ? c : a.order - b.order;
      });
    } else {
      // 按词库分组，组内保持词书原有顺序
      list.sort((a: FavoriteItem, b: FavoriteItem): number => {
        return a.order - b.order;
      });
    }
    this.shown = list;
  }

  // 切换收藏状态；取消收藏后从单词本移除
  private async onToggleFav(item: FavoriteItem): Promise<void> {
    await this.store.toggleFavorite(item.word.id);
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
      Text('单词本')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.ink(this.isDark))
      Blank()
      Text(`${this.shown.length} 词`)
        .fontSize(13)
        .fontColor(Theme.inkSecondary(this.isDark))
      // 右上角月亮按钮：与标题行对齐，点击切换深色/浅色模式
      ThemeToggle()
        .margin({ left: 10 })
    }
    .width('100%')
    .padding({ left: 8, right: 24, top: 8, bottom: 8 })
  }

  @Builder
  SearchAndSort() {
    Column() {
      Search({ value: this.keyword, placeholder: '搜索单词或释义' })
        .height(42)
        .fontColor(Theme.ink(this.isDark))
        .placeholderColor(Theme.inkTertiary(this.isDark))
        .backgroundColor(Theme.card(this.isDark))
        .borderRadius(21)
        .onChange((value: string) => {
          this.keyword = value;
          this.applyFilterAndSort();
        })

      Row({ space: 8 }) {
        ForEach(SORT_OPTIONS, (opt: string, i: number) => {
          Text(opt)
            .fontSize(12)
            .fontWeight(this.sortMode === i ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.sortMode === i ? Theme.accent(this.isDark) : Theme.inkSecondary(this.isDark))
            .backgroundColor(this.sortMode === i ? Theme.accentSoft(this.isDark) : Theme.card(this.isDark))
            .borderRadius(15)
            .padding({ left: 12, right: 12, top: 5, bottom: 5 })
            .onClick(() => {
              this.sortMode = i;
              this.applyFilterAndSort();
            })
        }, (opt: string) => opt)
      }
      .margin({ top: 10 })
    }
    .width('100%')
    .padding({ left: 24, right: 24, bottom: 12 })
  }

  @Builder
  EmptyView() {
    Column() {
      SymbolGlyph($r('sys.symbol.star'))
        .fontSize(48)
        .fontColor([Theme.inkTertiary(this.isDark)])
      Text(this.items.length === 0 ? '单词本还是空的' : '没有找到匹配的单词')
        .fontSize(16)
        .fontColor(Theme.inkSecondary(this.isDark))
        .margin({ top: 16 })
      Text(this.items.length === 0 ? '学习时点击星标，收藏你想记住的单词' : '换个关键词试试')
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
      this.SearchAndSort()
      if (this.shown.length > 0) {
        List({ space: 12 }) {
          ForEach(this.shown, (item: FavoriteItem) => {
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
                  }
                  .alignItems(VerticalAlign.Bottom)

                  Row() {
                    if (item.pos !== '') {
                      Text(item.pos)
                        .fontSize(11)
                        .fontColor(Theme.accent(this.isDark))
                        .backgroundColor(Theme.accentSoft(this.isDark))
                        .borderRadius(6)
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    }
                    Text(item.meaning)
                      .fontSize(14)
                      .fontColor(Theme.inkSecondary(this.isDark))
                      .margin({ left: 8 })
                      .layoutWeight(1)
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)
                  .margin({ top: 8 })

                  Row() {
                    Text(item.bookName)
                      .fontSize(11)
                      .fontColor(Theme.inkTertiary(this.isDark))
                    if (item.favoritedAt !== '') {
                      Text(`收藏于 ${item.favoritedAt}`)
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

                // 收藏星标：点击可取消收藏
                SymbolGlyph($r('sys.symbol.star_fill'))
                  .fontSize(24)
                  .fontColor([Theme.accent(this.isDark)])
                  .margin({ left: 8 })
                  .onClick(() => {
                    this.onToggleFav(item);
                  })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              .backgroundColor(Theme.card(this.isDark))
              .borderRadius(18)
              .padding(16)
            }
          }, (item: FavoriteItem) => `${item.word.id}-${item.favorited}`)
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
