import crypto from 'node:crypto';
import path from 'node:path';
import { Router } from 'express';
import multer from 'multer';

import { requireAdminJwt } from '../auth.js';
import {
  deleteWordBook,
  getWordBook,
  listWordBooks,
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
    return ok(res, { ...book, words: undefined }, '词表已更新');
  })
);

adminWordbooksRouter.delete(
  '/:id',
  asyncRoute(async (req, res) => {
    if (!deleteWordBook(req.params.id)) {
      return fail(res, 404, ErrorCode.NOT_FOUND, '词表不存在');
    }
    return ok(res, null, '词表已删除');
  })
);
