import { promptAction, router, window } from '@kit.ArkUI';
import { Theme } from '../common/Theme';
import { findVideo } from '../data/VideoData';
import { VideoItem } from '../model/VideoModel';
import { Word } from '../model/WordModel';
import { Store } from '../store/Store';

// 倍速档位：循环切换
const RATES: number[] = [0.75, 1.0, 1.25, 1.5, 2.0];

// 爱心红色：收藏态图标色（浅色与深色下均可辨识）
const HEART_RED: string = '#FF5A76';

// 词性选项（展示文案），与 POS_SHORT 同索引对应
const POS_OPTIONS: string[] = [
  'n. 名词', 'v. 动词', 'adj. 形容词', 'adv. 副词', 'pron. 代词',
  'prep. 介词', 'conj. 连词', 'int. 感叹词', 'num. 数词', 'art. 冠词'
];

// 词性缩写（写入释义，如 "v. 放弃"，与列表页释义拆分格式一致）
const POS_SHORT: string[] = ['n.', 'v.', 'adj.', 'adv.', 'pron.', 'prep.', 'conj.', 'int.', 'num.', 'art.'];

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

// 本视频添加单词的展示项：预先拆好词性与释义（与单词本页样式一致）
interface MyWordItem {
  word: Word;
  pos: string;
  meaning: string;
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
  // 是否已收藏当前视频（爱心按钮状态）
  @State isFav: boolean = false;
  // 爱心弹跳动效缩放比（keyframe 动画驱动）
  @State heartScale: number = 1;
  // "+"悬浮按钮弹跳动效缩放比（keyframe 动画驱动）
  @State fabScale: number = 1;
  // 深色模式开关：双向绑定 AppStorage，切换后页面配色同步刷新
  @StorageLink('darkMode') isDark: boolean = false;
  // 添加单词面板：是否展开
  @State showAddPanel: boolean = false;
  // 添加单词表单：单词 / 中文意思 / 音标 / 词性选中索引（-1 未选）
  @State wordInput: string = '';
  @State meaningInput: string = '';
  @State phoneticInput: string = '';
  @State posIndex: number = -1;
  // 当前视频下用户手动添加的单词（页面下方展示）
  @State myWords: MyWordItem[] = [];
  // 笔记编辑模式：开启后每个单词行右侧显示删除按钮
  @State editing: boolean = false;

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, string>;
    if (params) {
      this.video = findVideo(params['id']);
    }
    if (this.video) {
      this.isFav = this.store.isVideoFavorite(this.video.id);
      this.refreshMyWords();
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

  // 切换收藏状态并播放爱心弹跳动效
  private async toggleFavorite(): Promise<void> {
    if (!this.video) {
      return;
    }
    this.isFav = await this.store.toggleVideoFavorite(this.video.id);
    this.playHeartAnim();
  }

  // 爱心弹跳动效：先缩小再放大回弹，模拟"怦然心动"
  // keyframeAnimateTo 每个关键帧用 duration + event 闭包描述（本 SDK 无 offset/value 形式）
  private playHeartAnim(): void {
    this.getUIContext().keyframeAnimateTo({
      iterations: 1
    }, [
      {
        duration: 90,
        curve: Curve.EaseIn,
        event: () => {
          this.heartScale = 0.4;
        }
      },
      {
        duration: 160,
        curve: Curve.EaseOut,
        event: () => {
          this.heartScale = 1.3;
        }
      },
      {
        duration: 120,
        curve: Curve.EaseIn,
        event: () => {
          this.heartScale = 0.85;
        }
      },
      {
        duration: 80,
        curve: Curve.EaseOut,
        event: () => {
          this.heartScale = 1.0;
        }
      }
    ]);
  }

  // "+"按钮点击弹跳动效：按下缩小再回弹放大，最后复位（与爱心弹跳同款）
  private playFabAnim(): void {
    this.getUIContext().keyframeAnimateTo({
      iterations: 1
    }, [
      {
        duration: 90,
        curve: Curve.EaseIn,
        event: () => {
          this.fabScale = 0.78;
        }
      },
      {
        duration: 150,
        curve: Curve.EaseOut,
        event: () => {
          this.fabScale = 1.15;
        }
      },
      {
        duration: 110,
        curve: Curve.EaseIn,
        event: () => {
          this.fabScale = 0.94;
        }
      },
      {
        duration: 70,
        curve: Curve.EaseOut,
        event: () => {
          this.fabScale = 1.0;
        }
      }
    ]);
  }

  // 打开添加单词面板：暂停视频，方便用户对照画面查看字幕填写
  private openAddPanel(): void {
    this.controller.pause();
    this.showControls = true;
    if (this.hideTimer >= 0) {
      clearTimeout(this.hideTimer);
      this.hideTimer = -1;
    }
    this.showAddPanel = true;
  }

  // 关闭添加单词面板（视频保持暂停，由用户手动继续播放）
  private closeAddPanel(): void {
    this.showAddPanel = false;
  }

  // 校验并保存自定义单词到自填词库（单词/词性/中文意思必填，音标选填）
  private async saveCustomWord(): Promise<void> {
    if (!this.video) {
      return;
    }
    const word = this.wordInput.trim();
    const meaning = this.meaningInput.trim();
    const phonetic = this.phoneticInput.trim();
    if (word === '') {
      promptAction.showToast({ message: '请填写单词' });
      return;
    }
    if (this.posIndex < 0) {
      promptAction.showToast({ message: '请选择词性' });
      return;
    }
    if (meaning === '') {
      promptAction.showToast({ message: '请填写中文意思' });
      return;
    }
    await this.store.addCustomWord(word, phonetic, POS_SHORT[this.posIndex], meaning, this.video.id);
    promptAction.showToast({ message: `已记下 ${word}` });
    // 刷新页面下方本视频单词列表
    this.refreshMyWords();
    // 清空表单并收起面板
    this.wordInput = '';
    this.meaningInput = '';
    this.phoneticInput = '';
    this.posIndex = -1;
    this.showAddPanel = false;
  }

  // 重新加载当前视频下用户添加的单词（进入页面与保存后调用）
  private refreshMyWords(): void {
    if (!this.video) {
      this.myWords = [];
      return;
    }
    const words = this.store.customWordsOf(this.video.id);
    const list: MyWordItem[] = [];
    for (let i = 0; i < words.length; i++) {
      const part = splitMeaning(words[i].meaning);
      const item: MyWordItem = {
        word: words[i],
        pos: part.pos,
        meaning: part.text
      };
      list.push(item);
    }
    this.myWords = list;
  }

  // 删除前二次确认：用户确认后才真正移除单词
  private confirmDelete(item: MyWordItem): void {
    promptAction.showDialog({
      title: '删除单词',
      message: `确定要删除 "${item.word.word}" 吗？删除后将从单词本中同步移除。`,
      buttons: [
        { text: '取消', color: Theme.inkSecondary(this.isDark) },
        { text: '删除', color: Theme.danger(this.isDark) }
      ]
    }).then((res) => {
      if (res.index === 1) {
        this.doDelete(item);
      }
    });
  }

  // 执行删除并刷新列表（删空后自动退出编辑模式）
  private async doDelete(item: MyWordItem): Promise<void> {
    await this.store.deleteCustomWord(item.word.id);
    this.refreshMyWords();
    if (this.myWords.length === 0) {
      this.editing = false;
    }
    promptAction.showToast({ message: '已删除' });
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
              .selectedColor(Theme.accent(this.isDark))
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

  // 添加单词面板：从底部弹出半屏表单（条件渲染 + transition 滑入滑出动画）
  @Builder
  AddWordPanel() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 半透明遮罩：淡入淡出，点击关闭面板
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0, 0, 0, 0.45)')
        .transition(TransitionEffect.OPACITY.animation({ duration: 240, curve: Curve.EaseOut }))
        .onClick(() => {
          this.closeAddPanel();
        })

      // 面板主体：占据屏幕下半部分
      Column() {
        // 顶部小横条：仿系统面板拖拽指示
        Row()
          .width(40)
          .height(4)
          .borderRadius(2)
          .backgroundColor(Theme.line(this.isDark))

        Row() {
          Text('添加单词')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(Theme.ink(this.isDark))
          Blank()
          Text('视频单词笔记')
            .fontSize(11)
            .fontColor(Theme.accent(this.isDark))
            .backgroundColor(Theme.accentSoft(this.isDark))
            .borderRadius(10)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        }
        .width('100%')
        .margin({ top: 14 })

        // 单词输入（必填）
        TextInput({ text: this.wordInput, placeholder: '请输入英文单词（必填）' })
          .height(46)
          .fontSize(15)
          .fontColor(Theme.ink(this.isDark))
          .placeholderColor(Theme.inkTertiary(this.isDark))
          .backgroundColor(Theme.bg(this.isDark))
          .borderRadius(12)
          .margin({ top: 16 })
          .onChange((value: string) => {
            this.wordInput = value;
          })

        // 词性选择（必填）：横向滚动选项，选中高亮
        Scroll() {
          Row({ space: 8 }) {
            ForEach(POS_OPTIONS, (opt: string, i: number) => {
              Text(opt)
                .fontSize(13)
                .fontWeight(this.posIndex === i ? FontWeight.Medium : FontWeight.Normal)
                .fontColor(this.posIndex === i ? Theme.accent(this.isDark) : Theme.inkSecondary(this.isDark))
                .backgroundColor(this.posIndex === i ? Theme.accentSoft(this.isDark) : Theme.glass(this.isDark))
                .border({ width: 1, color: this.posIndex === i ? Theme.accent(this.isDark) : Theme.line(this.isDark), radius: 15 })
                .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                .onClick(() => {
                  this.posIndex = i;
                })
            }, (opt: string) => opt)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        .margin({ top: 14 })

        // 中文意思输入（必填）
        TextInput({ text: this.meaningInput, placeholder: '请输入中文意思（必填）' })
          .height(46)
          .fontSize(15)
          .fontColor(Theme.ink(this.isDark))
          .placeholderColor(Theme.inkTertiary(this.isDark))
          .backgroundColor(Theme.bg(this.isDark))
          .borderRadius(12)
          .margin({ top: 14 })
          .onChange((value: string) => {
            this.meaningInput = value;
          })

        // 音标输入（选填）
        TextInput({ text: this.phoneticInput, placeholder: '请输入音标（选填）' })
          .height(46)
          .fontSize(15)
          .fontColor(Theme.ink(this.isDark))
          .placeholderColor(Theme.inkTertiary(this.isDark))
          .backgroundColor(Theme.bg(this.isDark))
          .borderRadius(12)
          .margin({ top: 14 })
          .onChange((value: string) => {
            this.phoneticInput = value;
          })

        Blank()

        // 底部按钮：取消 + 保存
        Row({ space: 12 }) {
          Button('取消')
            .layoutWeight(1)
            .height(44)
            .fontSize(15)
            .backgroundColor(Theme.glass(this.isDark))
            .border({ width: 1, color: Theme.glassBorder(this.isDark) })
            .fontColor(Theme.inkSecondary(this.isDark))
            .onClick(() => {
              this.closeAddPanel();
            })
          Button('保存')
            .layoutWeight(1)
            .height(44)
            .fontSize(15)
            .backgroundColor(Theme.accent(this.isDark))
            .fontColor(Color.White)
            .onClick(() => {
              this.saveCustomWord();
            })
        }
        .width('100%')
      }
      .width('100%')
      .height('50%')
      .padding({ left: 24, right: 24, top: 12, bottom: 24 })
      .backgroundColor(Theme.surface(this.isDark))
      .borderRadius({ topLeft: 20, topRight: 20 })
      .transition(TransitionEffect.translate({ y: '100%' }).animation({ duration: 280, curve: Curve.EaseOut }))
    }
    .width('100%')
    .height('100%')
  }

  build() {
    Stack() {
      // 背景层：全屏时黑色铺满；非全屏时与学习日历一致（顶部三分之一渐变 + 下方三分之二纯白，深色下为深灰）
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
            .backgroundColor(Theme.surface(this.isDark))
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
              .margin({ left: 4 })
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
                .borderRadius(5)
                .clip(true)

                // 视频信息卡
                Column() {
                  Row() {
                    Column() {
                      Text(this.video.title)
                        .fontSize(17)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(Theme.ink(this.isDark))
                        .width('100%')
                      Text(`上传于 ${this.dateLabel(this.video.date)}`)
                        .fontSize(13)
                        .fontColor(Theme.inkSecondary(this.isDark))
                        .width('100%')
                        .margin({ top: 8 })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .layoutWeight(1)

                    // 收藏按钮：爱心图案 + 点击弹跳动效（padding 扩大点击热区）
                    SymbolGlyph(this.isFav ? $r('sys.symbol.heart_fill') : $r('sys.symbol.heart'))
                      .fontSize(26)
                      .fontColor([this.isFav ? HEART_RED : Theme.inkTertiary(this.isDark)])
                      .scale({ x: this.heartScale, y: this.heartScale })
                      .padding(4)
                      .margin({ left: 10 })
                      .onClick(() => {
                        this.toggleFavorite();
                      })
                  }
                  .width('100%')
                  .alignItems(VerticalAlign.Center)
                }
                .alignItems(HorizontalAlign.Start)
                // 与首页一致的玻璃质感：半透明底 + 背景模糊 + 高光描边 + 悬空阴影
                .backgroundColor(Theme.glass(this.isDark))
                .backgroundBlurStyle(BlurStyle.Thin)
                .border({ width: 1, color: Theme.glassBorder(this.isDark) })
                .borderRadius(16)
                .shadow({ radius: 12, color: 'rgba(27,30,40,0.12)', offsetX: 0, offsetY: 6 })
                .padding(16)
                .width('100%')
                .margin({ top: 16 })

                // 本视频添加的单词：仅展示在当前视频下添加的单词
                Column() {
                  Row() {
                    Text('本视频添加的单词')
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor(Theme.ink(this.isDark))
                    Blank()
                    if (this.myWords.length > 0) {
                      Text(`${this.myWords.length} 个`)
                        .fontSize(12)
                        .fontColor(Theme.inkTertiary(this.isDark))
                    }
                    // 编辑 / 完成按钮：有单词时显示，切换删除模式
                    if (this.myWords.length > 0) {
                      Text(this.editing ? '完成' : '编辑')
                        .fontSize(13)
                        .fontColor(Theme.accent(this.isDark))
                        .fontWeight(FontWeight.Medium)
                        .margin({ left: 12 })
                        .onClick(() => {
                          this.editing = !this.editing;
                        })
                    }
                  }
                  .width('100%')

                  if (this.myWords.length === 0) {
                    Text('点击右下角 + 按钮，把视频里遇到的单词记下来')
                      .fontSize(12)
                      .fontColor(Theme.inkTertiary(this.isDark))
                      .width('100%')
                      .margin({ top: 10 })
                  } else {
                    ForEach(this.myWords, (item: MyWordItem) => {
                      Row() {
                        Column() {
                          Row() {
                            Text(item.word.word)
                              .fontSize(16)
                              .fontWeight(FontWeight.Medium)
                              .fontColor(Theme.ink(this.isDark))
                            if (item.word.phonetic !== '') {
                              Text(item.word.phonetic)
                                .fontSize(11)
                                .fontColor(Theme.inkTertiary(this.isDark))
                                .margin({ left: 8 })
                            }
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
                          .margin({ top: 6 })
                        }
                        .alignItems(HorizontalAlign.Start)
                        .layoutWeight(1)

                        // 编辑模式下的删除按钮：红色圆形减号
                        if (this.editing) {
                          Stack() {
                            Text('-')
                              .fontSize(20)
                              .fontWeight(FontWeight.Medium)
                              .fontColor(Color.White)
                          }
                          .width(30)
                          .height(30)
                          .borderRadius(15)
                          .backgroundColor(Theme.danger(this.isDark))
                          .margin({ left: 10 })
                          .onClick(() => {
                            this.confirmDelete(item);
                          })
                        }
                      }
                      .width('100%')
                      .padding({ top: 10, bottom: 10 })
                    }, (item: MyWordItem) => `${item.word.id}-${this.editing}`)
                  }
                }
                .alignItems(HorizontalAlign.Start)
                // 与首页一致的玻璃质感：半透明底 + 背景模糊 + 高光描边 + 悬空阴影
                .backgroundColor(Theme.glass(this.isDark))
                .backgroundBlurStyle(BlurStyle.Thin)
                .border({ width: 1, color: Theme.glassBorder(this.isDark) })
                .borderRadius(16)
                .shadow({ radius: 12, color: 'rgba(27,30,40,0.12)', offsetX: 0, offsetY: 6 })
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

      // 右下角"+"悬浮按钮：打开添加单词面板（全屏时隐藏，避免遮挡控制栏）
      // 动效：出现/消失时缩放淡入淡出（transition），点击时弹跳回弹（keyframe）
      if (!this.fullscreen) {
        Stack() {
          Text('+')
            .fontSize(30)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
        }
        .width(56)
        .height(56)
        .borderRadius(28)
        .backgroundColor(Theme.accent(this.isDark))
        .shadow({ radius: 16, color: 'rgba(0, 0, 0, 0.28)', offsetX: 0, offsetY: 5 })
        .scale({ x: this.fabScale, y: this.fabScale })
        .transition(TransitionEffect.scale({ x: 0.6, y: 0.6 })
          .combine(TransitionEffect.OPACITY)
          .animation({ duration: 260, curve: Curve.EaseOut }))
        .position({ x: '95%', y: '100%' })
        .markAnchor({ x: '100%', y: '100%' })
        .offset({ x: -24, y: -32 })
        .onClick(() => {
          this.playFabAnim();
          this.openAddPanel();
        })
      }

      // 添加单词面板：仅在展开时渲染（收起时组件不存在，不拦截页面触摸）
      if (this.showAddPanel) {
        this.AddWordPanel()
      }
    }
    .width('100%')
    .height('100%')
  }
}                         
