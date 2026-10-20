import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { STATUS_LEARNING, STATUS_MASTERED, STATUS_NEW, Word } from '../model/WordModel';
import { CUSTOM_BOOK } from '../data/WordData';

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
  private pref: preferences.Preferences | undefined = undefined;

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

  // 任意一次学习行为（含复习已掌握词）都算坚持一天
  private markTodayActive(): void {
    if (this.lastLearnDate !== Store.today()) {
      this.lastLearnDate = Store.today();
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
  async login(token: string, nickname: string = '', avatar: string = ''): Promise<void> {
    this.token = token;
    this.nickname = nickname;
    this.avatar = avatar;
    this.isLoggedIn = true;
    await this.save();
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
    this.learnedLog = {};
    this.todayLearned = 0;
    this.streak = 0;
    this.totalLearned = 0;
    this.learnedDays = 0;
    this.lastLearnDate = '';
    await this.save();
  }

  private async save(): Promise<void> {
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
  }
}
