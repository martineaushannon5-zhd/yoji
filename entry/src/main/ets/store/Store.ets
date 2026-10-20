import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { STATUS_LEARNING, STATUS_MASTERED, STATUS_NEW, Word } from '../model/WordModel';
import { CUSTOM_BOOK } from '../data/WordData';
import { ProgressSnapshot } from '../model/ProgressModel';

interface PersistData {
  currentBookId: string;
  dailyTarget: number;
  statusMap: Record<string, number>;
  masteredAt: Record<string, string>;
  learnedLog: Record<string, string[]>;
  favorites: Record<string, string>;
  swipeGuideShown: boolean;
  todayLearned: number;
  todayDate: string;
  streak: number;
  totalLearned: number;
  learnedDays: number;
  lastLearnDate: string;
  isLoggedIn: boolean;
  token: string;
  userId: string;
  nickname: string;
  avatar: string;
  gender: string;
  birthday: string;
  videoProgress: Record<string, number>;
  favoriteVideos: Record<string, string>;
  darkMode: boolean;
  // 用户在视频页手动添加的单词（自填词库）
  customWords: Word[];
}

// 全局学习进度存储，基于 Preferences 持久化
export class Store {
  private static instance: Store | undefined = undefined;

  currentBookId: string = 'cet4';
  dailyTarget: number = 10;
  statusMap: Record<string, number> = {};
  masteredAt: Record<string, string> = {};
  learnedLog: Record<string, string[]> = {};
  // 收藏（单词本）：wordId -> 收藏日期，用于按收藏时间排序
  favorites: Record<string, string> = {};
  // 学词页滑动引导是否已展示过（仅首次进入学词时显示一次）
  swipeGuideShown: boolean = false;
  todayLearned: number = 0;
  todayDate: string = '';
  streak: number = 0;
  totalLearned: number = 0;
  learnedDays: number = 0;
  lastLearnDate: string = '';
  isLoggedIn: boolean = false;
  token: string = '';
  // 上一次登录的用户 id：换账号登录时用于清空上一个账号的本地进度
  userId: string = '';
  nickname: string = '';
  avatar: string = '';
  // 性别（男/女）与生日（YYYY-MM-DD），由“编辑资料”页维护
  gender: string = '';
  birthday: string = '';
  // 视频播放进度：videoId -> 已播放秒数（供播放页续播）
  videoProgress: Record<string, number> = {};
  // 收藏（喜欢的视频）：videoId -> 收藏日期，用于按收藏时间排序
  favoriteVideos: Record<string, string> = {};
  // 深色模式开关（切换主题后持久化，重启保持）
  darkMode: boolean = false;
  // 用户在视频页手动添加的单词（自填词库），由 Store 统一持久化
  customWords: Word[] = [];
  // 云端进度版本号：来自后端，用于覆盖写入时的乐观锁
  syncVersion: number = 0;
  // 每次持久化后的回调：由启动页注册为「防抖上云」，Store 本身不依赖网络层
  onSaved: (() => void) | undefined = undefined;
  private pref: preferences.Preferences | undefined = undefined;
  private initialized: boolean = false;

  static get(): Store {
    if (!Store.instance) {
      Store.instance = new Store();
    }
    return Store.instance;
  }

  private static today(): string {
    const d = new Date();
    const month = (d.getMonth() + 1).toString();
    const day = d.getDate().toString();
    return `${d.getFullYear()}-${month}-${day}`;
  }

