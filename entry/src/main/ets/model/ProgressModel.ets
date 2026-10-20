import { Word } from './WordModel';

// 与后端 /api/progress 对应的进度快照结构
export interface ProgressSnapshot {
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
  videoProgress: Record<string, number>;
  darkMode: boolean;
  // v1.2.0 新增：个人资料与视频相关数据（旧版后端可能不返回）
  nickname?: string;
  gender?: string;
  birthday?: string;
  favoriteVideos?: Record<string, string>;
  customWords?: Word[];
}

// 云端返回的进度包：version 用于写入时的乐观锁
export interface ProgressPayload {
  version: number;
  updatedAt: string;
  data: ProgressSnapshot;
}
