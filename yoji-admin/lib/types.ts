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

export interface AdminWord {
  id: string;
  word: string;
  phonetic: string;
  meaning: string;
  example: string;
  exampleCn: string;
}

export interface AdminWordBook {
  id: string;
  name: string;
  subtitle: string;
  description: string;
  source: string;
  wordCount: number;
  visible: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

export interface AdminWordBookDetail extends AdminWordBook {
  words: AdminWord[];
}

export interface AdminWordBooksPayload {
  books: AdminWordBook[];
}

export interface AuditLog {
  id: number;
  account: string;
  action: string;
  target: string;
  detail: string;
  ip: string;
  createdAt: string;
}

export interface AuditLogsPayload {
  logs: AuditLog[];
  total: number;
  page: number;
  pageSize: number;
}

export interface StorageInfo {
  mode: "oss" | "local";
  publicBase: string | null;
  dir: string | null;
}

export interface UploadTicket {
  mode: "oss";
  host: string;
  key: string;
  policy: string;
  signature: string;
  accessKeyId: string;
  expire: string;
  maxBytes: number;
  publicUrl: string;
}