  async init(context: common.UIAbilityContext): Promise<void> {
    // 启动页与首页都会调用 init，这里做幂等保护，避免重复读盘覆盖内存中的最新进度
    if (this.initialized) {
      return;
    }
    this.pref = await preferences.getPreferences(context, 'wancizhan');
    const raw = await this.pref.get('data', '{}') as string;
    const data: PersistData = JSON.parse(raw) as PersistData;
    this.currentBookId = data.currentBookId ?? 'cet4';
    // 自填词库只是视频单词笔记，不作为可选词库：历史选择过则回退到默认词书
    if (this.currentBookId === 'custom') {
      this.currentBookId = 'cet4';
    }
    this.dailyTarget = data.dailyTarget ?? 10;
    this.statusMap = data.statusMap ?? {};
    this.masteredAt = data.masteredAt ?? {};
    this.learnedLog = data.learnedLog ?? {};
    this.favorites = data.favorites ?? {};
    this.swipeGuideShown = data.swipeGuideShown ?? false;
    // 兼容旧数据：无学习日志时，由掌握日期回填，保证日历可展示历史掌握记录
    if (Object.keys(this.learnedLog).length === 0 && Object.keys(this.masteredAt).length > 0) {
      const ids = Object.keys(this.masteredAt);
      for (let i = 0; i < ids.length; i++) {
        const d = this.masteredAt[ids[i]];
        if (d !== undefined && d !== '') {
          if (!this.learnedLog[d]) {
            this.learnedLog[d] = [];
          }
          if (this.learnedLog[d].indexOf(ids[i]) < 0) {
            this.learnedLog[d].push(ids[i]);
          }
        }
      }
    }
    this.todayLearned = data.todayLearned ?? 0;
    this.todayDate = data.todayDate ?? '';
    this.streak = data.streak ?? 0;
    this.totalLearned = data.totalLearned ?? 0;
    this.learnedDays = data.learnedDays ?? 0;
    this.lastLearnDate = data.lastLearnDate ?? '';
    this.isLoggedIn = data.isLoggedIn ?? false;
    this.token = data.token ?? '';
    this.userId = data.userId ?? '';
    this.nickname = data.nickname ?? '';
    this.avatar = data.avatar ?? '';
    this.gender = data.gender ?? '';
    this.birthday = data.birthday ?? '';
    this.videoProgress = data.videoProgress ?? {};
    this.favoriteVideos = data.favoriteVideos ?? {};
    this.darkMode = data.darkMode ?? false;
    this.customWords = data.customWords ?? [];
    // 将持久化的自填单词注入"自填词库"，后续添加时保持同一数组引用
    CUSTOM_BOOK.words = this.customWords;
    // 跨天重置今日进度
    if (this.todayDate !== Store.today()) {
      this.todayLearned = 0;
      this.todayDate = Store.today();
      await this.save();
    }
    this.initialized = true;
  }

  // 本地是否有真实学习数据（用于判断登录后是否需要用云端覆盖本地）
  hasLearningData(): boolean {
    return Object.keys(this.statusMap).length > 0 ||
      Object.keys(this.learnedLog).length > 0 ||
      Object.keys(this.favorites).length > 0 ||
      Object.keys(this.favoriteVideos).length > 0 ||
      Object.keys(this.masteredAt).length > 0 ||
      this.customWords.length > 0 ||
      this.totalLearned > 0;
  }

  // 导出与后端约定的进度快照（不含登录态字段）
  toSnapshot(): ProgressSnapshot {
    const snapshot: ProgressSnapshot = {
      currentBookId: this.currentBookId,
      dailyTarget: this.dailyTarget,
      statusMap: this.statusMap,
      masteredAt: this.masteredAt,
      learnedLog: this.learnedLog,
      favorites: this.favorites,
      swipeGuideShown: this.swipeGuideShown,
      todayLearned: this.todayLearned,
      todayDate: this.todayDate,
      streak: this.streak,
      totalLearned: this.totalLearned,
      learnedDays: this.learnedDays,
      lastLearnDate: this.lastLearnDate,
      videoProgress: this.videoProgress,
      darkMode: this.darkMode,
      nickname: this.nickname,
      gender: this.gender,
      birthday: this.birthday,
      favoriteVideos: this.favoriteVideos,
      customWords: this.customWords
    };
    return snapshot;
  }

