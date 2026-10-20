// Yoji. · 主题色板：浅色（浅灰底 + 靛蓝主色）与深色（深灰底 + 亮靛蓝主色）两套配色。
// 颜色方法统一接收 dark 参数，调用处必须传入组件的 @StorageLink('darkMode') 响应式变量，
// 如 Theme.ink(this.isDark)。这样表达式显式依赖 isDark，主题切换时 ArkUI 部分更新机制
// 才会重新求值并刷新；若使用无参 getter，表达式无状态依赖，重渲染时会被复用旧值导致页面不换色。
export class Theme {
  static readonly darkKey: string = 'darkMode';

  // 当前是否为深色模式（供非 UI 逻辑读取）
  static isDark(): boolean {
    return AppStorage.get<boolean>(Theme.darkKey) ?? false;
  }

  // 页面背景：浅灰 / 深灰
  static bg(dark: boolean): string {
    return dark ? '#16181D' : '#F5F6F8';
  }

  // 卡片与白色模块：纯白 / 深灰
  static card(dark: boolean): string {
    return dark ? '#23262E' : '#FFFFFF';
  }

  // 主文字：深墨 / 浅灰白
  static ink(dark: boolean): string {
    return dark ? '#ECEEF4' : '#1B1E28';
  }

  // 次级文字
  static inkSecondary(dark: boolean): string {
    return dark ? '#A6ADBC' : '#6B7280';
  }

  // 弱化文字
  static inkTertiary(dark: boolean): string {
    return dark ? '#6E7684' : '#A5ABB8';
  }

  // 主色：深色下提亮，保证与深底的对比度
  static accent(dark: boolean): string {
    return dark ? '#7B93FF' : '#3D5AF1';
  }

  // 主色浅底（选中态胶囊、词性标签底）
  static accentSoft(dark: boolean): string {
    return dark ? '#2B3350' : '#EAEEFE';
  }

  static success(dark: boolean): string {
    return dark ? '#4ADE80' : '#16A34A';
  }

  static successSoft(dark: boolean): string {
    return dark ? '#1C3328' : '#E8F7EE';
  }

  static warning(dark: boolean): string {
    return dark ? '#FBBF24' : '#F59E0B';
  }

  static warningSoft(dark: boolean): string {
    return dark ? '#3A301E' : '#FEF3E2';
  }

  // 危险/错误色（答错选项、清空数据、登录错误提示）
  static danger(dark: boolean): string {
    return dark ? '#F87171' : '#DC2626';
  }

  // 危险色浅底（答错选项背景）
  static dangerSoft(dark: boolean): string {
    return dark ? '#3B2024' : '#FDEAEA';
  }

  // 分隔线
  static line(dark: boolean): string {
    return dark ? '#2E333D' : '#ECEEF2';
  }

  // 底部导航玻璃胶囊底色与描边（深色下换成深色玻璃）
  static glass(dark: boolean): string {
    return dark ? 'rgba(35, 38, 46, 0.80)' : 'rgba(255, 255, 255, 0.72)';
  }

  static glassBorder(dark: boolean): string {
    return dark ? 'rgba(255, 255, 255, 0.10)' : 'rgba(255, 255, 255, 0.70)';
  }

  // 液态玻璃彩色变体：首页卡片与按钮保持各自语义色的玻璃质感
  static accentGlass(dark: boolean): string {
    return dark ? 'rgba(123, 147, 255, 0.18)' : 'rgba(61, 90, 241, 0.12)';
  }

  static accentGlassBorder(dark: boolean): string {
    return dark ? 'rgba(123, 147, 255, 0.40)' : 'rgba(61, 90, 241, 0.32)';
  }

  // 主按钮玻璃底：比 accentGlass 更浓，突出“开始学习”主入口
  static accentGlassStrong(dark: boolean): string {
    return dark ? 'rgba(123, 147, 255, 0.28)' : 'rgba(61, 90, 241, 0.20)';
  }

  static successGlass(dark: boolean): string {
    return dark ? 'rgba(74, 222, 128, 0.14)' : 'rgba(22, 163, 74, 0.10)';
  }

  static successGlassBorder(dark: boolean): string {
    return dark ? 'rgba(74, 222, 128, 0.34)' : 'rgba(22, 163, 74, 0.26)';
  }

  static warningGlass(dark: boolean): string {
    return dark ? 'rgba(251, 191, 36, 0.14)' : 'rgba(245, 158, 11, 0.10)';
  }

  static warningGlassBorder(dark: boolean): string {
    return dark ? 'rgba(251, 191, 36, 0.34)' : 'rgba(245, 158, 11, 0.26)';
  }

  // 大块纯色背景（日历、视频播放页下半部分）：浅色为纯白，深色与页面背景一致
  static surface(dark: boolean): string {
    return dark ? '#16181D' : '#FFFFFF';
  }

  // 月亮按钮图标色：深色下暖黄（月亮发光），浅色下墨色
  static moon(dark: boolean): string {
    return dark ? '#F7D774' : '#1B1E28';
  }
}
