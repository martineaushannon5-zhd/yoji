import crypto from 'node:crypto';
import fs from 'node:fs';
import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import rateLimit from 'express-rate-limit';
import { config } from './config.js';
import { ErrorCode, fail } from './http.js';
import { authRouter } from './routes/auth.js';
import { adminPanelRouter } from './routes/adminPanel.js';
import { progressRouter } from './routes/progress.js';
import { videosRouter } from './routes/videos.js';
import { adminRouter } from './routes/admin.js';

export const app = express();

app.disable('x-powered-by');
// Nginx 反代时只信任一跳，限流 / 日志才能拿到真实 IP
app.set('trust proxy', config.trustProxy ? 1 : false);

app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }));
app.use(cors({ origin: config.corsOrigin === '*' ? true : config.corsOrigin.split(',') }));
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: false, limit: '16kb' }));

// 极简访问日志：记录请求 id、方法、路径、状态码、耗时
app.use((req, res, next) => {
  req.id = crypto.randomUUID().slice(0, 8);
  const start = process.hrtime.bigint();
  res.on('finish', () => {
    if (req.path === '/healthz') {
      return;
    }
    const ms = Number(process.hrtime.bigint() - start) / 1e6;
    console.log(
      `[${new Date().toISOString()}] ${req.id} ${req.method} ${req.originalUrl} ` +
      `${res.statusCode} ${ms.toFixed(1)}ms ${req.ip}`
    );
  });
  next();
});

const apiLimiter = rateLimit({
  windowMs: 60 * 1000,
  limit: 300,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { code: ErrorCode.RATE_LIMITED, message: '请求过于频繁，请稍后再试', data: null }
});

// 登录 / 注册单独限流，降低撞库与批量注册风险
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 100,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { code: ErrorCode.RATE_LIMITED, message: '尝试次数过多，请 15 分钟后再试', data: null }
});

const registerLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { code: ErrorCode.RATE_LIMITED, message: '注册过于频繁，请稍后再试', data: null }
});

// 管理后台登录单独限流，防止暴力猜 ADMIN_TOKEN
const adminLoginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { code: ErrorCode.RATE_LIMITED, message: '管理登录尝试过多，请 15 分钟后再试', data: null }
});

app.get('/healthz', (req, res) => {
  res.json({
    status: 'ok',
    uptime: Math.round(process.uptime()),
    time: new Date().toISOString()
  });
});

app.use('/api', apiLimiter);
app.use('/api/auth/register', registerLimiter);
app.use('/api/auth', authLimiter, authRouter);
app.use('/api/progress', progressRouter);
app.use('/api/videos', videosRouter);
app.use('/api/admin/login', adminLoginLimiter);
app.use('/api/admin', adminPanelRouter);
app.use('/api/admin', adminRouter);

// 媒体文件：开发 / 单机部署时由 Node 直接提供，生产建议交给 Nginx
fs.mkdirSync(config.mediaDir, { recursive: true });
app.use(
  config.publicMediaPrefix,
  express.static(config.mediaDir, {
    maxAge: '7d',
    fallthrough: true,
    setHeaders(res) {
      res.setHeader('Cross-Origin-Resource-Policy', 'cross-origin');
      res.setHeader('Accept-Ranges', 'bytes');
    }
  })
);

app.use((req, res) => {
  fail(res, 404, ErrorCode.NOT_FOUND, '接口不存在');
});

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  if (err?.type === 'entity.parse.failed') {
    return fail(res, 400, ErrorCode.BAD_REQUEST, '请求体不是合法的 JSON');
  }
  if (err?.type === 'entity.too.large') {
    return fail(res, 413, ErrorCode.BAD_REQUEST, '请求体过大');
  }
  console.error(`[${new Date().toISOString()}] ${req.id || '-'} unhandled error:`, err);
  return fail(res, 500, ErrorCode.SERVER_ERROR, '服务器内部错误');
});
