import { common } from '@kit.AbilityKit';
import { font, router } from '@kit.ArkUI';
import { Store } from '../store/Store';
import { CloudSync } from '../common/CloudSync';

// 欢迎页：每次启动时展示，稍后按登录态进入登录页或首页
@Entry
@Component
struct SplashPage {
  @State fadeIn: number = 0;
  private timer: number = -1;
  private store: Store = Store.get();

  async aboutToAppear(): Promise<void> {
    // 注册品牌字体（Bebas），供 Yoji. 大字使用
    font.registerFont({
      familyName: 'Bebas',
      familySrc: '/rawfile/Bebas-Regular.ttf'
    });
    // 先初始化全局存储，确保能读取登录态
    const ctx = getContext(this) as common.UIAbilityContext;
    await this.store.init(ctx);
    // 恢复上次选择的主题（深色/浅色），供各页面 @StorageLink 读取
    AppStorage.setOrCreate('darkMode', this.store.darkMode);
    // 学习进度每次落盘后触发防抖上云；Store 本身不感知网络
    this.store.onSaved = (): void => {
      CloudSync.schedulePush();
    };
    // 已登录：后台静默合并云端进度，完成后通过 AppStorage.syncTick 通知首页刷新
    if (this.store.isLoggedIn) {
      CloudSync.bootstrap();
    }
    // 品牌文字淡入
    animateTo({ duration: 600, curve: Curve.EaseOut }, () => {
      this.fadeIn = 1;
    });
    // 1.8 秒后按登录态跳转：未登录先去登录注册页
    this.timer = setTimeout(() => {
      const target = this.store.isLoggedIn ? 'pages/Index' : 'pages/LoginPage';
      router.replaceUrl({ url: target });
    }, 1800);
  }

  aboutToDisappear(): void {
    if (this.timer >= 0) {
      clearTimeout(this.timer);
      this.timer = -1;
    }
  }

  build() {
    Column() {
      Blank()
      Column() {
        // 品牌文字主视觉：Yoji. 纯白大字（使用 Bebas 字体）
        Text('Yoji.')
          .fontSize(56)
          .fontFamily('Bebas')
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        Text('要记单词？Yoji帮你！')
          .fontSize(14)
          .fontColor('rgba(255, 255, 255, 0.8)')
          .margin({ top: 10 })
      }
      .opacity(this.fadeIn)
      .justifyContent(FlexAlign.Center)

      Blank()
      Text('v1.2.0')
        .fontSize(12)
        .fontColor('rgba(255, 255, 255, 0.5)')
        .margin({ bottom: 40 })
    }
    .width('100%')
    .height('100%')
    // 背景：#0077ff → #000000 线性渐变，角度 52°
    .linearGradient({
      angle: 52,
      colors: [['#0077ff', 0.0], ['#000000', 1.0]]
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
