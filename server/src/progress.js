/**
 * 学习进度快照的清洗与合并。
 *
 * 设计目标：
 * 1. 永远不信任客户端 JSON，只保留白名单字段并做类型/范围校验；
 * 2. 多设备同步采用「并集合并」：学习状态取更高一级、收藏/学习记录取并集、
 *    计数取较大值，避免一端覆盖另一端造成数据丢失；
 * 3. 设置类字段（词书、每日目标、深色模式）以「有数据的一端」为准。
 */

const DATE_RE = /^(\d{4})-(\d{1,2})-(\d{1,2})$/;
const ID_RE = /^[A-Za-z0-9_-]{1,64}$/;

const MAX_WORDS = 50000;
const MAX_DATES = 3650;
const MAX_CUSTOM_WORDS = 5000;

function isPlainObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function asObject(value) {
  return isPlainObject(value) ? value : {};
}

function clampInt(value, min, max, fallback) {
  const n = Number(value);
  if (!Number.isFinite(n)) {
    return fallback;
  }
  return Math.min(max, Math.max(min, Math.trunc(n)));
}

function asText(value, maxLength, fallback = '') {
  if (typeof value !== 'string') {
    return fallback;
  }
  return value.slice(0, maxLength);
}

function asDateKey(value) {
  return typeof value === 'string' && DATE_RE.test(value) ? value : '';
}

// 视频页手动添加的单词：只保留 Word 需要的字段，避免客户端塞入任意 JSON
function sanitizeCustomWords(input) {
  if (!Array.isArray(input)) {
    return [];
  }
  const result = [];
  const seen = new Set();
  for (const item of input) {
    if (result.length >= MAX_CUSTOM_WORDS || !isPlainObject(item)) {
      break;
    }
    const id = asText(item.id, 64);
    const word = asText(item.word, 64).trim();
    if (!ID_RE.test(id) || !word || seen.has(id)) {
      continue;
    }
    seen.add(id);
    const entry = {
      id,
      word,
      phonetic: asText(item.phonetic, 64),
      meaning: asText(item.meaning, 200),
      example: asText(item.example, 500),
      exampleCn: asText(item.exampleCn, 500)
    };
    const videoId = asText(item.videoId, 64);
    if (ID_RE.test(videoId)) {
      entry.videoId = videoId;
    }
    result.push(entry);
  }
  return result;
}

export function sanitizeSnapshot(input) {
  const src = asObject(input);

  const statusMap = {};
  let wordCount = 0;
  for (const [key, value] of Object.entries(asObject(src.statusMap))) {
    if (wordCount >= MAX_WORDS) {
      break;
    }
    if (!ID_RE.test(key)) {
      continue;
    }
    const n = Number(value);
    if (n === 0 || n === 1 || n === 2) {
      statusMap[key] = n;
      wordCount += 1;
    }
  }

  const masteredAt = {};
  let masteredCount = 0;
  for (const [key, value] of Object.entries(asObject(src.masteredAt))) {
    if (!ID_RE.test(key) || masteredCount >= MAX_WORDS) {
      continue;
    }
    const date = asDateKey(value);
    if (date) {
      masteredAt[key] = date;
      masteredCount += 1;
    }
  }

  const learnedLog = {};
  let dateCount = 0;
  for (const [key, value] of Object.entries(asObject(src.learnedLog))) {
    if (dateCount >= MAX_DATES || !DATE_RE.test(key) || !Array.isArray(value)) {
      continue;
    }
    const ids = [];
    const seen = new Set();
    for (const item of value) {
      if (typeof item !== 'string' || !ID_RE.test(item) || seen.has(item)) {
        continue;
      }
      seen.add(item);
      ids.push(item);
      if (ids.length >= 2000) {
        break;
      }
    }
    if (ids.length > 0) {
      learnedLog[key] = ids;
      dateCount += 1;
    }
  }

  const favorites = {};
  let favoriteCount = 0;
  for (const [key, value] of Object.entries(asObject(src.favorites))) {
    if (!ID_RE.test(key) || favoriteCount >= MAX_WORDS) {
      continue;
    }
    // 收藏值可能是日期字符串，也可能只是占位；统一存成合法的日期或空串
    favorites[key] = asDateKey(value);
    favoriteCount += 1;
  }

  const videoProgress = {};
  let videoCount = 0;
  for (const [key, value] of Object.entries(asObject(src.videoProgress))) {
    if (!ID_RE.test(key) || videoCount >= 5000) {
      continue;
    }
    const position = clampInt(value, 0, 24 * 3600 * 30, 0);
    if (position > 0) {
      videoProgress[key] = position;
      videoCount += 1;
    }
  }

  const favoriteVideos = {};
  let favoriteVideoCount = 0;
  for (const [key, value] of Object.entries(asObject(src.favoriteVideos))) {
    if (!ID_RE.test(key) || favoriteVideoCount >= 5000) {
      continue;
    }
    favoriteVideos[key] = asDateKey(value);
    favoriteVideoCount += 1;
  }

  return {
    currentBookId: asText(src.currentBookId, 64, 'cet4') || 'cet4',
    dailyTarget: clampInt(src.dailyTarget, 5, 50, 10),
    statusMap,
    masteredAt,
    learnedLog,
    favorites,
    swipeGuideShown: src.swipeGuideShown === true,
    todayLearned: clampInt(src.todayLearned, 0, 100000, 0),
    todayDate: asDateKey(src.todayDate),
    streak: clampInt(src.streak, 0, 100000, 0),
    totalLearned: clampInt(src.totalLearned, 0, 1000000, 0),
    learnedDays: clampInt(src.learnedDays, 0, MAX_DATES, 0),
    lastLearnDate: asDateKey(src.lastLearnDate),
    videoProgress,
    darkMode: src.darkMode === true,
    nickname: asText(src.nickname, 24),
    gender: asText(src.gender, 8),
    birthday: asDateKey(src.birthday),
    favoriteVideos,
    customWords: sanitizeCustomWords(src.customWords)
  };
}

