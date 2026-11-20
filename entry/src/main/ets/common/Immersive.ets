import { common } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';

// 沉浸式布局：把状态栏 / 底部导航条做成透明，并读取避让区高度供页面留白使用。
// 只在需要的页面开启（首页），离开时恢复系统默认布局，避免其它页面内容压到状态栏下面。

export const INSET_STATUS_BAR = 'insetStatusBarPx';
export const INSET_NAV_BAR = 'insetNavBarPx';

function publishInsets(win: window.Window): void {
  const system = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
  const indicator = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
  AppStorage.setOrCreate(INSET_STATUS_BAR, system.topRect.height);
  AppStorage.setOrCreate(INSET_NAV_BAR, indicator.bottomRect.height);
}

export async function enterImmersive(ctx: common.UIAbilityContext, dark: boolean): Promise<void> {
  try {
    const win = await window.getLastWindow(ctx);
    await win.setWindowLayoutFullScreen(true);
    await win.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: dark ? '#FFFFFF' : '#000000',
      navigationBarContentColor: dark ? '#FFFFFF' : '#000000'
    });
    publishInsets(win);
  } catch (err) {
    // 老设备或平板分屏下可能不支持全屏，保持默认布局即可，不影响功能
    console.error(`enterImmersive failed: ${JSON.stringify(err)}`);
  }
}

export async function exitImmersive(ctx: common.UIAbilityContext): Promise<void> {
  try {
    const win = await window.getLastWindow(ctx);
    await win.setWindowLayoutFullScreen(false);
    AppStorage.setOrCreate(INSET_STATUS_BAR, 0);
    AppStorage.setOrCreate(INSET_NAV_BAR, 0);
  } catch (err) {
    console.error(`exitImmersive failed: ${JSON.stringify(err)}`);
  }
}

// 深色模式切换后同步系统栏文字颜色（不重新计算避让区）
export async function refreshBarStyle(ctx: common.UIAbilityContext, dark: boolean): Promise<void> {
  try {
    const win = await window.getLastWindow(ctx);
    await win.setWindowSystemBarProperties({
      statusBarColor: '#00000000',
      navigationBarColor: '#00000000',
      statusBarContentColor: dark ? '#FFFFFF' : '#000000',
      navigationBarContentColor: dark ? '#FFFFFF' : '#000000'
    });
  } catch (err) {
    console.error(`refreshBarStyle failed: ${JSON.stringify(err)}`);
  }
}