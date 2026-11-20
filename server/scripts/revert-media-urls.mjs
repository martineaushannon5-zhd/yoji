#!/usr/bin/env node
/**
 * 把 videos 表里的绝对媒体地址回滚为相对路径（例如 OSS 故障时切回本机 Nginx）。
 *
 * 用法：
 *   node scripts/revert-media-urls.mjs --db=data/yoji.db \
 *     --from=https://yoji-video.oss-cn-shenzhen.aliyuncs.com/media --to=/media
 *   node scripts/revert-media-urls.mjs ... --apply
 *
 * 默认只打印将要修改的行（dry-run）；--apply 才会写库，并自动生成 .bak-时间戳 备份。
 */
import fs from "node:fs";
import path from "node:path";
import { DatabaseSync } from "node:sqlite";

const args = process.argv.slice(2);
const opt = (name, fallback = "") => {
  const hit = args.find((a) => a === `--${name}` || a.startsWith(`--${name}=`));
  if (!hit) return fallback;
  if (hit.includes("=")) return hit.slice(hit.indexOf("=") + 1);
  return args[args.indexOf(hit) + 1] ?? fallback;
};
const dbPath = path.resolve(opt("db", "data/yoji.db"));
const from = opt("from");
const to = opt("to", "/media");
const apply = args.includes("--apply");

if (!from) {
  console.error("缺少 --from（要替换掉的绝对地址前缀，例如 https://cdn.example.com/media）");
  process.exit(1);
}
if (!fs.existsSync(dbPath)) {
  console.error(`数据库不存在：${dbPath}`);
  process.exit(1);
}

const fix = (v) => (typeof v === "string" && v.startsWith(from) ? to + v.slice(from.length) : v);

const db = new DatabaseSync(dbPath);
const rows = db.prepare("SELECT id, video_url, thumb_url FROM videos").all();
const planned = rows
  .map((r) => ({ id: r.id, video_url: fix(r.video_url), thumb_url: fix(r.thumb_url), before: r }))
  .filter((r) => r.video_url !== r.before.video_url || r.thumb_url !== r.before.thumb_url);

console.log(`数据库：${dbPath}`);
console.log(`规则：${from}  ->  ${to}`);
console.log(`视频行 ${rows.length} 条，需要修改 ${planned.length} 条`);
for (const p of planned) {
  console.log(`  #${p.id}`);
  if (p.before.video_url !== p.video_url) console.log(`    video: ${p.before.video_url} -> ${p.video_url}`);
  if (p.before.thumb_url !== p.thumb_url) console.log(`    thumb: ${p.before.thumb_url} -> ${p.thumb_url}`);
}

if (!apply) {
  console.log("\n[dry-run] 未写库；确认无误后加 --apply");
  process.exit(0);
}
if (!planned.length) {
  console.log("没有需要修改的行");
  process.exit(0);
}

const stamp = new Date().toISOString().replace(/[-:T]/g, "").slice(0, 14);
const backup = `${dbPath}.bak-${stamp}`;
fs.copyFileSync(dbPath, backup);
const up = db.prepare("UPDATE videos SET video_url = ?, thumb_url = ?, updated_at = datetime('now') WHERE id = ?");
for (const p of planned) up.run(p.video_url, p.thumb_url, p.id);
console.log(`\n已写库 ${planned.length} 条；备份：${backup}`);