  // 应用云端返回的进度快照（登录 / 启动同步时调用），保留本地登录态与本地头像
  async applySnapshot(snapshot: ProgressSnapshot): Promise<void> {
    this.currentBookId = snapshot.currentBookId;
    this.dailyTarget = snapshot.dailyTarget;
    this.statusMap = snapshot.statusMap;
    this.masteredAt = snapshot.masteredAt;
    this.learnedLog = snapshot.learnedLog;
    this.favorites = snapshot.favorites;
    this.swipeGuideShown = snapshot.swipeGuideShown;
    this.todayLearned = snapshot.todayLearned;
    this.todayDate = snapshot.todayDate;
    this.streak = snapshot.streak;
    this.totalLearned = snapshot.totalLearned;
    this.learnedDays = snapshot.learnedDays;
    this.lastLearnDate = snapshot.lastLearnDate;
    this.videoProgress = snapshot.videoProgress;
    this.darkMode = snapshot.darkMode;
    // 旧版后端不返回 v1.2.0 新增字段，缺失时保留本地数据，避免被默认值清空
    if (snapshot.nickname !== undefined && snapshot.nickname !== '') {
      this.nickname = snapshot.nickname;
    }
    if (snapshot.gender !== undefined) {
      this.gender = snapshot.gender;
    }
    if (snapshot.birthday !== undefined) {
      this.birthday = snapshot.birthday;
    }
    if (snapshot.favoriteVideos !== undefined) {
      this.favoriteVideos = snapshot.favoriteVideos;
    }
    if (snapshot.customWords !== undefined) {
      this.customWords = snapshot.customWords;
      CUSTOM_BOOK.words = this.customWords;
    }
    // 头像目前是设备本地沙箱路径，不能跨设备同步，应用快照时保留本地头像
    // 云端快照可能来自别的日期：跨天时今日进度归零
    if (this.todayDate !== Store.today()) {
      this.todayLearned = 0;
      this.todayDate = Store.today();
    }
    // 应用云端数据时不再回调上云，避免「拉取 → 推送」循环
    await this.save(false);
  }

  statusOf(wordId: string): number {
    const s = this.statusMap[wordId];
    return s === undefined ? STATUS_NEW : s;
  }

  // 是否已收藏该单词
  isFavorite(wordId: string): boolean {
    return this.favorites[wordId] !== undefined;
  }

  // 今天是否为用户生日（birthday 格式 YYYY-MM-DD，仅比较月日）
  isBirthdayToday(): boolean {
    if (this.birthday === '') {
      return false;
    }
    const parts = this.birthday.split('-');
    if (parts.length < 3) {
      return false;
    }
    const d = new Date();
    return Number(parts[1]) === d.getMonth() + 1 && Number(parts[2]) === d.getDate();
  }

  // 切换收藏状态，返回切换后是否为已收藏
  async toggleFavorite(wordId: string): Promise<boolean> {
    if (this.isFavorite(wordId)) {
      // ArkTS 不支持 delete，重建 Record 以移除该键
      const next: Record<string, string> = {};
      const keys = Object.keys(this.favorites);
      for (let i = 0; i < keys.length; i++) {
        if (keys[i] !== wordId) {
          next[keys[i]] = this.favorites[keys[i]];
        }
      }
      this.favorites = next;
      await this.save();
      return false;
    }
    this.favorites[wordId] = Store.today();
    await this.save();
    return true;
  }

  private static yesterday(): string {
    const d = new Date();
    d.setDate(d.getDate() - 1);
    const month = (d.getMonth() + 1).toString();
    const day = d.getDate().toString();
    return `${d.getFullYear()}-${month}-${day}`;
  }

  // 任意一次学习行为（含复习已掌握词）都算坚持一天
  private markTodayActive(): void {
    const today = Store.today();
    if (this.lastLearnDate !== today) {
      // 昨天也学过则连续 +1，否则从今天重新计数
      if (this.lastLearnDate === Store.yesterday()) {
        this.streak += 1;
      } else {
        this.streak = 1;
      }
      this.lastLearnDate = today;
      this.learnedDays += 1;
    }
  }

  // 记录当天学过的单词（供学习日历展示）
  private logToday(wordId: string): void {
    const today = Store.today();
    if (!this.learnedLog[today]) {
      this.learnedLog[today] = [];
    }
    const list = this.learnedLog[today];
    if (list.indexOf(wordId) < 0) {
      list.push(wordId);
    }
  }