export function hasMeaningfulData(snapshot) {
  return (
    Object.keys(snapshot.statusMap).length > 0 ||
    Object.keys(snapshot.favorites).length > 0 ||
    Object.keys(snapshot.favoriteVideos).length > 0 ||
    Object.keys(snapshot.learnedLog).length > 0 ||
    Object.keys(snapshot.masteredAt).length > 0 ||
    Object.keys(snapshot.videoProgress).length > 0 ||
    snapshot.customWords.length > 0 ||
    snapshot.totalLearned > 0
  );
}

function rankOf(dateKey) {
  const m = DATE_RE.exec(dateKey);
  if (!m) {
    return Number.NEGATIVE_INFINITY;
  }
  return Date.UTC(Number(m[1]), Number(m[2]) - 1, Number(m[3]));
}

function laterDate(a, b) {
  if (!a) {
    return b;
  }
  if (!b) {
    return a;
  }
  return rankOf(a) >= rankOf(b) ? a : b;
}

function ymdUtc(date) {
  return `${date.getUTCFullYear()}-${date.getUTCMonth() + 1}-${date.getUTCDate()}`;
}

/** 从学习日志计算当前连续天数：必须包含今天或昨天，否则视为中断 */
function computeStreak(learnedLog) {
  const days = new Set(Object.keys(learnedLog));
  if (days.size === 0) {
    return 0;
  }
  let latest = '';
  let latestRank = Number.NEGATIVE_INFINITY;
  for (const key of days) {
    const rank = rankOf(key);
    if (rank > latestRank) {
      latestRank = rank;
      latest = key;
    }
  }
  const todayRank = rankOf(ymdUtc(new Date()));
  // 今天还没学但昨天学了，连续天数仍然保留
  if (latestRank < todayRank - 86400000) {
    return 0;
  }
  let streak = 0;
  const cursor = new Date(latestRank);
  while (days.has(ymdUtc(cursor))) {
    streak += 1;
    cursor.setUTCDate(cursor.getUTCDate() - 1);
  }
  return streak;
}

function mergeStatusMaps(serverMap, clientMap) {
  const merged = { ...serverMap };
  for (const [key, value] of Object.entries(clientMap)) {
    const current = merged[key] ?? 0;
    merged[key] = Math.max(current, value);
  }
  return merged;
}

