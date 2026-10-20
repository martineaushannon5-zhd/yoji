import { router } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
import { setRemoteVideos, toVideoItems, videoList } from '../data/VideoData';
import { Api, VideoListResult } from '../common/Api';
import { VideoItem } from '../model/VideoModel';

// 视频学习视图：搜索框 + 视频卡片列表（缩略图、标题、上传日期）
@Component
export struct VideoListView {
  @State keyword: string = '';
  @State all: VideoItem[] = videoList();
  @State shown: VideoItem[] = videoList();
  // 深色模式开关：双向绑定 AppStorage，切换后本视图配色同步刷新
  @StorageLink('darkMode') isDark: boolean = false;
  // 滚动位置回调：用于首页底部导航栏的收起/展开联动
  onScrollY: (y: number) => void = (y: number): void => {};
  // 入场动画开关：首次进入或切回本 Tab 时触发淡入上浮
  @State enter: boolean = false;

  aboutToAppear(): void {
    this.all = videoList();
    this.shown = this.all;
    this.loadRemoteVideos();
    setTimeout(() => {
      this.enter = true;
    }, 80);
  }

  // 从后端拉取视频列表；失败时静默回退到远程兜底列表
  private async loadRemoteVideos(): Promise<void> {
    const result: VideoListResult = await Api.fetchVideos();
    if (!result.ok || result.videos.length === 0) {
      return;
    }
    const items: VideoItem[] = toVideoItems(result.videos);
    setRemoteVideos(items);
    this.all = items;
    this.filter();
  }

  // 按标题关键字过滤视频
  private filter(): void {
    const kw = this.keyword.trim();
    if (kw === '') {
      this.shown = this.all;
      return;
    }
    const list: VideoItem[] = [];
    for (let i = 0; i < this.all.length; i++) {
      if (this.all[i].title.indexOf(kw) >= 0) {
        list.push(this.all[i]);
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
          .fontColor(Theme.ink(this.isDark))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        Text(`上传于 ${this.dateLabel(item.date)}`)
          .fontSize(12)
          .fontColor(Theme.inkTertiary(this.isDark))
          .width('100%')
          .margin({ top: 8 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      .margin({ left: 12 })
    }
    .width('100%')
    // 与底部导航栏一致的玻璃质感：半透明底 + 背景模糊 + 高光描边 + 悬空阴影
    .backgroundColor(Theme.glass(this.isDark))
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1, color: Theme.glassBorder(this.isDark) })
    .borderRadius(16)
    .shadow({ radius: 12, color: 'rgba(27,30,40,0.12)', offsetX: 0, offsetY: 6 })
    .padding(12)
    .margin({ top: 12 })
    .clickEffect({ level: ClickEffectLevel.LIGHT })
    .onClick(() => {
      router.pushUrl({ url: 'pages/VideoPlayPage', params: { id: item.id } });
    })
  }

  build() {
    Column() {
      Row() {
        Text('视频学习')
          .fontSize(30)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.ink(this.isDark))
          .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 24, bottom: 8 })
      .translate({ y: this.enter ? 0 : 24 })
      .opacity(this.enter ? 1 : 0)
      .animation({ duration: 450, curve: Curve.Friction })

      // 搜索框（液态玻璃胶囊）
      Row() {
        Search({ value: this.keyword, placeholder: '搜索视频' })
          .height(40)
          .layoutWeight(1)
          .fontColor(Theme.ink(this.isDark))
          .placeholderColor(Theme.inkTertiary(this.isDark))
          .backgroundColor(Theme.glass(this.isDark))
          .backgroundBlurStyle(BlurStyle.Thin)
          .border({ width: 1, color: Theme.glassBorder(this.isDark) })
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
      .translate({ y: this.enter ? 0 : 24 })
      .opacity(this.enter ? 1 : 0)
      .animation({ duration: 450, curve: Curve.Friction, delay: 90 })

      // 视频列表
      Scroll() {
        Column() {
          if (this.shown.length === 0) {
            Column() {
              SymbolGlyph($r('sys.symbol.play_circle'))
                .fontSize(40)
                .fontColor([Theme.inkTertiary(this.isDark)])
              Text('没有找到相关视频')
                .fontSize(13)
                .fontColor(Theme.inkSecondary(this.isDark))
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
        // 底部留白加大，避免内容被悬浮导航栏遮挡
        .padding({ left: 24, right: 24, top: 4, bottom: 104 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
      .translate({ y: this.enter ? 0 : 28 })
      .opacity(this.enter ? 1 : 0)
      .animation({ duration: 450, curve: Curve.Friction, delay: 180 })
      .onDidScroll((xOffset: number, yOffset: number, scrollState: ScrollState) => {
        this.onScrollY(yOffset);
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Theme.bg(this.isDark))
  }
}