  // 学完一个词，返回 true 表示状态有变化
  async markLearned(wordId: string, known: boolean): Promise<boolean> {
    this.markTodayActive();
    this.logToday(wordId);
    const old = this.statusOf(wordId);
    if (!known) {
      if (old !== STATUS_LEARNING) {
        this.statusMap[wordId] = STATUS_LEARNING;
        if (old === STATUS_MASTERED) {
          // 降级为学习中，清除掌握日期
          this.masteredAt[wordId] = '';
        }
        this.todayLearned += 1;
        await this.save();
        return true;
      }
      // 状态没变，但今天的学习记录 / 连续天数可能已更新，仍需落盘
      await this.save();
      return false;
    }
    this.statusMap[wordId] = STATUS_MASTERED;
    if (old === STATUS_NEW) {
      this.todayLearned += 1;
      this.totalLearned += 1;
    }
    if (old !== STATUS_MASTERED) {
      // 首次掌握时记录掌握日期
      this.masteredAt[wordId] = Store.today();
    }
    await this.save();
    return true;
  }

  // 是否已看过学词页的滑动引导
  hasSeenSwipeGuide(): boolean {
    return this.swipeGuideShown;
  }

  // 标记滑动引导已展示（仅首次进入学词页时调用）
  async markSwipeGuideSeen(): Promise<void> {
    this.swipeGuideShown = true;
    await this.save();
  }

  async setDailyTarget(n: number): Promise<void> {
    this.dailyTarget = Math.max(5, Math.min(50, n));
    await this.save();
  }

  async setCurrentBook(bookId: string): Promise<void> {
    this.currentBookId = bookId;
    await this.save();
  }

  // 保存深色模式开关（AppStorage 由 UI 的 @StorageLink 同步，这里负责持久化）
  async setDarkMode(dark: boolean): Promise<void> {
    this.darkMode = dark;
    await this.save();
  }

  // 登录/注册成功后保存登录态与用户信息（token/nickname/avatar 由后端接口返回）
  async login(token: string, nickname: string = '', avatar: string = '', userId: string = ''): Promise<void> {
    // 换账号：清掉上一个账号留在本机的进度，避免被推到新账号
    if (this.userId !== '' && userId !== '' && this.userId !== userId) {
      this.resetProgress();
    }
    if (userId !== '') {
      this.userId = userId;
    }
    this.token = token;
    this.nickname = nickname;
    // 后端没有头像上传时 avatar 为空：保留用户在本机设置的头像
    if (avatar !== '') {
      this.avatar = avatar;
    }
    this.isLoggedIn = true;
    // 换账号后云端版本号失效，等待 bootstrap 拉取
    this.syncVersion = 0;
    await this.save();
  }

  // 清空学习进度（保留词库、每日目标、深色模式等偏好）
  private resetProgress(): void {
    this.statusMap = {};
    this.masteredAt = {};
    this.learnedLog = {};
    this.favorites = {};
    this.favoriteVideos = {};
    this.videoProgress = {};
    this.customWords = [];
    CUSTOM_BOOK.words = this.customWords;
    this.todayLearned = 0;
    this.todayDate = Store.today();
    this.streak = 0;
    this.totalLearned = 0;
    this.learnedDays = 0;
    this.lastLearnDate = '';
    // 换账号时资料也重置，避免上一个账号的昵称/头像串到新账号
    this.gender = '';
    this.birthday = '';
    this.avatar = '';
  }

  // 更新个人资料：昵称/性别/生日/头像（头像为应用沙箱内文件路径）
  async updateProfile(nickname: string, gender: string, birthday: string, avatar: string): Promise<void> {
    this.nickname = nickname;
    this.gender = gender;
    this.birthday = birthday;
    this.avatar = avatar;
    await this.save();
  }

  // 保存视频播放进度（供播放页续播）
  async setVideoProgress(videoId: string, t: number): Promise<void> {
    this.videoProgress[videoId] = Math.max(0, Math.floor(t));
    await this.save();
  }

  // 是否已收藏该视频
  isVideoFavorite(videoId: string): boolean {
    return this.favoriteVideos[videoId] !== undefined;
  }

  // 切换视频收藏状态，返回切换后是否为已收藏
  async toggleVideoFavorite(videoId: string): Promise<boolean> {
    if (this.isVideoFavorite(videoId)) {
      // ArkTS 不支持 delete，重建 Record 以移除该键
      const next: Record<string, string> = {};
      const keys = Object.keys(this.favoriteVideos);
      for (let i = 0; i < keys.length; i++) {
        if (keys[i] !== videoId) {
          next[keys[i]] = this.favoriteVideos[keys[i]];
        }
      }
      this.favoriteVideos = next;
      await this.save();
      return false;
    }
    this.favoriteVideos[videoId] = Store.today();
    await this.save();
    return true;
  }

