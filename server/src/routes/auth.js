import crypto from 'node:crypto';
import { Router } from 'express';
import {
  dummyPasswordHash,
  hashPassword,
  requireAuth,
  signToken,
  verifyPassword
} from '../auth.js';
import {
  bumpTokenVersion,
  createUser,
  findUserByAccount,
  findUserById,
  updateUserProfile
} from '../db.js';
import { asyncRoute, ErrorCode, fail, ok } from '../http.js';

export const authRouter = Router();

const ACCOUNT_RE = /^[A-Za-z0-9_.@+-]{3,64}$/;

function parseAccount(raw) {
  const account = typeof raw === 'string' ? raw.trim() : '';
  if (!ACCOUNT_RE.test(account)) {
    return {
      error: '账号需为 3-64 位字母、数字或 _ . @ + - 字符'
    };
  }
  return { account };
}

function parsePassword(raw) {
  const password = typeof raw === 'string' ? raw : '';
  if (password.length < 6 || password.length > 72) {
    return { error: '密码长度需为 6-72 位' };
  }
  return { password };
}

function authPayload(user) {
  return {
    token: signToken(user),
    userId: user.id,
    account: user.account,
    nickname: user.nickname,
    avatar: user.avatar
  };
}

function defaultNickname(account) {
  const trimmed = account.length > 12 ? account.slice(0, 12) : account;
  return `Yoji.${trimmed}`;
}

authRouter.post(
  '/register',
  asyncRoute(async (req, res) => {
    const accountResult = parseAccount(req.body?.account);
    if (accountResult.error) {
      return fail(res, 400, ErrorCode.BAD_REQUEST, accountResult.error);
    }
    const passwordResult = parsePassword(req.body?.password);
    if (passwordResult.error) {
      return fail(res, 400, ErrorCode.BAD_REQUEST, passwordResult.error);
    }
    const account = accountResult.account;
    if (findUserByAccount(account.toLowerCase())) {
      return fail(res, 409, ErrorCode.ACCOUNT_EXISTS, '该账号已被注册');
    }

    const passwordHash = await hashPassword(passwordResult.password);
    const nickname = defaultNickname(account);
    let user;
    try {
      user = createUser({
        id: crypto.randomUUID(),
        account,
        passwordHash,
        nickname,
        avatar: ''
      });
    } catch (err) {
      // 并发注册同一账号时唯一索引会抛错，转成友好的 409
      if (String(err?.message || '').includes('UNIQUE')) {
        return fail(res, 409, ErrorCode.ACCOUNT_EXISTS, '该账号已被注册');
      }
      throw err;
    }
    return ok(res, authPayload(user), '注册成功');
  })
);

authRouter.post(
  '/login',
  asyncRoute(async (req, res) => {
    const account = typeof req.body?.account === 'string' ? req.body.account.trim() : '';
    const password = typeof req.body?.password === 'string' ? req.body.password : '';
    if (!account || !password) {
      return fail(res, 400, ErrorCode.BAD_REQUEST, '请输入账号和密码');
    }

    const user = findUserByAccount(account.toLowerCase());
    const matched = await verifyPassword(password, user ? user.passwordHash : dummyPasswordHash);
    if (!user || !matched) {
      return fail(res, 401, ErrorCode.INVALID_CREDENTIALS, '账号或密码错误');
    }
    return ok(res, authPayload(user), '登录成功');
  })
);

authRouter.get(
  '/me',
  requireAuth,
  asyncRoute(async (req, res) => {
    const user = findUserById(req.user.id);
    return ok(res, {
      userId: user.id,
      account: user.account,
      nickname: user.nickname,
      avatar: user.avatar,
      createdAt: user.createdAt
    });
  })
);

authRouter.patch(
  '/me',
  requireAuth,
  asyncRoute(async (req, res) => {
    const nicknameRaw = req.body?.nickname;
    const avatarRaw = req.body?.avatar;
    const current = findUserById(req.user.id);

    const nickname = typeof nicknameRaw === 'string' ? nicknameRaw.trim() : current.nickname;
    if (nickname.length < 1 || nickname.length > 24) {
      return fail(res, 400, ErrorCode.BAD_REQUEST, '昵称长度需为 1-24 个字符');
    }
    const avatar = typeof avatarRaw === 'string' ? avatarRaw.trim() : current.avatar;
    if (avatar.length > 500) {
      return fail(res, 400, ErrorCode.BAD_REQUEST, '头像地址过长');
    }
    if (avatar && !/^https?:\/\//i.test(avatar) && !avatar.startsWith('/')) {
      return fail(res, 400, ErrorCode.BAD_REQUEST, '头像需为 http(s) 地址');
    }

    const user = updateUserProfile(req.user.id, { nickname, avatar });
    return ok(res, {
      userId: user.id,
      account: user.account,
      nickname: user.nickname,
      avatar: user.avatar
    }, '已更新');
  })
);

authRouter.post(
  '/logout',
  requireAuth,
  asyncRoute(async (req, res) => {
    // token_version +1，所有设备上的旧 token 立即失效
    bumpTokenVersion(req.user.id);
    return ok(res, null, '已退出登录');
  })
);
