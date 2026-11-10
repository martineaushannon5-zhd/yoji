#!/usr/bin/env node
/**
 * 把数据库里的媒体地址从旧前缀批量替换为新前缀（默认只预览，不写库）。
 *
 * 用法（在 server 目录下执行）：
 *   node scripts/rewrite-media-urls.mjs --to=https://cdn.example.com/media
 *   node scripts/rewrite-media-urls.mjs --to=https://cdn.example.com/media --apply
 *
 * 可选参数：
 *   --db=路径          默认 ../data/yoji.db
 *   --from=/media      旧前缀，默认 /media
 *   --apply            真正写库（不加只打印将要修改的行）
 *   --include-avatars  同时改写 users.avatar
 *   --no-backup        不自动备份（默认写库前会复制一份 .bak-时间戳）
 *
 * 背景：videos.video_url / thumb_url 存的是相对路径（/media/videos/x.mp4），
 * App 与后台的 resolveMediaUrl 会把相对路径拼到 API 域名上，绝对 URL 原样使用。
 * 迁到 OSS/CDN 后执行本脚本，即可让客户端直接走新地址。
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { DatabaseSync } from 'node:sqlite';

const here = path.dirname(fileURLToPath(import.meta.url));
const argv = process.argv.slice(2);

function arg(name, fallback = '') {
  const hit = argv.find((item) => item.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : fallback;
}

function flag(name) {
  return argv.includes(`--${name}`);
}

const apply = flag('apply');
const includeAvatars = flag('include-avatars');
const backup = !flag('no-backup');
const from = arg('from', '/media').replace(/\/+$/, '');
const to = arg('to', '').replace(/\/+$/, '');
const dbFile = path.resolve(arg('db', path.join(here, '..', 'data', 'yoji.db')));

if (!to) {
  console.error('缺少 --to，例如 --to=https://cdn.example.com/media');
  process.exit(1);
}
if (!/^https?:\/\//i.test(to)) {
  console.error('--to 必须是 http(s) 地址');
  process.exit(1);
}
if (!from.startsWith('/')) {
  console.error('--from 必须是以 / 开头的路径前缀');
  process.exit(1);
}
if (!fs.existsSync(dbFile)) {
  console.error(`数据库不存在：${dbFile}`);
  process.exit(1);
}

function rewrite(url) {
  if (!url || /^https?:\/\//i.test(url)) {
    return url;
  }
  return url.startsWith(from) ? `${to}${url.slice(from.length)}` : url;
}

const db = new DatabaseSync(dbFile);
db.exec('PRAGMA busy_timeout = 5000;');

const videos = db
  .prepare('SELECT id, title, video_url, thumb_url FROM videos ORDER BY sort_order ASC')
  .all();

const videoChanges = [];
for (const row of videos) {
  const videoUrl = rewrite(row.video_url);
  const thumbUrl = rewrite(row.thumb_url);
  if (videoUrl !== row.video_url || thumbUrl !== row.thumb_url) {
    videoChanges.push({ id: row.id, title: row.title, videoUrl, thumbUrl, oldVideoUrl: row.video_url });
  }
}

const avatarChanges = [];
if (includeAvatars) {
  const users = db.prepare("SELECT id, nickname, avatar FROM users WHERE avatar <> ''").all();
  for (const row of users) {
    const avatar = rewrite(row.avatar);
    if (avatar !== row.avatar) {
      avatarChanges.push({ id: row.id, nickname: row.nickname, avatar, oldAvatar: row.avatar });
    }
  }
}

console.log(`数据库：${dbFile}`);
console.log(`替换规则：${from} -> ${to}`);
console.log(`视频行：${videos.length} 条，需要修改 ${videoChanges.length} 条`);
console.log(`头像行：${includeAvatars ? avatarChanges.length : '未处理（加 --include-avatars 启用）'}`);

for (const item of videoChanges.slice(0, 10)) {
  console.log(`  - ${item.id}  ${item.oldVideoUrl}  ->  ${item.videoUrl}`);
}
if (videoChanges.length > 10) {
  console.log(`  ... 其余 ${videoChanges.length - 10} 条省略`);
}

if (!apply) {
  console.log('\n当前是预览模式，未写库。确认无误后加 --apply 执行。');
  process.exit(0);
}
if (videoChanges.length === 0 && avatarChanges.length === 0) {
  console.log('\n没有需要修改的行，退出。');
  process.exit(0);
}

if (backup) {
  const stamp = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 14);
  const backupFile = `${dbFile}.bak-${stamp}`;
  fs.copyFileSync(dbFile, backupFile);
  console.log(`\n已备份数据库：${backupFile}`);
}

const updateVideo = db.prepare('UPDATE videos SET video_url = ?, thumb_url = ?, updated_at = ? WHERE id = ?');
const updateAvatar = db.prepare('UPDATE users SET avatar = ?, updated_at = ? WHERE id = ?');
const now = new Date().toISOString();

db.exec('BEGIN');
try {
  for (const item of videoChanges) {
    updateVideo.run(item.videoUrl, item.thumbUrl, now, item.id);
  }
  for (const item of avatarChanges) {
    updateAvatar.run(item.avatar, now, item.id);
  }
  db.exec('COMMIT');
} catch (error) {
  db.exec('ROLLBACK');
  throw error;
}

console.log(`\n完成：视频 ${videoChanges.length} 条，头像 ${avatarChanges.length} 条。`);
console.log('提示：App / 后台对绝对 URL 会原样使用，无需改客户端；建议再抽查 2-3 个视频能否播放。');