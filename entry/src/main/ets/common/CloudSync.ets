import { Api } from './Api';
import { Store } from '../store/Store';

// 云端同步：登录/启动时合并拉取，学习过程中防抖推送。
// 后端采用「并集合并」，多设备不会互相覆盖。
export class CloudSync {
  private static timer: number = -1;
  private static pushing: boolean = false;
  private static dirty: boolean = false;

  // 登录成功 / App 启动时调用：本地无数据则拉取云端，本地有数据则合并
  static async bootstrap(): Promise<void> {
    const store: Store = Store.get();
    if (!store.isLoggedIn || store.token === '') {
      return;
    }
    const remote = await Api.getProgress(store.token);
    if (!remote.ok || remote.data === null) {
      return;
    }

    // 云端还是空的：把本地设置/进度推上去，避免服务端默认值覆盖本地偏好
    if (remote.data.version === 0) {
      const merged = await Api.syncProgress(store.token, store.toSnapshot());
      if (merged.ok && merged.data !== null) {
        store.syncVersion = merged.data.version;
      }
      return;
    }

    // 本地没有学习数据（新设备 / 刚登录）：直接采用云端
    if (!store.hasLearningData()) {
      await store.applySnapshot(remote.data.data);
      store.syncVersion = remote.data.version;
      CloudSync.notifyApplied(store);
      return;
    }

    // 两边都有数据：交给服务端并集合并，再把权威结果写回本地
    const merged = await Api.syncProgress(store.token, store.toSnapshot());
    if (merged.ok && merged.data !== null) {
      await store.applySnapshot(merged.data.data);
      store.syncVersion = merged.data.version;
      CloudSync.notifyApplied(store);
    }
  }

  // 学习进度变化后调用：1.5 秒防抖，避免每滑一个词都发请求
  static schedulePush(): void {
    const store: Store = Store.get();
    if (!store.isLoggedIn || store.token === '') {
      return;
    }
    if (CloudSync.timer >= 0) {
      clearTimeout(CloudSync.timer);
    }
    CloudSync.timer = setTimeout(() => {
      CloudSync.timer = -1;
      CloudSync.pushNow();
    }, 1500);
  }

  static async pushNow(): Promise<void> {
    const store: Store = Store.get();
    if (!store.isLoggedIn || store.token === '') {
      return;
    }
    if (CloudSync.pushing) {
      CloudSync.dirty = true;
      return;
    }
    CloudSync.pushing = true;
    const result = await Api.syncProgress(store.token, store.toSnapshot());
    if (result.ok && result.data !== null) {
      store.syncVersion = result.data.version;
    } else {
      console.warn(`[CloudSync] 进度同步失败: ${result.message}`);
    }
    CloudSync.pushing = false;
    if (CloudSync.dirty) {
      CloudSync.dirty = false;
      CloudSync.schedulePush();
    }
  }

  // 清空学习记录后，把空进度强制覆盖到云端
  static async resetRemote(): Promise<void> {
    const store: Store = Store.get();
    if (!store.isLoggedIn || store.token === '') {
      return;
    }
    const result = await Api.saveProgressForce(store.token, store.toSnapshot());
    if (result.ok && result.data !== null) {
      store.syncVersion = result.data.version;
    }
  }

  // 退出登录：先尽量把最新进度推上去，再让服务端作废旧 token
  static async logout(): Promise<void> {
    const store: Store = Store.get();
    if (CloudSync.timer >= 0) {
      clearTimeout(CloudSync.timer);
      CloudSync.timer = -1;
    }
    if (store.token !== '') {
      await CloudSync.pushNow();
      await Api.logout(store.token);
    }
    await store.logout();
  }

  // 云端数据应用到本地后通知 UI：同步主题与刷新标记
  private static notifyApplied(store: Store): void {
    AppStorage.setOrCreate('darkMode', store.darkMode);
    AppStorage.setOrCreate('syncTick', Date.now());
  }
}
