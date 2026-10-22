import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

import { config } from './config.js';
import { createVideo, getVideo, listVideos, updateVideo } from './db.js';

const VIDEO_EXTS = new Set(['.mp4', '.webm', '.m4v']);
const IMAGE_EXTS = new Set(['.png', '.jpg', '.jpeg', '.webp']);

function baseName(file) {
  return path.basename(file, path.extname(file));
}

function slugify(value) {
  const slug = value
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48);
  if (slug.length >= 2) {
    return slug;
  }
  return `video-${crypto.createHash('sha1').update(value).digest('hex').slice(0, 10)}`;
}

function titleize(value) {
  const title = value.replace(/[_-]+/g, ' ').replace(/\s+/g, ' ').trim();
  return title || value;
}

function fileNameFromUrl(url) {
  try {
    const parsed = new URL(String(url || ''), 'http://localhost');
    return decodeURIComponent(path.basename(parsed.pathname));
  } catch {
    return path.basename(String(url || ''));
  }
}

function buildUrl(segment, file) {
  return `${config.publicMediaPrefix}/${segment}/${encodeURIComponent(file)}`;
}

function listFiles(dir, extensions) {
  if (!fs.existsSync(dir)) {
    return [];
  }
  return fs
    .readdirSync(dir)
    .filter((name) => extensions.has(path.extname(name).toLowerCase()))
    .sort();
}

function findThumb(thumbs, videoBase) {
  const target = videoBase.toLowerCase();
  const exact = thumbs.find((name) => baseName(name).toLowerCase() === target);
  if (exact) {
    return exact;
  }
  // 兼容 video_xxx / xxx_cover 这类命名
  return thumbs.find((name) => {
    const base = baseName(name).toLowerCase();
    return base.startsWith(target) || target.startsWith(base);
  });
}

/**
 * 扫描 media/videos 与 media/thumbs，把新增文件登记到 videos 表。
 * 文件名即标题来源；同一个视频文件重复扫描不会重复插入。
 */
export function syncMedia() {
  const videoDir = path.join(config.mediaDir, 'videos');
  const thumbDir = path.join(config.mediaDir, 'thumbs');
  const videoFiles = listFiles(videoDir, VIDEO_EXTS);
  const thumbFiles = listFiles(thumbDir, IMAGE_EXTS);
  const existing = listVideos({ includeHidden: true });

  const byFile = new Map();
  let sortOrder = 0;
  for (const video of existing) {
    byFile.set(fileNameFromUrl(video.videoUrl).toLowerCase(), video);
    sortOrder = Math.max(sortOrder, Number(video.sortOrder) || 0);
  }

  let created = 0;
  let updated = 0;

  for (const file of videoFiles) {
    const base = baseName(file);
    const thumb = findThumb(thumbFiles, base);
    const videoUrl = buildUrl('videos', file);
    const thumbUrl = thumb ? buildUrl('thumbs', thumb) : '';
    const current = byFile.get(file.toLowerCase());

    if (current) {
      if (current.videoUrl !== videoUrl || (thumbUrl && current.thumbUrl !== thumbUrl)) {
        updateVideo(current.id, {
          videoUrl,
          thumbUrl: thumbUrl || current.thumbUrl
        });
        updated += 1;
      }
      continue;
    }

    const stat = fs.statSync(path.join(videoDir, file));
    let id = slugify(base);
    if (getVideo(id)) {
      id = `${id.slice(0, 40)}-${crypto.createHash('sha1').update(file).digest('hex').slice(0, 6)}`;
    }
    let attempt = 1;
    while (getVideo(id)) {
      id = `${id.slice(0, 50)}-${attempt}`;
      attempt += 1;
    }
    createVideo({
      id,
      title: titleize(base),
      description: '',
      date: stat.mtime.toISOString().slice(0, 10),
      thumbUrl,
      videoUrl,
      duration: 0,
      sortOrder: sortOrder + 1,
      visible: true
    });
    sortOrder += 1;
    created += 1;
  }

  return {
    created,
    updated,
    total: listVideos({ includeHidden: true }).length,
    videos: listVideos()
  };
}
