import { Router } from 'express';
import { getVideo, listVideos } from '../db.js';
import { asyncRoute, ErrorCode, fail, ok } from '../http.js';

export const videosRouter = Router();

// 公开接口：App 未登录也可以浏览视频列表（只返回可见视频）
videosRouter.get(
  '/',
  asyncRoute(async (req, res) => {
    const keyword = typeof req.query.keyword === 'string' ? req.query.keyword.trim() : '';
    let videos = listVideos();
    if (keyword) {
      const lower = keyword.toLowerCase();
      videos = videos.filter((v) =>
        v.title.toLowerCase().includes(lower) || v.description.toLowerCase().includes(lower)
      );
    }
    return ok(res, { videos });
  })
);

videosRouter.get(
  '/:id',
  asyncRoute(async (req, res) => {
    const video = getVideo(req.params.id);
    if (!video || !video.visible) {
      return fail(res, 404, ErrorCode.NOT_FOUND, '视频不存在');
    }
    return ok(res, video);
  })
);
