import crypto from 'node:crypto';
import path from 'node:path';
import { Router } from 'express';
import multer from 'multer';

import { requireAdminJwt } from '../auth.js';
import { config } from '../config.js';
import {
  deleteWordBook,
  getWordBook,
  listWordBooks,
  recordAuditLog,
  saveWordBook
} from '../db.js';
import { asyncRoute, ErrorCode, fail, ok } from '../http.js';
import { parseWordList } from '../wordlist-parse.js';

export const adminWordbooksRouter = Router();
adminWordbooksRouter.use(requireAdminJwt);

const ID_RE = /^[a-z0-9][a-z0-9_-]{1,63}$/;

function text(value, max = 200) {
  return typeof value === 'string' ? value.trim().slice(0, max) : '';
}

function slug(value) {
  const result = String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48);
  return result.length >= 2 ? result : `book-${crypto.randomBytes(3).toString('hex')}`;
}

const receiveFile = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 8 * 1024 * 1024, files: 1 },
  fileFilter(req, file, cb) {
    const ext = path.extname(file.originalname || '').toLowerCase();
    if (ext !== '.txt' && ext !== '.json') {
      cb(new Error('只支持 .txt 或 .json 词表'));
      return;
    }
    cb(null, true);
  }
}).single('file');

function uploadOne(req, res, next) {
  receiveFile(req, res, (err) => {
    if (err) {
      return fail(res, 400, ErrorCode.BAD_REQUEST, err.message || '词表上传失败');
    }
    return next();
  });
}

adminWordbooksRouter.get(
  '/',
  asyncRoute(async (req, res) => {
    return ok(res, { books: listWordBooks({ includeHidden: true }) });
  })
);

adminWordbooksRouter.get(
  '/:id',
  asyncRoute(async (req, res) => {
    const book = getWordBook(req.params.id, { includeHidden: true, includeWords: true });
    if (!book) {
      return fail(res, 404, ErrorCode.NOT_FOUND, '词表不存在');
    }
    return ok(res, book);
  })
);

// 从官方节点（或指定地址）拉取全部词库，导入本地数据库。
// 自部署实例初始化后，管理员点一次即可拿到线上 8 套词库，App 不再只有内置两本。
function isPrivateHostname(hostname) {
  const host = String(hostname || '').toLowerCase().replace(/^\[|\]$/g, '');
  if (!host) {
    return true;
  }
  if (host === 'localhost' || host.endsWith('.localhost') || host === '::1') {
    return true;
  }
  if (/^(127|10|192\.168|169\.254)\./.test(host)) {
    return true;
  }
  const m = host.match(/^172\.(\d+)\./);
  if (m && Number(m[1]) >= 16 && Number(m[1]) <= 31) {
    return true;
  }
  return host.endsWith('.internal') || host.endsWith('.local');
}

function normalizeRemoteWord(raw, bookId, index) {
  if (!raw || typeof raw !== 'object') {
    return null;
  }
  const word = typeof raw.word === 'string' ? raw.word.trim().slice(0, 80) : '';
  const meaning = typeof raw.meaning === 'string' ? raw.meaning.trim().slice(0, 2000) : '';
  if (!word || !meaning) {
    return null;
  }
  const id = typeof raw.id === 'string' && raw.id.trim()
    ? raw.id.trim().slice(0, 80)
    : `${bookId}-w${String(index + 1).padStart(4, '0')}`;
  return {
    id,
    word,
    phonetic: typeof raw.phonetic === 'string' ? raw.phonetic.trim().slice(0, 120) : '',
    meaning,
    example: typeof raw.example === 'string' ? raw.example.trim().slice(0, 500) : '',
    exampleCn: typeof raw.exampleCn === 'string' ? raw.exampleCn.trim().slice(0, 500) : ''
  };
}

