import { Store } from '../store/Store';
import { Theme } from '../common/Theme';

// 深色模式切换按钮：月亮图案，放在各主页面右上角、与左侧标题对齐。
// 点击时月亮旋转一圈并弹性缩放，同步切换全局主题（浅色 ↔ 深色）并持久化保存；
// 深色模式下月亮为暖黄色发光效果，浅色模式下为墨色。
@Component
export struct ThemeToggle {
  // 双向绑定 AppStorage('darkMode')：任一页面切换，所有页面同步刷新配色
  @StorageLink('darkMode') isDark: boolean = false;
  // 点击动效状态：月亮旋转角度与缩放（命名避开组件 scale() 属性方法）
  @State spin: number = 0;
  @State scaleValue: number = 1;
  private store: Store = Store.get();

  // 切换主题：先同步更新 AppStorage（所有页面立即变色），再执行月亮旋转缩放动效
  private onToggle(): void {
    const next = !this.isDark;
    // ⚠️ 不能在 animateTo 闭包内修改 @StorageLink/AppStorage：状态同步会被动画系统
    // 延迟甚至吞掉，导致其他页面的 @StorageLink 收不到更新通知、页面不刷新。
    // 必须先在闭包外同步写入，保证即时全局变色。
    AppStorage.setOrCreate<boolean>(Theme.darkKey, next);
    // 持久化到 Store，下次启动保持所选主题
    this.store.setDarkMode(next);
    // 图标动效：先缩小再旋转弹回（仅操作局部 @State，与主题同步无关）
    this.scaleValue = 0.5;
    animateTo({ duration: 420, curve: Curve.Friction }, () => {
      this.spin += 360;
      this.scaleValue = 1;
    });
  }

  build() {
    Column() {
      SymbolGlyph(this.isDark ? $r('sys.symbol.moon_fill') : $r('sys.symbol.moon'))
        .fontSize(20)
        .fontColor([Theme.moon(this.isDark)])
        .rotate({ angle: this.spin })
        .scale({ x: this.scaleValue, y: this.scaleValue })
    }
    .width(40)
    .height(40)
    .borderRadius(20)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(Theme.card(this.isDark))
    .border({ width: 1, color: this.isDark ? Theme.line(this.isDark) : 'rgba(27, 30, 40, 0.06)' })
    .shadow({ radius: 10, color: 'rgba(27, 30, 40, 0.12)', offsetY: 3 })
    .onClick(() => {
      this.onToggle();
    })
  }
}