function mergeDateMaps(serverMap, clientMap, keep = 'client') {
  const merged = { ...serverMap };
  for (const [key, clientValue] of Object.entries(clientMap)) {
    const serverValue = merged[key] || '';
    if (!serverValue) {
      merged[key] = clientValue;
    } else if (keep === 'client' && clientValue) {
      merged[key] = laterDate(serverValue, clientValue);
    }
  }
  return merged;
}

function mergeLearnedLog(serverLog, clientLog) {
  const merged = {};
  for (const [date, ids] of Object.entries(serverLog)) {
    merged[date] = [...ids];
  }
  for (const [date, ids] of Object.entries(clientLog)) {
    if (!merged[date]) {
      merged[date] = [...ids];
      continue;
    }
    const set = new Set(merged[date]);
    for (const id of ids) {
      if (!set.has(id)) {
        merged[date].push(id);
        set.add(id);
      }
    }
  }
  return merged;
}

function mergeCounters(server, client) {
  const learnedDaysFromLog = Object.keys(client.learnedLog).length;
  return {
    learnedDays: Math.max(server.learnedDays, client.learnedDays, learnedDaysFromLog)
  };
}

export function mergeSnapshots(serverInput, clientInput) {
  const server = sanitizeSnapshot(serverInput);
  const client = sanitizeSnapshot(clientInput);
  const clientHasData = hasMeaningfulData(client);

  // 客户端刚登录 / 新设备还没有学习数据：直接沿用云端快照
  if (!clientHasData) {
    return withDerivedFields(server);
  }

  const statusMap = mergeStatusMaps(server.statusMap, client.statusMap);
  const learnedLog = mergeLearnedLog(server.learnedLog, client.learnedLog);
  const todayDate = laterDate(server.todayDate, client.todayDate);
  const todayLearned = server.todayDate === todayDate && client.todayDate === todayDate
    ? Math.max(server.todayLearned, client.todayLearned)
    : (todayDate === client.todayDate ? client.todayLearned : server.todayLearned);

  const merged = {
    currentBookId: client.currentBookId || server.currentBookId,
    dailyTarget: client.dailyTarget,
    statusMap,
    masteredAt: mergeDateMaps(server.masteredAt, client.masteredAt),
    learnedLog,
    favorites: mergeDateMaps(server.favorites, client.favorites, 'server'),
    swipeGuideShown: server.swipeGuideShown || client.swipeGuideShown,
    todayLearned,
    todayDate,
    streak: Math.max(server.streak, client.streak),
    totalLearned: Math.max(server.totalLearned, client.totalLearned),
    learnedDays: Math.max(server.learnedDays, client.learnedDays),
    lastLearnDate: laterDate(server.lastLearnDate, client.lastLearnDate),
    videoProgress: mergeVideoProgress(server.videoProgress, client.videoProgress),
    darkMode: client.darkMode,
    nickname: client.nickname || server.nickname,
    gender: client.gender || server.gender,
    birthday: client.birthday || server.birthday,
    favoriteVideos: mergeDateMaps(server.favoriteVideos, client.favoriteVideos, 'server'),
    customWords: mergeCustomWords(server.customWords, client.customWords)
  };

  return withDerivedFields({ ...merged, ...mergeCounters(server, merged) });
}

function mergeCustomWords(serverWords, clientWords) {
  const byId = new Map();
  for (const word of serverWords) {
    byId.set(word.id, word);
  }
  for (const word of clientWords) {
    byId.set(word.id, word);
  }
  return Array.from(byId.values());
}

function mergeVideoProgress(serverMap, clientMap) {
  const merged = { ...serverMap };
  for (const [key, value] of Object.entries(clientMap)) {
    merged[key] = Math.max(merged[key] ?? 0, value);
  }
  return merged;
}

/** 用学习日志修正派生的连续天数 / 学习天数，避免客户端旧版本计数不准 */
function withDerivedFields(snapshot) {
  const streak = computeStreak(snapshot.learnedLog);
  return {
    ...snapshot,
    streak: Math.max(streak, snapshot.streak),
    learnedDays: Math.max(snapshot.learnedDays, Object.keys(snapshot.learnedLog).length)
  };
}

export const progressInternals = { computeStreak, sanitizeSnapshot, mergeSnapshots };
