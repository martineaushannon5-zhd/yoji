import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';
import bcrypt from 'bcryptjs';
import { DatabaseSync } from 'node:sqlite';
import { config, paths } from './config.js';

fs.mkdirSync(config.dataDir, { recursive: true });

export const db = new DatabaseSync(paths.dbFile);

// WAL 适合“读多写少 + 单机”的场景，2 核 2G 的小机器完全够用
db.exec('PRAGMA journal_mode = WAL;');
db.exec('PRAGMA synchronous = NORMAL;');
db.exec('PRAGMA foreign_keys = ON;');
db.exec('PRAGMA busy_timeout = 5000;');

db.exec(`
CREATE TABLE IF NOT EXISTS users (
  id            TEXT PRIMARY KEY,
  account       TEXT NOT NULL,
  account_lower TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  nickname      TEXT NOT NULL DEFAULT '',
  avatar        TEXT NOT NULL DEFAULT '',
  token_version INTEGER NOT NULL DEFAULT 1,
  created_at    TEXT NOT NULL,
  updated_at    TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS progress (
  user_id    TEXT PRIMARY KEY,
  version    INTEGER NOT NULL DEFAULT 0,
  data       TEXT NOT NULL DEFAULT '{}',
  updated_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS videos (
  id          TEXT PRIMARY KEY,
  title       TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  date        TEXT NOT NULL,
  thumb_url   TEXT NOT NULL DEFAULT '',
  video_url   TEXT NOT NULL,
  duration    INTEGER NOT NULL DEFAULT 0,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  visible     INTEGER NOT NULL DEFAULT 1,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_videos_visible ON videos(visible, sort_order, created_at);

CREATE TABLE IF NOT EXISTS admins (
  id            TEXT PRIMARY KEY,
  account       TEXT NOT NULL,
  account_lower TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at    TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS word_books (
  id          TEXT PRIMARY KEY,
  name        TEXT NOT NULL,
  subtitle    TEXT NOT NULL DEFAULT '',
  description TEXT NOT NULL DEFAULT '',
  source      TEXT NOT NULL DEFAULT '',
  words_json  TEXT NOT NULL DEFAULT '[]',
  word_count  INTEGER NOT NULL DEFAULT 0,
  visible     INTEGER NOT NULL DEFAULT 1,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL
);
`);

const now = () => new Date().toISOString();
const today = () => new Date().toISOString().slice(0, 10);

function one(sql, ...params) {
  const row = db.prepare(sql).get(...params);
  return row ? { ...row } : undefined;
}

function all(sql, ...params) {
  return db.prepare(sql).all(...params).map((row) => ({ ...row }));
}

function run(sql, ...params) {
  return db.prepare(sql).run(...params);
}

