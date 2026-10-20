import { router } from '@kit.ArkUI';
import { BOOKS } from '../data/WordData';
import { Store } from '../store/Store';
import { Theme } from '../common/Theme';
import { STATUS_MASTERED, Word } from '../model/WordModel';

// 排序方式：0 学习日期，1 首字母，2 词库
const SORT_OPTIONS: string[] = ['学习日期', '首字母', '词库'];

// 单词列表项（已掌握 / 学习中通用）
interface MasteredItem {
  word: Word;
  bookName: string;
  order: number;
  pos: string;
  meaning: string;
  masteredAt: string;
  favorited: boolean;
}

interface MeaningPart {
  pos: string;
  text: string;
}

// 路由参数：status 指定列表展示的单词状态（缺省为已掌握）
interface ListParams {
  status: number;
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
struct WordListPage {
  @State items: MasteredItem[] = [];
  @State shown: MasteredItem[] = [];
  @State keyword: string = '';
  @State sortMode: number = 0;
  // 深色模式开关：双向绑定 AppStorage，切换后页面配色同步刷新
  @StorageLink('darkMode') isDark: boolean = false;
  private store: Store = Store.get();
  // 当前列表展示的单词状态：已掌握 / 学习中，由路由参数指定
  private status: number = STATUS_MASTERED;

  aboutToAppear(): void {
    const params = router.getParams() as ListParams;
    if (params) {
      this.status = params.status;
    }
    const list: MasteredItem[] = [];
    let order = 0;
    for (let b = 0; b < BOOKS.length; b++) {
      const book = BOOKS[b];
      for (let w = 0; w < book.words.length; w++) {
        const word = book.words[w];
        if (this.store.statusOf(word.id) === this.status) {
          const part = splitMeaning(word.meaning);
          const item: MasteredItem = {
            word: word,
            bookName: book.name,
            order: order,
            pos: part.pos,
            meaning: part.text,
            masteredAt: this.store.masteredAt[word.id] ?? '',
            favorited: this.store.isFavorite(word.id)
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
    let list: MasteredItem[] = this.items.slice();
    const kw = this.keyword.trim().toLowerCase();
    if (kw !== '') {
      list = list.filter((it: MasteredItem): boolean => {
        return it.word.word.toLowerCase().indexOf(kw) >= 0 ||
          it.meaning.toLowerCase().indexOf(kw) >= 0;
      });
    }
    if (this.sortMode === 0) {
      // 按掌握日期从新到旧，无日期记录排最后
      list.sort((a: MasteredItem, b: MasteredItem): number => {
        if (a.masteredAt === b.masteredAt) {
          return a.order - b.order;
        }
        if (a.masteredAt === '') {
          return 1;
        }
        if (b.masteredAt === '') {
          return -1;
        }
        return a.masteredAt < b.masteredAt ? 1 : -1;
      });
    } else if (this.sortMode === 1) {
      // 按英文首字母升序
      list.sort((a: MasteredItem, b: MasteredItem): number => {
        const c = a.word.word.toLowerCase().localeCompare(b.word.word.toLowerCase());
        return c !== 0 ? c : a.order - b.order;
      });
    } else {
      // 按词库分组，组内保持词书原有顺序
      list.sort((a: MasteredItem, b: MasteredItem): number => {
        return a.order - b.order;
      });
    }
    this.shown = list;
  }

  // 切换收藏状态，同步刷新列表项的星标显示
  private async onToggleFav(item: MasteredItem): Promise<void> {
    const fav = await this.store.toggleFavorite(item.word.id);
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].word.id === item.word.id) {
        this.items[i].favorited = fav;
      }
    }
    this.applyFilterAndSort();
  }

  // 空列表提示文案（按当前状态区分）
  private emptyTitle(): string {
    return this.status === STATUS_MASTERED ? '还没有已掌握的单词' : '还没有学习中的单词';
  }

  private emptyHint(): string {
    return this.status === STATUS_MASTERED ? '开始学习，掌握属于你的第一个单词吧' : '开始学习，遇到的生词会出现在这里';
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
      Text(this.status === STATUS_MASTERED ? '已掌握单词' : '学习中单词')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.ink(this.isDark))
      Blank()
      Text(`${this.shown.length} 词`)
        .fontSize(13)
        .fontColor(Theme.inkSecondary(this.isDark))
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
        .backgroundColor(Theme.glass(this.isDark))
        .backgroundBlurStyle(BlurStyle.Thin)
        .border({ width: 1, color: Theme.glassBorder(this.isDark) })
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
            .backgroundColor(this.sortMode === i ? Theme.accentSoft(this.isDark) : Theme.glass(this.isDark))
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
      SymbolGlyph($r('sys.symbol.book'))
        .fontSize(48)
        .fontColor([Theme.inkTertiary(this.isDark)])
      Text(this.items.length === 0 ? this.emptyTitle() : '没有找到匹配的单词')
        .fontSize(16)
        .fontColor(Theme.inkSecondary(this.isDark))
        .margin({ top: 16 })
      Text(this.items.length === 0 ? this.emptyHint() : '换个关键词试试')
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
          ForEach(this.shown, (item: MasteredItem) => {
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
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Column() {
                  Text(item.bookName)
                    .fontSize(11)
                    .fontColor(Theme.inkTertiary(this.isDark))
                  if (item.masteredAt !== '') {
                    Text(item.masteredAt)
                      .fontSize(11)
                      .fontColor(Theme.inkTertiary(this.isDark))
                      .margin({ top: 4 })
                  }
                }
                .alignItems(HorizontalAlign.End)
                .margin({ left: 8 })

                // 收藏星标：点击切换收藏状态
                SymbolGlyph(item.favorited ? $r('sys.symbol.star_fill') : $r('sys.symbol.star'))
                  .fontSize(24)
                  .fontColor([item.favorited ? Theme.accent(this.isDark) : Theme.inkTertiary(this.isDark)])
                  .margin({ left: 10 })
                  .onClick(() => {
                    this.onToggleFav(item);
                  })
              }
              .width('100%')
              .alignItems(VerticalAlign.Top)
              // 与首页一致的玻璃质感：半透明底 + 背景模糊 + 高光描边 + 悬空阴影
              .backgroundColor(Theme.glass(this.isDark))
              .backgroundBlurStyle(BlurStyle.Thin)
              .border({ width: 1, color: Theme.glassBorder(this.isDark) })
              .borderRadius(18)
              .shadow({ radius: 12, color: 'rgba(27,30,40,0.12)', offsetX: 0, offsetY: 6 })
              .padding(16)
            }
          }, (item: MasteredItem) => `${item.word.id}-${item.favorited}`)
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
