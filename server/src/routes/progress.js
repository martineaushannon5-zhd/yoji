import { Router } from 'express';
import { requireAuth } from '../auth.js';
import { getProgress, saveProgress, updateUserNickname } from '../db.js';
import { config } from '../config.js';
import { asyncRoute, ErrorCode, fail, ok } from '../http.js';
import { mergeSnapshots, sanitizeSnapshot } from '../progress.js';

export const progressRouter = Router();
progressRouter.use(requireAuth);

function tooLarge(data) {
  try {
    return Buffer.byteLength(JSON.stringify(data), 'utf8') > config.maxProgressBytes;
  } catch {
    return true;
  }
}

/** 读取云端进度（客户端登录后 / 启动时拉取） */
progressRouter.get(
  '/',
  asyncRoute(async (req, res) => {
    const stored = getProgress(req.user.id);
    return ok(res, {
      version: stored.version,
      updatedAt: stored.updatedAt,
      data: sanitizeSnapshot(stored.data)
    });
  })
);

/**
 * 合并同步：把本地快照与云端快照做并集合并，返回合并后的权威结果。
 * 客户端每次学习后（防抖）调用，多个设备之间不会互相覆盖。
 */
progressRouter.post(
  '/sync',
  asyncRoute(async (req, res) => {
    const clientData = req.body?.data;
    if (!clientData || typeof clientData !== 'object' || Array.isArray(clientData)) {
      return fail(res, 400, ErrorCode.BAD_REQUEST, 'data 必须是进度对象');
    }
    if (tooLarge(clientData)) {
      return fail(res, 413, ErrorCode.BAD_REQUEST, '进度数据过大');
    }

    const stored = getProgress(req.user.id);
    const merged = mergeSnapshots(stored.data, clientData);
    const saved = saveProgress(req.user.id, merged);
    // 昵称随进度一起同步到 users 表，后台用户列表可直接展示
    if (merged.nickname && merged.nickname !== req.user.nickname) {
      updateUserNickname(req.user.id, merged.nickname);
    }
    return ok(res, {
      version: saved.version,
      updatedAt: saved.updatedAt,
      data: merged
    }, '已同步');
  })
);

/**
 * 覆盖写入：用于「清空学习记录」这类必须让云端跟随本地清空的场景。
 * 默认做乐观锁校验；force=true 时强制覆盖。
 */
progressRouter.put(
  '/',
  asyncRoute(async (req, res) => {
    const clientData = req.body?.data;
    if (!clientData || typeof clientData !== 'object' || Array.isArray(clientData)) {
      return fail(res, 400, ErrorCode.BAD_REQUEST, 'data 必须是进度对象');
    }
    if (tooLarge(clientData)) {
      return fail(res, 413, ErrorCode.BAD_REQUEST, '进度数据过大');
    }

    const force = req.body?.force === true;
    const expectedVersion = force ? null : Number.isInteger(req.body?.expectedVersion)
      ? req.body.expectedVersion
      : null;
    const snapshot = sanitizeSnapshot(clientData);
    const saved = saveProgress(req.user.id, snapshot, expectedVersion);

    if (saved.conflict) {
      const current = getProgress(req.user.id);
      return res.status(409).json({
        code: ErrorCode.CONFLICT,
        message: '云端数据已更新，请先拉取最新进度',
        data: {
          version: current.version,
          updatedAt: current.updatedAt,
          data: sanitizeSnapshot(current.data)
        }
      });
    }
    return ok(res, {
      version: saved.version,
      updatedAt: saved.updatedAt,
      data: snapshot
    }, '已保存');
  })
);
