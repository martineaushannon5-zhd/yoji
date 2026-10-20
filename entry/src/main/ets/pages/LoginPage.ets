import { router } from '@kit.ArkUI';
import { Api, AuthData, AuthResult } from '../common/Api';
import { CloudSync } from '../common/CloudSync';
import { Store } from '../store/Store';
import { Theme } from '../common/Theme';

// ============================================================
// 登录 / 注册：接入远程 Node 后端（server/）
//
// POST /api/auth/login    入参 { account, password }
// POST /api/auth/register 入参 { account, password }
// 出参 { code: 0, message, data: { token, userId, account, nickname, avatar } }
//
// 登录成功后：
//   1. Store.login(token, nickname, avatar, userId) 保存登录态
//   2. CloudSync.bootstrap() 拉取/合并云端学习进度
//   3. 返回来源页或进入首页
// ============================================================

@Entry
@Component
struct LoginPage {
  @State mode: number = 0;          // 0 登录，1 注册
  @State account: string = '';
  @State password: string = '';
  @State confirm: string = '';
  @State errorMsg: string = '';
  @State loading: boolean = false;
  // 深色模式开关：双向绑定 AppStorage，切换后页面配色同步刷新
  @StorageLink('darkMode') isDark: boolean = false;
  private store: Store = Store.get();

  // 提交登录 / 注册：调用后端接口，失败时直接展示服务端返回的文案
  private async handleSubmit(): Promise<void> {
    if (this.loading) {
      return;
    }
    if (this.account.trim() === '') {
      this.errorMsg = '请输入账号';
      return;
    }
    if (this.password === '') {
      this.errorMsg = '请输入密码';
      return;
    }
    if (this.mode === 1 && this.confirm !== this.password) {
      this.errorMsg = '两次输入的密码不一致';
      return;
    }
    this.errorMsg = '';
    this.loading = true;

    const result: AuthResult = this.mode === 0
      ? await Api.login(this.account.trim(), this.password)
      : await Api.register(this.account.trim(), this.password);

    if (!result.ok || result.data === null) {
      this.loading = false;
      this.errorMsg = result.message;
      return;
    }

    const data: AuthData = result.data;
    await this.store.login(data.token, data.nickname, data.avatar, data.userId);
    // 登录后同步云端进度（新设备直接恢复，老设备做并集合并）
    await CloudSync.bootstrap();
    this.loading = false;

    // 若从“我的”页进入则返回原页面，否则（欢迎页进入）替换为首页
    if (Number(router.getLength()) > 1) {
      router.back();
    } else {
      router.replaceUrl({ url: 'pages/Index' });
    }
  }

  private skipLogin(): void {
    router.replaceUrl({ url: 'pages/Index' });
  }

  private switchMode(mode: number): void {
    if (this.mode === mode) {
      return;
    }
    this.mode = mode;
    this.errorMsg = '';
  }

