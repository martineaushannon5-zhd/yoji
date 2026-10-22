import { Router } from 'express';

import { getWordBook, listWordBooks } from '../db.js';
import { asyncRoute, ErrorCode, fail, ok } from '../http.js';

export const wordbooksRouter = Router();

function publicBook(book, includeWords) {
  return {
    id: book.id,
    name: book.name,
    subtitle: book.subtitle,
    description: book.description,
    source: book.source,
    wordCount: book.wordCount,
    ...(includeWords ? { words: book.words || [] } : {})
  };
}

// GET /api/wordbooks —— 公开词表摘要（App 词库选择页）
wordbooksRouter.get(
  '/',
  asyncRoute(async (req, res) => {
    return ok(res, { books: listWordBooks().map((book) => publicBook(book, false)) });
  })
);

// GET /api/wordbooks/full —— 一次返回所有启用的词表，App 启动时下载
wordbooksRouter.get(
  '/full',
  asyncRoute(async (req, res) => {
    const books = listWordBooks().map((book) => publicBook(
      getWordBook(book.id, { includeWords: true }),
      true
    ));
    return ok(res, { books });
  })
);

// GET /api/wordbooks/:id —— 单个词表完整内容
wordbooksRouter.get(
  '/:id',
  asyncRoute(async (req, res) => {
    const book = getWordBook(req.params.id, { includeWords: true });
    if (!book) {
      return fail(res, 404, ErrorCode.NOT_FOUND, '词表不存在');
    }
    return ok(res, publicBook(book, true));
  })
);
