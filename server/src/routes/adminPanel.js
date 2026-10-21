import { Router } from 'express';
import { signAdminToken, requireAdminJwt, verifyAdminCredentials } from '../auth.js';
import { deleteUserById, getProgress, listUsers, stats } from '../db.js';
import { config } from '../config.js';
import { asyncRoute, ErrorCode, fail, ok } from '../http.js';

export const adminPanelRouter = Router();

const TZ_OFFSET_MINUTES = 8 * 60; // 后台按中国时间统计“今天”

function pad2(n) {
  return n < 10 ? `0${n}` : `${n}`;
}

function chinaDateKey(input = new Date()) {
  const t = new Date(input.getTime() + TZ_OFFSET_MINUTES * 60 * 1000);
  return `${t.getUTCFullYear()}-${pad2(t.getUTCMonth() + 1)}-${pad2(t.getUTCDate())}`;
}

function normalizeDateKey(raw) {
  const m = /^(\d{4})-(\d{1,2})-(\d{1,2})$/.exec(String(raw || ''));
  if (!m) {
    return '';
  }
  return `${m[1]}-${pad2(Number(m[2]))}-${pad2(Number(m[3]))}`;
}

function lastNDates(n) {
  const result = [];
  const now = Date.now() + TZ_OFFSET_MINUTES * 60 * 1000;
  for (let i = n - 1; i >= 0; i--) {
    result.push(chinaDateKey(new Date(now - i * 24 * 60 * 60 * 1000)));
  }
  return result;
}

function buildUserRow(user) {
  const stored = getProgress(user.id);
  const data = stored.data || {};
  const statusMap = data.statusMap && typeof data.statusMap === 'object' ? data.statusMap : {};
  let mastered = 0;
  let learning = 0;
  for (const value of Object.values(statusMap)) {
    if (Number(value) === 2) {
      mastered += 1;
    } else if (Number(value) === 1) {
      learning += 1;
    }
  }

  const learnedLog = data.learnedLog && typeof data.learnedLog === 'object' ? data.learnedLog : {};
  const activeDates = new Set();
  for (const [date, ids] of Object.entries(learnedLog)) {
    const key = normalizeDateKey(date);
    if (key && Array.isArray(ids) && ids.length > 0) {
      activeDates.add(key);
    }
  }
  const lastLearnDate = normalizeDateKey(data.lastLearnDate);
  if (lastLearnDate) {
    activeDates.add(lastLearnDate);
  }

  const today = chinaDateKey();
  const favorites = data.favorites && typeof data.favorites === 'object' ? data.favorites : {};
  const favoriteVideos = data.favoriteVideos && typeof data.favoriteVideos === 'object' ? data.favoriteVideos : {};
  const customWords = Array.isArray(data.customWords) ? data.customWords : [];

  return {
    id: user.id,
    account: user.account,
    nickname: user.nickname,
    avatar: user.avatar,
    createdAt: user.createdAt,
    mastered,
    learning,
    learnedDays: activeDates.size,
    lastLearnDate: lastLearnDate || '',
    todayLearned: normalizeDateKey(data.todayDate) === today ? Number(data.todayLearned) || 0 : 0,
    streak: Number(data.streak) || 0,
    favoriteCount: Object.keys(favorites).length,
    favoriteVideoCount: Object.keys(favoriteVideos).length,
    customWordCount: customWords.length,
    activeDates
  };
}

// POST /api/admin/login
adminPanelRouter.post(
  '/login',
  asyncRoute(async (req, res) => {
    const account = typeof req.body?.account === 'string' ? req.body.account.trim() : '';
    const password = typeof req.body?.password === 'string' ? req.body.password : '';
    if (!account || !password) {
      return fail(res, 400, ErrorCode.BAD_REQUEST, '请输入管理员账号和密码');
    }
    if (!config.adminToken) {
      return fail(res, 503, ErrorCode.FORBIDDEN, '服务器未配置 ADMIN_TOKEN，后台登录不可用');
    }
    if (!verifyAdminCredentials(account, password)) {
      return fail(res, 401, ErrorCode.INVALID_CREDENTIALS, '管理员账号或密码错误');
    }
    return ok(res, {
      token: signAdminToken(),
      account: config.adminAccount,
      expiresIn: config.adminJwtTtl
    }, '登录成功');
  })
);

// GET /api/admin/stats
adminPanelRouter.get(
  '/stats',
  requireAdminJwt,
  asyncRoute(async (req, res) => {
    const rows = listUsers().map(buildUserRow);
    const dates = lastNDates(14);
    const trend = dates.map((date) => ({
      date,
      label: date.slice(5),
      newUsers: 0,
      activeUsers: 0
    }));
    const trendMap = new Map(trend.map((item) => [item.date, item]));
    const today = chinaDateKey();

    let todayActive = 0;
    let totalWords = 0;
    let masteredWords = 0;
    let newUsers7d = 0;
    const sevenDaysAgo = chinaDateKey(new Date(Date.now() - 6 * 24 * 60 * 60 * 1000));

    for (const user of rows) {
      const createdDate = new Date(user.createdAt || 0);
      const created = Number.isNaN(createdDate.getTime()) ? '' : chinaDateKey(createdDate);
      const item = trendMap.get(created);
      if (item) {
        item.newUsers += 1;
      }
      if (created && created >= sevenDaysAgo) {
        newUsers7d += 1;
      }
      if (user.activeDates.has(today)) {
        todayActive += 1;
      }
      for (const date of user.activeDates) {
        const t = trendMap.get(date);
        if (t) {
          t.activeUsers += 1;
        }
      }
      totalWords += user.mastered + user.learning;
      masteredWords += user.mastered;
    }

    return ok(res, {
      totalUsers: rows.length,
      todayActive,
      totalWords,
      masteredWords,
      totalVideos: stats().videos,
      newUsers7d,
      trend
    });
  })
);

// GET /api/admin/users?search=&page=1&pageSize=10
adminPanelRouter.get(
  '/users',
  requireAdminJwt,
  asyncRoute(async (req, res) => {
    const search = typeof req.query.search === 'string' ? req.query.search.trim().toLowerCase() : '';
    const page = Math.max(1, Number.parseInt(String(req.query.page || '1'), 10) || 1);
    const pageSize = Math.min(50, Math.max(1, Number.parseInt(String(req.query.pageSize || '10'), 10) || 10));

    let rows = listUsers().map(buildUserRow);
    if (search) {
      rows = rows.filter((user) =>
        user.account.toLowerCase().includes(search) ||
        user.nickname.toLowerCase().includes(search)
      );
    }
    const total = rows.length;
    const start = (page - 1) * pageSize;
    const users = rows.slice(start, start + pageSize).map(({ activeDates, ...rest }) => rest);
    return ok(res, { users, total, page, pageSize });
  })
);

// DELETE /api/admin/users/:id
adminPanelRouter.delete(
  '/users/:id',
  requireAdminJwt,
  asyncRoute(async (req, res) => {
    const removed = deleteUserById(req.params.id);
    if (!removed) {
      return fail(res, 404, ErrorCode.NOT_FOUND, '用户不存在');
    }
    return ok(res, null, '已删除用户');
  })
);
