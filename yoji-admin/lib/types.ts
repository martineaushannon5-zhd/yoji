export interface AdminUser {
  id: string;
  account: string;
  nickname: string;
  avatar: string;
  createdAt: string;
  mastered: number;
  learning: number;
  learnedDays: number;
  lastLearnDate: string;
  todayLearned: number;
  streak: number;
  favoriteCount: number;
  favoriteVideoCount: number;
  customWordCount: number;
}

export interface AdminUsersPayload {
  users: AdminUser[];
  total: number;
  page: number;
  pageSize: number;
}

export interface TrendPoint {
  date: string;
  label: string;
  newUsers: number;
  activeUsers: number;
}

export interface AdminStats {
  totalUsers: number;
  todayActive: number;
  totalWords: number;
  masteredWords: number;
  totalVideos: number;
  newUsers7d: number;
  trend: TrendPoint[];
}

export interface AdminLoginPayload {
  token: string;
  account: string;
  expiresIn: string;
}

export interface AdminVideo {
  id: string;
  title: string;
  description: string;
  date: string;
  thumbUrl: string;
  videoUrl: string;
  duration: number;
  sortOrder: number;
  visible: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface AdminVideosPayload {
  videos: AdminVideo[];
}
