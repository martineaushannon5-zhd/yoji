import { router, window } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
import { findVideo } from '../data/VideoData';
import { VideoItem } from '../model/VideoModel';
import { Store } from '../store/Store';

// 倍速档位：循环切换
const RATES: number[] = [0.75, 1.0, 1.25, 1.5, 2.0];

// 秒 -> "mm:ss"（超过 1 小时显示 "h:mm:ss"）
function formatTime(t: number): string {
  const total = Math.max(0, Math.floor(t));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  const pad = (n: number): string => (n < 10 ? `0${n}` : `${n}`);
  if (h > 0) {
    return `${h}:${pad(m)}:${pad(s)}`;
  }
  return `${pad(m)}:${pad(s)}`;
}

// 视频播放页：自定义控制栏 + 手势快进快退 + 倍速 + 自绘全屏 + 记住进度
@Entry
@Component
struct VideoPlayPage {
  private video: VideoItem | undefined = undefined;
  private controller: VideoController = new VideoController();
  private store: Store = Store.get();
  private hideTimer: number = -1;
  private seekStart: number = 0;
  private seekTarget: number = -1;
  // 全屏切换会重建 Video，用于 onPrepared 恢复：目标进度（-1 表示取上次保存值）与是否自动续播
  private resumeTime: number = -1;
  private resumePlaying: boolean = false;
  @State playing: boolean = false;
  @State currentTime: number = 0;
  @State duration: number = 0;
  @State rate: number = 1.0;
  @State showControls: boolean = true;
  @State fullscreen: boolean = false;
  @State seeking: boolean = false;
  @State seekHint: string = '';
  // 视频加载失败时的错误提示（用于排查播放问题）
  @State loadError: string = '';

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params) {
      this.video = findVideo(params['id']);
    }
    // 不修改状态栏颜色，保持系统默认，避免影响其他页面显示
  }

  aboutToDisappear(): void {
    if (this.hideTimer >= 0) {
      clearTimeout(this.hideTimer);
      this.hideTimer = -1;
    }
    this.controller.stop();
    // 记住播放进度，下次进入续播
    if (this.video) {
      this.store.setVideoProgress(this.video.id, this.currentTime);
    }
    // 若在全屏状态退出页面，恢复窗口与系统栏，避免影响后续页面
    if (this.fullscreen) {
      this.fullscreen = false;
      window.getLastWindow(getContext(this)).then((win: window.Window) => {
        win.setPreferredOrientation(window.Orientation.AUTO_ROTATION);
        win.setSpecificSystemBarEnabled('status', true);
        win.setSpecificSystemBarEnabled('navigation', true);
      });
    }
  }

  // 播放 / 暂停切换
  private togglePlay(): void {
    if (this.playing) {
      this.controller.pause();
    } else {
      this.controller.start();
      this.showControls = true;
      this.scheduleHide();
    }
  }

  // 播放中 3 秒无操作自动隐藏控制栏
  private scheduleHide(): void {
    if (this.hideTimer >= 0) {
      clearTimeout(this.hideTimer);
    }
    this.hideTimer = setTimeout(() => {
      if (this.playing) {
        this.showControls = false;
      }
      this.hideTimer = -1;
    }, 3000);
  }

  // 切换倍速：1.0 -> 1.25 -> 1.5 -> 2.0 -> 0.75 -> 1.0
  private cycleRate(): void {
    const idx = RATES.indexOf(this.rate);
    this.rate = RATES[(idx + 1) % RATES.length];
  }

  // 全屏 / 退出全屏：旋转窗口 + 隐藏系统栏，页面布局跟随切换
  // 不用 VideoController.requestFullscreen（系统全屏窗口不会渲染页面自绘的控制层）
  private async toggleFullscreen(): Promise<void> {
    // 记录当前进度与播放状态：布局切换会重建 Video，onPrepared 中据此恢复
    this.resumeTime = this.currentTime;
    this.resumePlaying = this.playing;
    const win = await window.getLastWindow(getContext(this));
    if (this.fullscreen) {
      // 退出全屏：跟随传感器旋转（横置手机时视频仍会跟着转）
      await win.setPreferredOrientation(window.Orientation.AUTO_ROTATION);
      await win.setSpecificSystemBarEnabled('status', true);
      await win.setSpecificSystemBarEnabled('navigation', true);
      this.fullscreen = false;
    } else {
      // 进入全屏：强制横屏并隐藏状态栏/导航栏
      await win.setPreferredOrientation(window.Orientation.LANDSCAPE);
      await win.setSpecificSystemBarEnabled('status', false);
      await win.setSpecificSystemBarEnabled('navigation', false);
      this.fullscreen = true;
    }
    this.showControls = true;
    this.scheduleHide();
  }

  // 日期展示格式，如 "2026-10-16" -> "2026年10月16日"
  private dateLabel(date: string): string {
    const parts = date.split('-');
    if (parts.length === 3) {
      return `${parts[0]}年${Number(parts[1])}月${Number(parts[2])}日`;
    }
    return date;
  }

  // 播放器主体：视频 + 手势层 + 遮罩 + 中央按钮 + 控制栏（全屏与非全屏共用）
  // 注意：@Builder 参数按值传递，Resource 类型经值拷贝后无法正确解析，
  // 因此这里不传参，直接访问 this.video（调用处已保证非空）
  @Builder
  PlayerBody() {
    Stack() {
      if (this.video) {
        Video({
          src: this.video.src,
          controller: this.controller,
          currentProgressRate: this.rate
        })
          .width('100%')
          .height('100%')
          .autoPlay(false)
          .controls(false)
          .objectFit(ImageFit.Contain)
          .backgroundColor('#000000')
          .onStart(() => {
            this.playing = true;
            this.scheduleHide();
          })
          .onPause(() => {
            this.playing = false;
            this.showControls = true;
            if (this.hideTimer >= 0) {
              clearTimeout(this.hideTimer);
              this.hideTimer = -1;
            }
          })
          .onFinish(() => {
            this.playing = false;
            this.showControls = true;
          })
          .onUpdate((e: PlaybackInfo) => {
            if (!this.seeking) {
              this.currentTime = e.time;
            }
          })
          .onPrepared((e: PreparedInfo) => {
            // 视频就绪后拿到总时长
            this.duration = e.duration;
            this.loadError = '';
            // 恢复进度：全屏切换用当前进度，首次进入用上次保存的进度
            let target = this.resumeTime;
            if (target < 0 && this.video) {
              target = this.store.videoProgress[this.video.id] ?? 0;
            }
            if (target > 0) {
              this.controller.setCurrentTime(target);
              this.currentTime = target;
            }
            // 全屏切换前正在播放则自动续播
            if (this.resumePlaying) {
              this.controller.start();
            }
            this.resumeTime = -1;
            this.resumePlaying = false;
          })
          .onError(() => {
            // 加载或播放失败：显示提示便于排查
            this.loadError = '视频加载失败';
            this.playing = false;
            this.showControls = true;
          })
      }

      // 手势层：点击播放/暂停 + 左右滑动快进快退
      Column()
        .width('100%')
        .height('100%')
        .onClick(() => {
          this.togglePlay();
        })
        .gesture(
          PanGesture({ direction: PanDirection.Horizontal })
            .onActionStart(() => {
              this.seekStart = this.currentTime;
              this.seekTarget = -1;
            })
            .onActionUpdate((e: GestureEvent) => {
              // 每滑动 10px 快进/快退 1 秒
              const target = Math.max(0, Math.min(this.duration, this.seekStart + e.offsetX / 10));
              this.seekTarget = target;
              this.seekHint = `${formatTime(target)} / ${formatTime(this.duration)}`;
            })
            .onActionEnd(() => {
              if (this.seekTarget >= 0) {
                this.controller.setCurrentTime(this.seekTarget);
                this.currentTime = this.seekTarget;
              }
              this.seekTarget = -1;
              this.seekHint = '';
            })
        )

      // 顶部渐变遮罩：占满一层、遮罩在上、其余留空（用布局结构定位，位置确定）
      if (this.showControls) {
        Column() {
          Column()
            .width('100%')
            .height(48)
            .linearGradient({
              angle: 180,
              colors: [['rgba(0, 0, 0, 0.55)', 0.0], ['rgba(0, 0, 0, 0)', 1.0]]
            })
          Blank()
        }
        .width('100%')
        .height('100%')
      }

      // 视频加载失败提示（Stack 默认居中）
      if (this.loadError !== '') {
        Text(this.loadError)
          .fontSize(13)
          .fontColor('#FF9C9C')
          .backgroundColor('rgba(0, 0, 0, 0.55)')
          .borderRadius(14)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      }

      // 快进快退提示（Stack 默认居中）
      if (this.seekHint !== '') {
        Text(this.seekHint)
          .fontSize(13)
          .fontColor(Color.White)
          .backgroundColor('rgba(0, 0, 0, 0.55)')
          .borderRadius(14)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
      }

      // 底部自定义控制栏：占满一层、控制栏在下、其余留空（用布局结构定位，位置确定）
      if (this.showControls) {
        Column() {
          Blank()
          Column() {
            // 进度条：白色滑块 + 主题蓝已播部分
            Slider({
              value: this.currentTime,
              min: 0,
              max: this.duration > 0 ? this.duration : 100
            })
              .blockColor(Color.White)
              .selectedColor(Theme.accent)
              .trackColor('rgba(255, 255, 255, 0.3)')
              .trackThickness(3)
              .height(20)
              .onChange((v: number, mode: SliderChangeMode) => {
                if (mode === SliderChangeMode.Begin) {
                  this.seeking = true;
                }
                this.currentTime = v;
                if (mode === SliderChangeMode.End) {
                  this.seeking = false;
                  this.controller.setCurrentTime(v);
                  this.scheduleHide();
                }
              })
            Row() {
              // 播放 / 暂停按钮（进度条下方，直接绑定点击）
              SymbolGlyph(this.playing ? $r('sys.symbol.pause_fill') : $r('sys.symbol.play_fill'))
                .fontSize(20)
                .fontColor([Color.White])
                .onClick(() => {
                  this.togglePlay();
                })
              Text(`${formatTime(this.currentTime)} / ${formatTime(this.duration)}`)
                .fontSize(11)
                .fontColor('rgba(255, 255, 255, 0.85)')
                .margin({ left: 12 })
              Blank()
              Text(`${this.rate}x`)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(Color.White)
                .onClick(() => {
                  this.cycleRate();
                })
              SymbolGlyph(this.fullscreen ?
                $r('sys.symbol.arrow_down_right_and_arrow_up_left') :
                $r('sys.symbol.arrow_up_left_and_arrow_down_right'))
                .fontSize(16)
                .fontColor([Color.White])
                .margin({ left: 16 })
                .onClick(() => {
                  this.toggleFullscreen();
                })
            }
            .width('100%')
            .margin({ top: 2 })
          }
          .width('100%')
          .padding({ left: 14, right: 14, bottom: 10 })
          .linearGradient({
            angle: 0,
            colors: [['rgba(0, 0, 0, 0.65)', 0.0], ['rgba(0, 0, 0, 0)', 1.0]]
          })
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      // 背景层：全屏时黑色铺满；非全屏时与学习日历一致（顶部三分之一渐变 + 下方三分之二纯白）
      if (this.fullscreen) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#000000')
      } else {
        Column() {
          Column()
            .width('100%')
            .height('33.3%')
            .linearGradient({
              angle: 52,
              colors: [['#0077ff', 0.0], ['#000000', 1.0]]
            })
          Column()
            .width('100%')
            .layoutWeight(1)
            .backgroundColor(Color.White)
        }
        .width('100%')
        .height('100%')
      }

      if (this.fullscreen && this.video) {
        // 全屏：播放器铺满整个窗口
        Stack() {
          this.PlayerBody()
        }
        .width('100%')
        .height('100%')
      } else {
        // 非全屏：顶栏 + 滚动区（16:9 播放器 + 视频信息卡）
        Column() {
          // 顶栏：返回 + 标题（渐变深色背景上使用白色）
          Row() {
            Column() {
              SymbolGlyph($r('sys.symbol.chevron_left'))
                .fontSize(20)
                .fontColor([Color.White])
            }
            .width(40)
            .height(40)
            .borderRadius(20)
            .justifyContent(FlexAlign.Center)
            .onClick(() => {
              router.back();
            })
            Text('视频学习')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
              .layoutWeight(1)
              .textAlign(TextAlign.Center)
            Column() {
            }
            .width(40)
            .height(40)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 4 })

          Scroll() {
            Column() {
              if (this.video) {
                // 播放器：16:9 圆角
                Stack() {
                  this.PlayerBody()
                }
                .width('100%')
                .aspectRatio(16 / 9)
                .borderRadius(16)
                .clip(true)

                // 视频信息卡
                Column() {
                  Text(this.video.title)
                    .fontSize(17)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Theme.ink)
                    .width('100%')
                  Text(`上传于 ${this.dateLabel(this.video.date)}`)
                    .fontSize(13)
                    .fontColor(Theme.inkSecondary)
                    .width('100%')
                    .margin({ top: 8 })
                  Divider()
                    .strokeWidth(1)
                    .color(Theme.line)
                    .margin({ top: 14, bottom: 14 })
                  Text('播放页粗略版本，后续将补充更多功能')
                    .fontSize(12)
                    .fontColor(Theme.inkTertiary)
                    .width('100%')
                }
                .alignItems(HorizontalAlign.Start)
                .backgroundColor(Theme.card)
                .borderRadius(16)
                .padding(16)
                .width('100%')
                .margin({ top: 16 })
              }
            }
            .padding({ left: 24, right: 24, bottom: 24 })
            .width('100%')
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          // 内容不足视口时顶部对齐，避免播放器居中显示
          .align(Alignment.Top)
        }
        .width('100%')
        .height('100%')
      }
    }
    .width('100%')
    .height('100%')
  }
}