adminWordbooksRouter.post(
  '/sync',
  asyncRoute(async (req, res) => {
    const rawUrl = text(req.body?.url, 400) || config.officialWordbooksUrl;
    let target;
    try {
      target = new URL(rawUrl);
    } catch {
      return fail(res, 400, ErrorCode.BAD_REQUEST, '同步地址不是合法 URL');
    }
    if (target.protocol !== 'http:' && target.protocol !== 'https:') {
      return fail(res, 400, ErrorCode.BAD_REQUEST, '同步地址只支持 http/https');
    }
    if (isPrivateHostname(target.hostname)) {
      return fail(res, 400, ErrorCode.BAD_REQUEST, '同步地址不能指向内网或本机');
    }

    const startedAt = Date.now();
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), config.wordbookSyncTimeoutMs);
    let payload;
    try {
      const response = await fetch(target, {
        signal: controller.signal,
        headers: { accept: 'application/json', 'user-agent': 'yoji-admin-sync/1.0' }
      });
      if (!response.ok) {
        return fail(res, 502, ErrorCode.BAD_GATEWAY, `拉取词库失败：HTTP ${response.status}`);
      }
      const declared = Number(response.headers.get('content-length') || 0);
      if (declared > config.wordbookSyncMaxBytes) {
        return fail(res, 413, ErrorCode.BAD_REQUEST, '词库数据超过大小上限');
      }
      const body = await response.text();
      if (Buffer.byteLength(body) > config.wordbookSyncMaxBytes) {
        return fail(res, 413, ErrorCode.BAD_REQUEST, '词库数据超过大小上限');
      }
      payload = JSON.parse(body);
    } catch (error) {
      const reason = error?.name === 'AbortError' ? '请求超时' : error?.message || '网络错误';
      return fail(res, 502, ErrorCode.BAD_GATEWAY, `拉取词库失败：${reason}`);
    } finally {
      clearTimeout(timer);
    }

    const list = payload?.data?.books ?? payload?.books ?? payload?.data;
    if (!Array.isArray(list)) {
      return fail(res, 502, ErrorCode.BAD_GATEWAY, '词库返回格式不正确（缺少 books 数组）');
    }

    const imported = [];
    const skipped = [];
    let totalWords = 0;
    let skippedWords = 0;
    list.forEach((item, index) => {
      const id = typeof item?.id === 'string' ? item.id.trim().toLowerCase() : '';
      if (!ID_RE.test(id)) {
        skipped.push({ id: id || '(空)', reason: 'id 不合法' });
        return;
      }
      const sourceWords = Array.isArray(item?.words) ? item.words : [];
      const words = sourceWords
        .map((w, i) => normalizeRemoteWord(w, id, i))
        .filter(Boolean);
      skippedWords += sourceWords.length - words.length;
      if (words.length === 0) {
        skipped.push({ id, reason: '没有有效单词' });
        return;
      }
      const existing = getWordBook(id, { includeHidden: true, includeWords: false });
      const sortOrder = Number.isFinite(Number(item?.sortOrder))
        ? Math.trunc(Number(item.sortOrder))
        : existing?.sortOrder ?? 100 + index;
      const book = saveWordBook({
        id,
        name: text(item?.name, 80) || id,
        subtitle: text(item?.subtitle, 120),
        description: text(item?.description, 500),
        source: text(item?.source, 160) || new URL(target).host,
        words,
        visible: existing ? existing.visible : item?.visible !== false,
        sortOrder
      });
      totalWords += words.length;
      imported.push({ id: book.id, name: book.name, words: words.length });
    });

    recordAuditLog({
      account: req.admin?.account || 'admin',
      action: 'wordbook.sync',
      target: target.host,
      detail: `${imported.length} 本 / ${totalWords} 词`,
      ip: req.ip
    });

    return ok(
      res,
      {
        source: target.toString(),
        imported,
        skipped,
        totalBooks: imported.length,
        totalWords,
        skippedWords,
        elapsedMs: Date.now() - startedAt
      },
      '词库同步完成'
    );
  })
);

adminWordbooksRouter.post(
  '/upload',
  uploadOne,
  asyncRoute(async (req, res) => {
    if (!req.file) {
      return fail(res, 400, ErrorCode.BAD_REQUEST, '请选择词表文件');
    }
    const fallbackName = path.basename(req.file.originalname, path.extname(req.file.originalname));
    const name = text(req.body?.name, 80) || fallbackName || '未命名词表';
    let id = text(req.body?.id, 64).toLowerCase() || slug(name);
    if (!ID_RE.test(id)) {
      return fail(res, 400, ErrorCode.BAD_REQUEST, '词表 id 需为 2-64 位小写字母、数字、_ 或 -');
    }

    const parsed = parseWordList(req.file.buffer.toString('utf8'), id);
    if (parsed.length === 0) {
      return fail(res, 400, ErrorCode.BAD_REQUEST, '没有解析到单词，请检查文件格式');
    }

    const sortRaw = Number(req.body?.sortOrder);
    const existing = getWordBook(id, { includeHidden: true, includeWords: false });
    const sortOrder = Number.isFinite(sortRaw)
      ? Math.trunc(sortRaw)
      : existing?.sortOrder ?? Math.max(0, ...listWordBooks({ includeHidden: true }).map((b) => b.sortOrder)) + 1;

    const book = saveWordBook({
      id,
      name,
      subtitle: text(req.body?.subtitle, 120),
      description: text(req.body?.description, 500),
      source: path.basename(req.file.originalname),
      words: parsed,
      visible: String(req.body?.visible ?? 'true') !== 'false',
      sortOrder
    });
    recordAuditLog({
      account: req.admin?.account || 'admin',
      action: 'wordbook.upload',
      target: book.id,
      detail: `${book.name}（${parsed.length} 词）`,
      ip: req.ip
    });
    return ok(res, { ...book, words: undefined }, '词表已上传');
  })
);

adminWordbooksRouter.patch(
  '/:id',
  asyncRoute(async (req, res) => {
    const existing = getWordBook(req.params.id, { includeHidden: true, includeWords: true });
    if (!existing) {
      return fail(res, 404, ErrorCode.NOT_FOUND, '词表不存在');
    }
    const book = saveWordBook({
      ...existing,
      name: req.body?.name !== undefined ? text(req.body.name, 80) || existing.name : existing.name,
      subtitle: req.body?.subtitle !== undefined ? text(req.body.subtitle, 120) : existing.subtitle,
      description: req.body?.description !== undefined ? text(req.body.description, 500) : existing.description,
      visible: req.body?.visible !== undefined ? req.body.visible !== false : existing.visible,
      sortOrder: Number.isFinite(Number(req.body?.sortOrder))
        ? Math.trunc(Number(req.body.sortOrder))
        : existing.sortOrder
    });
    recordAuditLog({
      account: req.admin?.account || 'admin',
      action: 'wordbook.update',
      target: book.id,
      detail: book.name,
      ip: req.ip
    });
    return ok(res, { ...book, words: undefined }, '词表已更新');
  })
);

adminWordbooksRouter.delete(
  '/:id',
  asyncRoute(async (req, res) => {
    if (!deleteWordBook(req.params.id)) {
      return fail(res, 404, ErrorCode.NOT_FOUND, '词表不存在');
    }
    recordAuditLog({
      account: req.admin?.account || 'admin',
      action: 'wordbook.delete',
      target: req.params.id,
      ip: req.ip
    });
    return ok(res, null, '词表已删除');
  })
);
