import crypto from 'node:crypto';
import { Router } from 'express';
import { requireAdmin } from '../auth.js';
import {
  createVideo,
  deleteVideo,
  getVideo,
  listVideos,
  updateVideo
} from '../db.js';
import { asyncRoute, ErrorCode, fail, ok } from '../http.js';
import { syncMedia } from '../media-sync.js';

export const adminRouter = Router();
adminRouter.use(requireAdmin);

const DATE_RE = /^\d{4}-\d{2}-\d{2}$/;
const ID_RE = /^[a-z0-9][a-z0-9_-]{1,63}$/;

function text(value, maxLength) {
  return typeof value === 'string' ? value.trim().slice(0, maxLength) : '';
}

function isMediaUrl(value) {
  if (!value || value.length > 1000) {
    return false;
  }
  return value.startsWith('/') || /^https?:\/\//i.test(value);
}

function parseVideoInput(body, existing = null) {
  const title = text(body?.title, 100) || existing?.title || '';
  if (!title) {
    return { error: '标题不能为空' };
  }

  const description = body?.description === undefined
    ? existing?.description ?? ''
    : text(body.description, 500);

  let date = body?.date === undefined ? existing?.date ?? '' : text(body.date, 10);
  if (!date) {
    date = new Date().toISOString().slice(0, 10);
  }
  if (!DATE_RE.test(date)) {
    return { error: 'date 需为 YYYY-MM-DD 格式' };
  }

  const thumbUrl = body?.thumbUrl === undefined ? existing?.thumbUrl ?? '' : text(body.thumbUrl, 1000);
  if (thumbUrl && !isMediaUrl(thumbUrl)) {
    return { error: 'thumbUrl 需为 / 开头的站内路径或 http(s) 地址' };
  }

  const videoUrl = body?.videoUrl === undefined ? existing?.videoUrl ?? '' : text(body.videoUrl, 1000);
  if (!videoUrl || !isMediaUrl(videoUrl)) {
    return { error: 'videoUrl 必填，需为 / 开头的站内路径或 http(s) 地址' };
  }

  const duration = Number.isFinite(Number(body?.duration))
    ? Math.max(0, Math.trunc(Number(body.duration)))
    : existing?.duration ?? 0;
  const sortOrder = Number.isFinite(Number(body?.sortOrder))
    ? Math.trunc(Number(body.sortOrder))
    : existing?.sortOrder ?? 0;
  const visible = body?.visible === undefined ? existing?.visible ?? true : body.visible !== false;

  return {
    value: { title, description, date, thumbUrl, videoUrl, duration, sortOrder, visible }
  };
}

adminRouter.get(
  '/ping',
  asyncRoute(async (req, res) => ok(res, { ok: true }, 'admin token valid'))
);

adminRouter.get(
  '/videos',
  asyncRoute(async (req, res) => ok(res, { videos: listVideos({ includeHidden: true }) }))
);

// 扫描 media/videos 与 media/thumbs，把新上传的文件登记为视频记录
adminRouter.post(
  '/videos/scan',
  asyncRoute(async (req, res) => ok(res, syncMedia(), '媒体扫描完成'))
);

adminRouter.post(
  '/videos',
  asyncRoute(async (req, res) => {
    const parsed = parseVideoInput(req.body);
    if (parsed.error) {
      return fail(res, 400, ErrorCode.BAD_REQUEST, parsed.error);
    }
    let id = text(req.body?.id, 64).toLowerCase();
    if (!id) {
      id = `video-${Date.now().toString(36)}-${crypto.randomBytes(3).toString('hex')}`;
    }
    if (!ID_RE.test(id)) {
      return fail(res, 400, ErrorCode.BAD_REQUEST, 'id 需为 2-64 位小写字母、数字、_ 或 -');
    }
    if (getVideo(id)) {
      return fail(res, 409, ErrorCode.CONFLICT, '该 id 已存在');
    }
    const video = createVideo({ id, ...parsed.value });
    return ok(res, video, '已创建');
  })
);

adminRouter.patch(
  '/videos/:id',
  asyncRoute(async (req, res) => {
    const existing = getVideo(req.params.id);
    if (!existing) {
      return fail(res, 404, ErrorCode.NOT_FOUND, '视频不存在');
    }
    const parsed = parseVideoInput(req.body, existing);
    if (parsed.error) {
      return fail(res, 400, ErrorCode.BAD_REQUEST, parsed.error);
    }
    const video = updateVideo(existing.id, parsed.value);
    return ok(res, video, '已更新');
  })
);

adminRouter.delete(
  '/videos/:id',
  asyncRoute(async (req, res) => {
    if (!deleteVideo(req.params.id)) {
      return fail(res, 404, ErrorCode.NOT_FOUND, '视频不存在');
    }
    return ok(res, null, '已删除');
  })
);
