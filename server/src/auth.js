import crypto from 'node:crypto';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { config } from './config.js';
import { findUserById } from './db.js';
import { ErrorCode, fail } from './http.js';

export function hashPassword(password) {
  return bcrypt.hash(password, config.bcryptRounds);
}

/** 账号不存在时也做一次同成本的比对，避免通过响应时间推断账号是否注册 */
export const dummyPasswordHash = bcrypt.hashSync('dummy-password-for-timing', config.bcryptRounds);

export function verifyPassword(password, hash) {
  return bcrypt.compare(password, hash);
}

export function signToken(user) {
  return jwt.sign(
    { sub: user.id, ver: user.tokenVersion },
    config.jwtSecret,
    { expiresIn: `${config.jwtTtlDays}d`, algorithm: 'HS256' }
  );
}

function readBearer(req) {
  const header = req.get('authorization') || '';
  const match = /^Bearer\s+(.+)$/i.exec(header.trim());
  return match ? match[1] : '';
}

/**
 * 校验 JWT，并从数据库读取用户。
 * 同时校验 token_version：退出登录 / 改密码后，旧 token 立即失效。
 */
export function requireAuth(req, res, next) {
  const token = readBearer(req);
  if (!token) {
    return fail(res, 401, ErrorCode.UNAUTHORIZED, '请先登录');
  }
  let payload;
  try {
    payload = jwt.verify(token, config.jwtSecret, { algorithms: ['HS256'] });
  } catch (err) {
    const expired = err?.name === 'TokenExpiredError';
    return fail(
      res,
      401,
      expired ? ErrorCode.TOKEN_EXPIRED : ErrorCode.UNAUTHORIZED,
      expired ? '登录已过期，请重新登录' : '登录状态无效，请重新登录'
    );
  }
  const user = findUserById(String(payload.sub || ''));
  if (!user) {
    return fail(res, 401, ErrorCode.UNAUTHORIZED, '账号不存在或已注销');
  }
  if (user.tokenVersion !== Number(payload.ver)) {
    return fail(res, 401, ErrorCode.UNAUTHORIZED, '登录已失效，请重新登录');
  }
  req.user = user;
  next();
}

function safeEqual(a, b) {
  const left = crypto.createHash('sha256').update(String(a)).digest();
  const right = crypto.createHash('sha256').update(String(b)).digest();
  return crypto.timingSafeEqual(left, right);
}

/** 后台管理接口：使用独立的 ADMIN_TOKEN，和普通用户 token 完全隔离 */
export function requireAdmin(req, res, next) {
  if (!config.adminToken) {
    return fail(res, 503, ErrorCode.FORBIDDEN, '未配置 ADMIN_TOKEN，后台接口已关闭');
  }
  const token = req.get('x-admin-token') || '';
  if (!token || !safeEqual(token, config.adminToken)) {
    return fail(res, 401, ErrorCode.UNAUTHORIZED, '管理令牌无效');
  }
  next();
}

/**
 * 管理后台登录：账号固定为 ADMIN_ACCOUNT，密码为 ADMIN_TOKEN。
 * 两者都用常量时间比较，避免从响应时间推断。
 */
export function verifyAdminCredentials(account, password) {
  if (!config.adminToken) {
    return false;
  }
  const accountOk = safeEqual(account, config.adminAccount);
  const passwordOk = safeEqual(password, config.adminToken);
  return accountOk && passwordOk;
}

export function signAdminToken() {
  return jwt.sign(
    { sub: 'admin', role: 'admin' },
    config.jwtSecret,
    { expiresIn: config.adminJwtTtl, algorithm: 'HS256' }
  );
}

/** 管理后台 JWT：必须带 role=admin，普通用户 token 不能访问后台接口 */
export function requireAdminJwt(req, res, next) {
  const token = readBearer(req);
  if (!token) {
    return fail(res, 401, ErrorCode.UNAUTHORIZED, '请先登录管理后台');
  }
  let payload;
  try {
    payload = jwt.verify(token, config.jwtSecret, { algorithms: ['HS256'] });
  } catch (err) {
    const expired = err?.name === 'TokenExpiredError';
    return fail(
      res,
      401,
      expired ? ErrorCode.TOKEN_EXPIRED : ErrorCode.UNAUTHORIZED,
      expired ? '管理登录已过期，请重新登录' : '管理登录状态无效'
    );
  }
  if (payload.role !== 'admin' || payload.sub !== 'admin') {
    return fail(res, 403, ErrorCode.FORBIDDEN, '没有后台管理权限');
  }
  req.admin = { account: config.adminAccount };
  next();
}
