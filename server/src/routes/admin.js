import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import { Router } from 'express';
import multer from 'multer';
import { requireAdminAccess } from '../auth.js';
import {
  createVideo,
  deleteVideo,
  getVideo,
  listVideos,
  updateVideo
} from '../db.js';
import { config } from '../config.js';
import { asyncRoute, ErrorCode, fail, ok } from '../http.js';
import { syncMedia } from '../media-sync.js';

export const adminRouter = Router();
adminRouter.use(requireAdminAccess);

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

/* ---------------------------- 视频文件上传 ---------------------------- */

const VIDEO_UPLOAD_EXTS = new Set(['.mp4', '.webm', '.m4v']);
const COVER_UPLOAD_EXTS = new Set(['.png', '.jpg', '.jpeg', '.webp']);

function uploadBaseName(originalname) {
  const ext = path.extname(originalname || '').toLowerCase();
  const base = path.basename(originalname || '', ext)
    .replace(/[^\w.-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60);
  return { base: base || 'video', ext };
}

const uploadStorage = multer.diskStorage({
  destination(req, file, cb) {
    const dir = file.fieldname === 'cover'
      ? path.join(config.mediaDir, 'thumbs')
      : path.join(config.mediaDir, 'videos');
    try {
      fs.mkdirSync(dir, { recursive: true });
      cb(null, dir);
    } catch (err) {
      cb(err);
    }
  },
  filename(req, file, cb) {
    const { base, ext } = uploadBaseName(file.originalname);
    cb(null, `${base}-${Date.now().toString(36)}-${crypto.randomBytes(3).toString('hex')}${ext}`);
  }
});

const uploadVideoFields = multer({
  storage: uploadStorage,
  limits: { fileSize: 900 * 1024 * 1024, files: 2 },
  fileFilter(req, file, cb) {
    const ext = path.extname(file.originalname || '').toLowerCase();
    if (file.fieldname === 'video' && VIDEO_UPLOAD_EXTS.has(ext)) {
      cb(null, true);
      return;
    }
    if (file.fieldname === 'cover' && COVER_UPLOAD_EXTS.has(ext)) {
      cb(null, true);
      return;
    }
    cb(new Error('视频仅支持 mp4/webm/m4v，封面仅支持 png/jpg/webp'));
  }
}).fields([
  { name: 'video', maxCount: 1 },
  { name: 'cover', maxCount: 1 }
]);

function receiveVideoFiles(req, res, next) {
  uploadVideoFields(req, res, (err) => {
    if (err) {
      return fail(res, 400, ErrorCode.BAD_REQUEST, err.message || '上传失败');
    }
    return next();
  });
}

function removeUploaded(files) {
  for (const list of Object.values(files || {})) {
    for (const file of list) {
      fs.unlink(file.path, () => {});
    }
  }
}

function publicFileUrl(segment, filename) {
  return `${config.publicMediaPrefix}/${segment}/${encodeURIComponent(filename)}`;
}

adminRouter.post(
  '/videos/upload',
  receiveVideoFiles,
  asyncRoute(async (req, res) => {
    const videoFile = req.files?.video?.[0];
    const coverFile = req.files?.cover?.[0];
    if (!videoFile) {
      removeUploaded(req.files);
      return fail(res, 400, ErrorCode.BAD_REQUEST, '请选择视频文件');
    }
    if (coverFile && coverFile.size > 5 * 1024 * 1024) {
      removeUploaded(req.files);
      return fail(res, 400, ErrorCode.BAD_REQUEST, '封面不能超过 5MB');
    }

    const originalBase = path.basename(videoFile.originalname, path.extname(videoFile.originalname));
    const title = text(req.body?.title, 100) || originalBase.replace(/[_-]+/g, ' ').trim().slice(0, 100);
    if (!title) {
      removeUploaded(req.files);
      return fail(res, 400, ErrorCode.BAD_REQUEST, '标题不能为空');
    }
    let date = text(req.body?.date, 10) || new Date().toISOString().slice(0, 10);
    if (!DATE_RE.test(date)) {
      removeUploaded(req.files);
      return fail(res, 400, ErrorCode.BAD_REQUEST, 'date 需为 YYYY-MM-DD 格式');
    }

    let id = text(req.body?.id, 64).toLowerCase();
    if (!id) {
      id = `video-${Date.now().toString(36)}-${crypto.randomBytes(3).toString('hex')}`;
    }
    if (!ID_RE.test(id)) {
      removeUploaded(req.files);
      return fail(res, 400, ErrorCode.BAD_REQUEST, 'id 需为 2-64 位小写字母、数字、_ 或 -');
    }
    if (getVideo(id)) {
      removeUploaded(req.files);
      return fail(res, 409, ErrorCode.CONFLICT, '该 id 已存在');
    }

    const sortRaw = Number(req.body?.sortOrder);
    const sortOrder = Number.isFinite(sortRaw)
      ? Math.trunc(sortRaw)
      : Math.max(0, ...listVideos({ includeHidden: true }).map((item) => item.sortOrder)) + 1;
    const visible = String(req.body?.visible ?? 'true') !== 'false';

    try {
      const video = createVideo({
        id,
        title,
        description: text(req.body?.description, 500),
        date,
        thumbUrl: coverFile ? publicFileUrl('thumbs', coverFile.filename) : '',
        videoUrl: publicFileUrl('videos', videoFile.filename),
        duration: 0,
        sortOrder,
        visible
      });
      return ok(res, video, '视频已上传');
    } catch (err) {
      removeUploaded(req.files);
      throw err;
    }
  })
);

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