  // 退出登录，清空登录态与用户信息
  async logout(): Promise<void> {
    this.token = '';
    this.isLoggedIn = false;
    this.nickname = '';
    this.avatar = '';
    this.gender = '';
    this.birthday = '';
    this.syncVersion = 0;
    await this.save();
  }

  // 添加用户自定义单词：写入"自填词库"并自动收藏到单词本
  // 词性（pos）为缩写如 "v."，与中文意思组合为 "v. 放弃" 的释义格式；videoId 记录添加时所在视频
  async addCustomWord(word: string, phonetic: string, pos: string, meaningCn: string, videoId: string): Promise<Word> {
    const item: Word = {
      id: `cu-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
      word: word,
      phonetic: phonetic,
      meaning: `${pos} ${meaningCn}`,
      example: '',
      exampleCn: '',
      videoId: videoId
    };
    this.customWords.push(item);
    // 自动收藏：添加的单词同步出现在单词本（favorites 表）中
    this.favorites[item.id] = Store.today();
    await this.save();
    return item;
  }

  // 查询某个视频下用户手动添加的单词（保持添加顺序）
  customWordsOf(videoId: string): Word[] {
    const list: Word[] = [];
    for (let i = 0; i < this.customWords.length; i++) {
      if (this.customWords[i].videoId === videoId) {
        list.push(this.customWords[i]);
      }
    }
    return list;
  }

  // 删除用户自定义单词（同步从单词本收藏中移除）
  async deleteCustomWord(wordId: string): Promise<void> {
    const next: Word[] = [];
    for (let i = 0; i < this.customWords.length; i++) {
      if (this.customWords[i].id !== wordId) {
        next.push(this.customWords[i]);
      }
    }
    this.customWords = next;
    // 数组已替换，同步"自填词库"引用
    CUSTOM_BOOK.words = this.customWords;
    // 从收藏表移除（ArkTS 不支持 delete，重建 Record 以移除该键）
    const favNext: Record<string, string> = {};
    const keys = Object.keys(this.favorites);
    for (let i = 0; i < keys.length; i++) {
      if (keys[i] !== wordId) {
        favNext[keys[i]] = this.favorites[keys[i]];
      }
    }
    this.favorites = favNext;
    await this.save();
  }

  async clearAll(): Promise<void> {
    this.statusMap = {};
    this.masteredAt = {};
    this.learnedLog = {};
    this.todayLearned = 0;
    this.streak = 0;
    this.totalLearned = 0;
    this.learnedDays = 0;
    this.lastLearnDate = '';
    await this.save();
  }

  // notify=false 用于应用云端快照，避免触发「拉取 → 推送」循环
  private async save(notify: boolean = true): Promise<void> {
    if (!this.pref) {
      return;
    }
    const data: PersistData = {
      currentBookId: this.currentBookId,
      dailyTarget: this.dailyTarget,
      statusMap: this.statusMap,
      masteredAt: this.masteredAt,
      learnedLog: this.learnedLog,
      favorites: this.favorites,
      swipeGuideShown: this.swipeGuideShown,
      todayLearned: this.todayLearned,
      todayDate: this.todayDate,
      streak: this.streak,
      totalLearned: this.totalLearned,
      learnedDays: this.learnedDays,
      lastLearnDate: this.lastLearnDate,
      isLoggedIn: this.isLoggedIn,
      token: this.token,
      userId: this.userId,
      nickname: this.nickname,
      avatar: this.avatar,
      gender: this.gender,
      birthday: this.birthday,
      videoProgress: this.videoProgress,
      favoriteVideos: this.favoriteVideos,
      darkMode: this.darkMode,
      customWords: this.customWords
    };
    await this.pref.put('data', JSON.stringify(data));
    await this.pref.flush();
    const callback = this.onSaved;
    if (notify && callback !== undefined) {
      callback();
    }
  }
}