function mapUser(row) {
  if (!row) {
    return undefined;
  }
  return {
    id: row.id,
    account: row.account,
    passwordHash: row.password_hash,
    nickname: row.nickname,
    avatar: row.avatar,
    tokenVersion: Number(row.token_version),
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

function mapAdmin(row) {
  if (!row) {
    return undefined;
  }
  return {
    id: row.id,
    account: row.account,
    passwordHash: row.password_hash,
    createdAt: row.created_at
  };
}

function mapVideo(row) {
  if (!row) {
    return undefined;
  }
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    date: row.date,
    thumbUrl: row.thumb_url,
    videoUrl: row.video_url,
    duration: Number(row.duration),
    sortOrder: Number(row.sort_order),
    visible: Number(row.visible) === 1,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  };
}

/* ------------------------------- users ------------------------------- */

export function findUserByAccount(accountLower) {
  return mapUser(one('SELECT * FROM users WHERE account_lower = ?', accountLower));
}

export function findUserById(id) {
  return mapUser(one('SELECT * FROM users WHERE id = ?', id));
}

export function createUser({ id, account, passwordHash, nickname, avatar }) {
  const ts = now();
  run(
    `INSERT INTO users (id, account, account_lower, password_hash, nickname, avatar, token_version, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, 1, ?, ?)`,
    id,
    account,
    account.toLowerCase(),
    passwordHash,
    nickname,
    avatar,
    ts,
    ts
  );
  run(
    `INSERT INTO progress (user_id, version, data, updated_at) VALUES (?, 0, '{}', ?)`,
    id,
    ts
  );
  return findUserById(id);
}

export function updateUserProfile(userId, { nickname, avatar }) {
  run(
    'UPDATE users SET nickname = ?, avatar = ?, updated_at = ? WHERE id = ?',
    nickname,
    avatar,
    now(),
    userId
  );
  return findUserById(userId);
}

// 资料昵称也会随进度快照同步；这里顺手更新 users 表，后台用户列表才能看到最新昵称
export function updateUserNickname(userId, nickname) {
  run('UPDATE users SET nickname = ?, updated_at = ? WHERE id = ?', nickname, now(), userId);
}

export function updateUserAvatar(userId, avatar) {
  run('UPDATE users SET avatar = ?, updated_at = ? WHERE id = ?', avatar, now(), userId);
}

export function bumpTokenVersion(userId) {
  run(
    'UPDATE users SET token_version = token_version + 1, updated_at = ? WHERE id = ?',
    now(),
    userId
  );
}

/* ------------------------------ progress ----------------------------- */

export function getProgress(userId) {
  const row = one('SELECT * FROM progress WHERE user_id = ?', userId);
  if (!row) {
    return { version: 0, data: {}, updatedAt: '' };
  }
  let data = {};
  try {
    data = JSON.parse(row.data);
  } catch {
    data = {};
  }
  return { version: Number(row.version), data, updatedAt: row.updated_at };
}

export function saveProgress(userId, data, expectedVersion = null) {
  return withTransaction(() => {
    const current = one('SELECT version FROM progress WHERE user_id = ?', userId);
    const currentVersion = current ? Number(current.version) : 0;
    if (expectedVersion !== null && expectedVersion !== currentVersion) {
      return { conflict: true, version: currentVersion };
    }
    const nextVersion = currentVersion + 1;
    const ts = now();
    if (current) {
      run(
        'UPDATE progress SET version = ?, data = ?, updated_at = ? WHERE user_id = ?',
        nextVersion,
        JSON.stringify(data),
        ts,
        userId
      );
    } else {
      run(
        'INSERT INTO progress (user_id, version, data, updated_at) VALUES (?, ?, ?, ?)',
        userId,
        nextVersion,
        JSON.stringify(data),
        ts
      );
    }
    return { conflict: false, version: nextVersion, updatedAt: ts };
  });
}

/* ------------------------------- videos ------------------------------ */

export function listVideos({ includeHidden = false } = {}) {
  const rows = includeHidden
    ? all('SELECT * FROM videos ORDER BY sort_order ASC, created_at ASC')
    : all('SELECT * FROM videos WHERE visible = 1 ORDER BY sort_order ASC, created_at ASC');
  return rows.map(mapVideo);
}

export function getVideo(id) {
  return mapVideo(one('SELECT * FROM videos WHERE id = ?', id));
}

export function createVideo(video) {
  const ts = now();
  run(
    `INSERT INTO videos (id, title, description, date, thumb_url, video_url, duration, sort_order, visible, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    video.id,
    video.title,
    video.description,
    video.date,
    video.thumbUrl,
    video.videoUrl,
    video.duration,
    video.sortOrder,
    video.visible ? 1 : 0,
    ts,
    ts
  );
  return getVideo(video.id);
}

export function updateVideo(id, patch) {
  const existing = getVideo(id);
  if (!existing) {
    return undefined;
  }
  const next = { ...existing, ...patch };
  run(
    `UPDATE videos SET title = ?, description = ?, date = ?, thumb_url = ?, video_url = ?,
       duration = ?, sort_order = ?, visible = ?, updated_at = ? WHERE id = ?`,
    next.title,
    next.description,
    next.date,
    next.thumbUrl,
    next.videoUrl,
    next.duration,
    next.sortOrder,
    next.visible ? 1 : 0,
    now(),
    id
  );
  return getVideo(id);
}

export function deleteVideo(id) {
  return run('DELETE FROM videos WHERE id = ?', id).changes > 0;
}

/* ---------------------------- admin panel ---------------------------- */

export function findAdminByAccount(accountLower) {
  return mapAdmin(one('SELECT * FROM admins WHERE account_lower = ?', accountLower));
}

export function createAdmin(account, passwordHash) {
  const id = crypto.randomUUID();
  run(
    'INSERT INTO admins (id, account, account_lower, password_hash, created_at) VALUES (?, ?, ?, ?, ?)',
    id,
    account,
    account.toLowerCase(),
    passwordHash,
    now()
  );
  return findAdminByAccount(account.toLowerCase());
}

/**
 * 内置测试管理员（需求指定）：
 *   hans / 123456
 *   zhd  / 123456
 * 已有同名账号时不覆盖密码，避免每次重启重置。
 */
export function ensureAdminUsers() {
  const seeds = [
    { account: 'hans', password: '123456' },
    { account: 'zhd', password: '123456' }
  ];
  for (const item of seeds) {
    if (!findAdminByAccount(item.account)) {
      createAdmin(item.account, bcrypt.hashSync(item.password, config.bcryptRounds));
    }
  }
}

/* ----------------------------- word books ---------------------------- */

function mapWordBook(row, includeWords = false) {
  if (!row) {
    return undefined;
  }
  let words = [];
  if (includeWords) {
    try {
      words = JSON.parse(row.words_json);
    } catch {
      words = [];
    }
  }
  return {
    id: row.id,
    name: row.name,
    subtitle: row.subtitle,
    description: row.description,
    source: row.source,
    wordCount: Number(row.word_count),
    visible: Number(row.visible) === 1,
    sortOrder: Number(row.sort_order),
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    ...(includeWords ? { words } : {})
  };
}

export function listWordBooks({ includeHidden = false } = {}) {
  const rows = includeHidden
    ? all('SELECT * FROM word_books ORDER BY sort_order ASC, created_at ASC')
    : all('SELECT * FROM word_books WHERE visible = 1 ORDER BY sort_order ASC, created_at ASC');
  return rows.map((row) => mapWordBook(row));
}

export function getWordBook(id, { includeHidden = false, includeWords = false } = {}) {
  const row = includeHidden
    ? one('SELECT * FROM word_books WHERE id = ?', id)
    : one('SELECT * FROM word_books WHERE id = ? AND visible = 1', id);
  return mapWordBook(row, includeWords);
}

export function saveWordBook(book) {
  const id = String(book.id || '').trim();
  const name = String(book.name || '').trim();
  if (!id || !name) {
    throw new Error('word book id/name required');
  }
  const words = Array.isArray(book.words) ? book.words : [];
  const wordsJson = JSON.stringify(words);
  const existing = one('SELECT created_at FROM word_books WHERE id = ?', id);
  const createdAt = existing?.created_at || now();
  run(
    `INSERT INTO word_books
      (id, name, subtitle, description, source, words_json, word_count, visible, sort_order, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(id) DO UPDATE SET
       name = excluded.name,
       subtitle = excluded.subtitle,
       description = excluded.description,
       source = excluded.source,
       words_json = excluded.words_json,
       word_count = excluded.word_count,
       visible = excluded.visible,
       sort_order = excluded.sort_order,
       updated_at = excluded.updated_at`,
    id,
    name,
    String(book.subtitle || ''),
    String(book.description || ''),
    String(book.source || ''),
    wordsJson,
    words.length,
    book.visible === false ? 0 : 1,
    Number.isFinite(Number(book.sortOrder)) ? Math.trunc(Number(book.sortOrder)) : 0,
    createdAt,
    now()
  );
  return getWordBook(id, { includeHidden: true, includeWords: true });
}

export function deleteWordBook(id) {
  return run('DELETE FROM word_books WHERE id = ?', id).changes > 0;
}

export function listUsers() {
  return all(
    'SELECT id, account, nickname, avatar, created_at, updated_at FROM users ORDER BY created_at DESC'
  ).map((row) => ({
    id: row.id,
    account: row.account,
    nickname: row.nickname,
    avatar: row.avatar,
    createdAt: row.created_at,
    updatedAt: row.updated_at
  }));
}

export function deleteUserById(id) {
  return run('DELETE FROM users WHERE id = ?', id).changes > 0;
}

/* ------------------------------- misc -------------------------------- */

export function stats() {
  const users = one('SELECT COUNT(*) AS n FROM users');
  const videos = one('SELECT COUNT(*) AS n FROM videos');
  return {
    users: Number(users?.n || 0),
    videos: Number(videos?.n || 0)
  };
}

function withTransaction(fn) {
  db.exec('BEGIN IMMEDIATE');
  try {
    const result = fn();
    db.exec('COMMIT');
    return result;
  } catch (err) {
    db.exec('ROLLBACK');
    throw err;
  }
}

/** 首次启动时写入演示视频；表里已有数据则不动，避免覆盖后台配置 */
export function seedVideosIfEmpty() {
  const row = one('SELECT COUNT(*) AS n FROM videos');
  if (Number(row?.n || 0) > 0) {
    return 0;
  }
  const date = today();
  const prefix = config.publicMediaPrefix;
  const seeds = [
    {
      id: 'ted-anxiety',
      title: '【TED演讲】如何解决焦虑',
      description: 'TED 演讲：如何解决焦虑。',
      thumbUrl: `${prefix}/thumbs/video_thumb_anxiety.png`,
      videoUrl: `${prefix}/videos/anxiety.mp4`,
      sortOrder: 1
    },
    {
      id: 'casey-sloppy',
      title: '【Casey Neistat】拖延是创造力的毒药',
      description: 'Casey Neistat：拖延是创造力的毒药。',
      thumbUrl: `${prefix}/thumbs/video_thumb_sloppy.jpg`,
      videoUrl: `${prefix}/videos/sloppy.mp4`,
      sortOrder: 2
    }
  ];
  for (const item of seeds) {
    createVideo({
      ...item,
      description: item.description,
      date,
      duration: 0,
      visible: true
    });
  }
  return seeds.length;
}

// 首次启动或升级后补齐后台测试管理员
ensureAdminUsers();
