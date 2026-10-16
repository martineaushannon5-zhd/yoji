import { router } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
import { VIDEO_LIST } from '../data/VideoData';
import { VideoItem } from '../model/VideoModel';

// 视频学习视图：搜索框 + 视频卡片列表（缩略图、标题、上传日期）
@Component
export struct VideoListView {
  @State keyword: string = '';
  @State shown: VideoItem[] = VIDEO_LIST;

  aboutToAppear(): void {
    this.shown = VIDEO_LIST;
  }

  // 按标题关键字过滤视频
  private filter(): void {
    const kw = this.keyword.trim();
    if (kw === '') {
      this.shown = VIDEO_LIST;
      return;
    }
    const list: VideoItem[] = [];
    for (let i = 0; i < VIDEO_LIST.length; i++) {
      if (VIDEO_LIST[i].title.indexOf(kw) >= 0) {
        list.push(VIDEO_LIST[i]);
      }
    }
    this.shown = list;
  }

  // 日期展示格式，如 "2026-10-16" -> "2026年10月16日"
  private dateLabel(date: string): string {
    const parts = date.split('-');
    if (parts.length === 3) {
      return `${parts[0]}年${Number(parts[1])}月${Number(parts[2])}日`;
    }
    return date;
  }

  // 视频卡片：缩略图 + 标题 + 上传日期，点击进入播放页
  @Builder
  VideoCard(item: VideoItem) {
    Row() {
      Image(item.thumb)
        .width(132)
        .height(76)
        .borderRadius(10)
        .objectFit(ImageFit.Cover)
      Column() {
        Text(item.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(Theme.ink)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(`上传于 ${this.dateLabel(item.date)}`)
          .fontSize(12)
          .fontColor(Theme.inkTertiary)
          .width('100%')
          .margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })
    }
    .width('100%')
    .backgroundColor(Theme.card)
    .borderRadius(16)
    .padding(12)
    .margin({ top: 12 })
    .onClick(() => {
      router.pushUrl({ url: 'pages/VideoPlayPage', params: { id: item.id } });
    })
  }

  build() {
    Column() {
      Text('视频学习')
        .fontSize(30)
        .fontWeight(FontWeight.Bold)
        .fontColor(Theme.ink)
        .padding({ left: 24, top: 24, bottom: 8 })
        .width('100%')

      // 搜索框
      Row() {
        Search({ value: this.keyword, placeholder: '搜索视频' })
          .height(40)
          .layoutWeight(1)
          .backgroundColor(Theme.card)
          .borderRadius(20)
          .onChange((v: string) => {
            this.keyword = v;
            this.filter();
          })
          .onSubmit(() => {
            this.filter();
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24 })

      // 视频列表
      Scroll() {
        Column() {
          if (this.shown.length === 0) {
            Column() {
              SymbolGlyph($r('sys.symbol.play_circle'))
                .fontSize(40)
                .fontColor([Theme.inkTertiary])
              Text('没有找到相关视频')
                .fontSize(13)
                .fontColor(Theme.inkSecondary)
                .margin({ top: 10 })
            }
            .width('100%')
            .padding({ top: 60 })
          } else {
            ForEach(this.shown, (item: VideoItem) => {
              this.VideoCard(item)
            }, (item: VideoItem) => item.id)
          }
        }
        .padding({ left: 24, right: 24, top: 4, bottom: 24 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg)
  }
}
