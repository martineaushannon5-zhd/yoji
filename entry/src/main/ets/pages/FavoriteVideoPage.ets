import { router } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
import { findVideo } from '../data/VideoData';
import { Store } from '../store/Store';
import { VideoItem } from '../model/VideoModel';

// 爱心红色：收藏态图标色（浅色与深色下均可辨识）
const HEART_RED: string = '#FF5A76';

// 收藏视频列表项：视频信息 + 收藏日期
interface FavVideoItem {
  video: VideoItem;
  favoritedAt: string;
}

// 喜欢的视频页：展示用户收藏过的视频，点击进入播放页，可取消收藏
@Entry
@Component
struct FavoriteVideoPage {
  @State items: FavVideoItem[] = [];
  // 深色模式开关：双向绑定 AppStorage，切换后页面配色同步刷新
  @StorageLink('darkMode') isDark: boolean = false;
  private store: Store = Store.get();

  aboutToAppear(): void {
    this.rebuild();
  }

  // 从 Store 收藏表重建列表，按收藏时间从新到旧排序
  private rebuild(): void {
    const list: FavVideoItem[] = [];
    const ids = Object.keys(this.store.favoriteVideos);
    for (let i = 0; i < ids.length; i++) {
      const video = findVideo(ids[i]);
      if (video) {
        const item: FavVideoItem = {
          video: video,
          favoritedAt: this.store.favoriteVideos[ids[i]] ?? ''
        };
        list.push(item);
      }
    }
    // 按收藏日期从新到旧排序，无日期记录排最后
    list.sort((a: FavVideoItem, b: FavVideoItem): number => {
      if (a.favoritedAt === b.favoritedAt) {
        return 0;
      }
      if (a.favoritedAt === '') {
        return 1;
      }
      if (b.favoritedAt === '') {
        return -1;
      }
      return a.favoritedAt < b.favoritedAt ? 1 : -1;
    });
    this.items = list;
  }

  // 取消收藏并从列表移除
  private async onUnfav(item: FavVideoItem): Promise<void> {
    await this.store.toggleVideoFavorite(item.video.id);
    this.rebuild();
  }

  // 日期展示格式，如 "2026-10-16" -> "2026年10月16日"
  private dateLabel(date: string): string {
    const parts = date.split('-');
    if (parts.length === 3) {
      return `${parts[0]}年${Number(parts[1])}月${Number(parts[2])}日`;
    }
    return date;
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
      Text('喜欢的视频')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.ink(this.isDark))
      Blank()
      Text(`${this.items.length} 个视频`)
        .fontSize(13)
        .fontColor(Theme.inkSecondary(this.isDark))
    }
    .width('100%')
    .padding({ left: 8, right: 24, top: 8, bottom: 8 })
  }

  // 空态：还没有收藏任何视频
  @Builder
  EmptyView() {
    Column() {
      SymbolGlyph($r('sys.symbol.heart'))
        .fontSize(48)
        .fontColor([Theme.inkTertiary(this.isDark)])
      Text('还没有收藏的视频')
        .fontSize(16)
        .fontColor(Theme.inkSecondary(this.isDark))
        .margin({ top: 16 })
      Text('播放视频时点击爱心，把它加入喜欢')
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
      if (this.items.length > 0) {
        List({ space: 12 }) {
          ForEach(this.items, (item: FavVideoItem) => {
            ListItem() {
              Row() {
                // 内容区：点击进入播放页（与爱心按钮分开绑事件，避免点击冲突）
                Row() {
                  Image(item.video.thumb)
                    .width(132)
                    .height(76)
                    .borderRadius(10)
                    .objectFit(ImageFit.Cover)
                  Column() {
                    Text(item.video.title)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(Theme.ink(this.isDark))
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .width('100%')
                    Text(`上传于 ${this.dateLabel(item.video.date)}`)
                      .fontSize(12)
                      .fontColor(Theme.inkTertiary(this.isDark))
                      .width('100%')
                      .margin({ top: 8 })
                    if (item.favoritedAt !== '') {
                      Text(`收藏于 ${item.favoritedAt}`)
                        .fontSize(11)
                        .fontColor(Theme.inkTertiary(this.isDark))
                        .width('100%')
                        .margin({ top: 4 })
                    }
                  }
                  .alignItems(HorizontalAlign.Start)
                  .layoutWeight(1)
                  .margin({ left: 12 })
                }
                .layoutWeight(1)
                .alignItems(VerticalAlign.Center)
                .onClick(() => {
                  router.pushUrl({ url: 'pages/VideoPlayPage', params: { id: item.video.id } });
                })

                // 收藏爱心：点击取消收藏
                SymbolGlyph($r('sys.symbol.heart_fill'))
                  .fontSize(24)
                  .fontColor([HEART_RED])
                  .margin({ left: 8 })
                  .onClick(() => {
                    this.onUnfav(item);
                  })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              // 与首页一致的玻璃质感：半透明底 + 背景模糊 + 高光描边 + 悬空阴影
              .backgroundColor(Theme.glass(this.isDark))
              .backgroundBlurStyle(BlurStyle.Thin)
              .border({ width: 1, color: Theme.glassBorder(this.isDark) })
              .borderRadius(18)
              .shadow({ radius: 12, color: 'rgba(27,30,40,0.12)', offsetX: 0, offsetY: 6 })
              .padding(12)
            }
          }, (item: FavVideoItem) => item.video.id)
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
