// 词书 / 单词 / 学习状态的数据模型
export interface Word {
  id: string;
  word: string;
  phonetic: string;
  meaning: string;
  example: string;
  exampleCn: string;
  // 所属视频 id：用户在视频页手动添加的单词才有值，用于按视频展示
  videoId?: string;
}

export interface WordBook {
  id: string;
  name: string;
  subtitle: string;
  icon: ResourceStr;
  words: Word[];
}

// 学习状态：0 未学，1 学习中，2 已掌握
export const STATUS_NEW: number = 0;
export const STATUS_LEARNING: number = 1;
export const STATUS_MASTERED: number = 2;

export interface QuizOption {
  wordId: string;
  meaning: string;
  isAnswer: boolean;
}

export interface LearnResult {
  known: number;
  unknown: number;
  total: number;
}