  @Builder
  ModeTabs() {
    Row({ space: 8 }) {
      Text('登录')
        .fontSize(15)
        .fontWeight(this.mode === 0 ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.mode === 0 ? Theme.accent(this.isDark) : Theme.inkSecondary(this.isDark))
        .backgroundColor(this.mode === 0 ? Theme.accentSoft(this.isDark) : Theme.glass(this.isDark))
        .backgroundBlurStyle(BlurStyle.Thin)
        .border({ width: 1, color: Theme.glassBorder(this.isDark) })
        .borderRadius(20)
        .shadow({ radius: 12, color: 'rgba(0, 0, 0, 0.25)', offsetY: 4 })
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.switchMode(0);
        })
      Text('注册')
        .fontSize(15)
        .fontWeight(this.mode === 1 ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.mode === 1 ? Theme.accent(this.isDark) : Theme.inkSecondary(this.isDark))
        .backgroundColor(this.mode === 1 ? Theme.accentSoft(this.isDark) : Theme.glass(this.isDark))
        .backgroundBlurStyle(BlurStyle.Thin)
        .border({ width: 1, color: Theme.glassBorder(this.isDark) })
        .borderRadius(20)
        .shadow({ radius: 12, color: 'rgba(0, 0, 0, 0.25)', offsetY: 4 })
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .onClick(() => {
          this.switchMode(1);
        })
    }
    .width('100%')
    .margin({ top: 32 })
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          // 品牌文字主视觉：Yoji. 纯白大字
          Text('Yoji.')
            .fontSize(44)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
            .margin({ top: 48 })
          Text(this.mode === 0 ? '登录后同步你的学习进度' : '注册一个账号，开启背词之旅')
            .fontSize(13)
            .fontColor('rgba(255, 255, 255, 0.8)')
            .margin({ top: 8 })

          // 登录 / 注册切换
          this.ModeTabs()

          // 表单卡片
          Column() {
            TextInput({ placeholder: '请输入账号', text: this.account })
              .height(50)
              .fontSize(15)
              .fontColor(Theme.ink(this.isDark))
              .placeholderColor(Theme.inkTertiary(this.isDark))
              .backgroundColor(Theme.bg(this.isDark))
              .borderRadius(14)
              .padding({ left: 16, right: 16 })
              .onChange((value: string) => {
                this.account = value;
              })

            TextInput({ placeholder: '请输入密码', text: this.password })
              .height(50)
              .fontSize(15)
              .type(InputType.Password)
              .showPasswordIcon(true)
              .fontColor(Theme.ink(this.isDark))
              .placeholderColor(Theme.inkTertiary(this.isDark))
              .backgroundColor(Theme.bg(this.isDark))
              .borderRadius(14)
              .padding({ left: 16, right: 16 })
              .margin({ top: 14 })
              .onChange((value: string) => {
                this.password = value;
              })

            if (this.mode === 1) {
              TextInput({ placeholder: '请再次输入密码', text: this.confirm })
                .height(50)
                .fontSize(15)
                .type(InputType.Password)
                .showPasswordIcon(true)
                .fontColor(Theme.ink(this.isDark))
                .placeholderColor(Theme.inkTertiary(this.isDark))
                .backgroundColor(Theme.bg(this.isDark))
                .borderRadius(14)
                .padding({ left: 16, right: 16 })
                .margin({ top: 14 })
                .onChange((value: string) => {
                  this.confirm = value;
                })
            }

            if (this.errorMsg !== '') {
              Text(this.errorMsg)
                .fontSize(13)
                .fontColor(Theme.danger(this.isDark))
                .margin({ top: 12 })
                .width('100%')
            }

            Button(this.loading ? '请稍候…' : (this.mode === 0 ? '登 录' : '注 册'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .type(ButtonType.Capsule)
              .backgroundColor(Theme.accentGlassStrong(this.isDark))
              .backgroundBlurStyle(BlurStyle.Thin)
              .border({ width: 1, color: Theme.accentGlassBorder(this.isDark) })
              .fontColor(Theme.accent(this.isDark))
              .shadow({ radius: 16, color: 'rgba(61, 90, 241, 0.45)', offsetY: 6 })
              .height(52)
              .width('100%')
              .margin({ top: 20 })
              .onClick(() => {
                this.handleSubmit();
              })
          }
          // 玻璃表单卡：渐变背景上的半透明玻璃，模糊透出背景色
          .backgroundColor(Theme.glass(this.isDark))
          .backgroundBlurStyle(BlurStyle.Thin)
          .border({ width: 1, color: Theme.glassBorder(this.isDark) })
          .borderRadius(24)
          .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.30)', offsetY: 8 })
          .padding(24)
          .width('100%')
          .margin({ top: 20 })

          // 跳过登录
          Text('暂不登录，先逛逛 ›')
            .fontSize(13)
            .fontColor('rgba(255, 255, 255, 0.8)')
            .margin({ top: 24 })
            .onClick(() => {
              this.skipLogin();
            })
        }
        .padding({ left: 28, right: 28, bottom: 32 })
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    // 背景：#0077ff → #000000 线性渐变，角度 52°（与欢迎页一致）
    .linearGradient({
      angle: 52,
      colors: [['#0077ff', 0.0], ['#000000', 1.0]]
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
