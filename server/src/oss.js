import crypto from 'node:crypto';

/**
 * 阿里云 OSS 直传签名。
 *
 * 背景：视频如果继续走 Node 中转（浏览器 → ECS → 磁盘），会一直占用服务器磁盘，
 * 大文件上传还会吃满 2C2G 小机器的带宽。这里改成浏览器直传 OSS：
 * 浏览器先向后台要一份一次性上传策略（policy + signature），再自己 POST 给 OSS，
 * Node 只负责签名和登记元数据，不再接触文件本体。
 *
 * 不引入 ali-oss SDK：POST 策略签名只用到 HMAC-SHA1，标准库足够。
 * 需要在 .env 里配置 OSS_ACCESS_KEY_ID / OSS_ACCESS_KEY_SECRET / OSS_BUCKET /
 * OSS_REGION / OSS_PUBLIC_BASE，缺任意一项就自动退回本地磁盘模式。
 */

const VIDEO_EXTS = new Set(['.mp4', '.webm', '.m4v']);
const THUMB_EXTS = new Set(['.png', '.jpg', '.jpeg', '.webp']);

const LIMITS = {
  video: 900 * 1024 * 1024,
  thumb: 5 * 1024 * 1024
};

function env(name) {
  return String(process.env[name] || '').trim();
}

export function ossConfig() {
  const accessKeyId = env('OSS_ACCESS_KEY_ID');
  const accessKeySecret = env('OSS_ACCESS_KEY_SECRET');
  const bucket = env('OSS_BUCKET');
  const region = env('OSS_REGION');
  const publicBase = env('OSS_PUBLIC_BASE').replace(/\/+$/, '');
  const dir = (env('OSS_DIR') || 'media').replace(/^\/+|\/+$/g, '') || 'media';
  const ttl = Number.parseInt(env('OSS_SIGN_TTL'), 10);

  const enabled = Boolean(accessKeyId && accessKeySecret && bucket && region && publicBase);
  return {
    enabled,
    accessKeyId,
    accessKeySecret,
    bucket,
    region,
    publicBase,
    dir,
    ttlSeconds: Number.isFinite(ttl) && ttl > 0 && ttl <= 3600 ? ttl : 600,
    host: env('OSS_ENDPOINT') || `https://${bucket}.${region}.aliyuncs.com`
  };
}

export function storageMode() {
  return ossConfig().enabled ? 'oss' : 'local';
}

function safeExt(name, allowed) {
  const ext = (String(name || '').match(/\.[a-z0-9]+$/i)?.[0] || '').toLowerCase();
  return allowed.has(ext) ? ext : '';
}

function yyyymm() {
  const d = new Date();
  return `${d.getUTCFullYear()}${String(d.getUTCMonth() + 1).padStart(2, '0')}`;
}

/**
 * 生成一次直传所需的 policy / signature。
 * @param {{kind:'video'|'thumb', filename:string}} input
 */
export function createUploadTicket({ kind, filename }) {
  const conf = ossConfig();
  if (!conf.enabled) {
    return { error: 'OSS 未配置' };
  }
  const allowed = kind === 'thumb' ? THUMB_EXTS : VIDEO_EXTS;
  const ext = safeExt(filename, allowed);
  if (!ext) {
    return {
      error: kind === 'thumb'
        ? '封面仅支持 png/jpg/webp'
        : '视频仅支持 mp4/webm/m4v'
    };
  }

  const prefix = `${conf.dir}/${kind === 'thumb' ? 'thumbs' : 'videos'}/${yyyymm()}/`;
  const key = `${prefix}${Date.now().toString(36)}-${crypto.randomBytes(6).toString('hex')}${ext}`;
  const maxBytes = LIMITS[kind] || LIMITS.video;
  const expire = new Date(Date.now() + conf.ttlSeconds * 1000).toISOString();

  const policy = Buffer.from(JSON.stringify({
    expiration: expire,
    conditions: [
      ['content-length-range', 0, maxBytes],
      ['starts-with', '$key', prefix]
    ]
  })).toString('base64');

  const signature = crypto
    .createHmac('sha1', conf.accessKeySecret)
    .update(policy)
    .digest('base64');

  return {
    mode: 'oss',
    host: conf.host,
    key,
    policy,
    signature,
    accessKeyId: conf.accessKeyId,
    expire,
    maxBytes,
    publicUrl: `${conf.publicBase}/${key}`
  };
}