import 'dotenv/config';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const serverRoot = path.resolve(here, '..');

function bool(value, fallback) {
  if (value === undefined || value === '') {
    return fallback;
  }
  return value === '1' || value.toLowerCase() === 'true';
}

function int(value, fallback) {
  const n = Number.parseInt(value ?? '', 10);
  return Number.isFinite(n) ? n : fallback;
}

const nodeEnv = process.env.NODE_ENV || 'development';
const jwtSecret = process.env.JWT_SECRET || '';

// 开发环境允许缺省密钥（方便本机跑通），生产环境必须显式配置，避免令牌被伪造
if (nodeEnv === 'production' && jwtSecret.length < 32) {
  throw new Error('生产环境必须设置 JWT_SECRET（至少 32 个字符），请在 .env 中配置');
}

export const config = {
  nodeEnv,
  isProduction: nodeEnv === 'production',
  host: process.env.HOST || '127.0.0.1',
  port: int(process.env.PORT, 3000),
  // 反向代理（Nginx）后面需要信任 X-Forwarded-For，限流与日志才能拿到真实 IP
  trustProxy: bool(process.env.TRUST_PROXY, true),

  jwtSecret: jwtSecret || 'dev-only-secret-change-me-0123456789abcdef',
  jwtTtlDays: int(process.env.JWT_TTL_DAYS, 30),

  adminToken: process.env.ADMIN_TOKEN || '',
  bcryptRounds: Math.min(12, Math.max(8, int(process.env.BCRYPT_ROUNDS, 10))),

  dataDir: path.resolve(process.env.DATA_DIR || path.join(serverRoot, 'data')),
  mediaDir: path.resolve(process.env.MEDIA_DIR || path.join(serverRoot, 'media')),
  publicMediaPrefix: (process.env.PUBLIC_MEDIA_PREFIX || '/media').replace(/\/+$/, ''),
  corsOrigin: process.env.CORS_ORIGIN || '*',

  // 单个用户进度 JSON 的硬上限，防止恶意超大请求
  maxProgressBytes: int(process.env.MAX_PROGRESS_BYTES, 1024 * 1024)
};

export const paths = {
  serverRoot,
  dbFile: path.join(config.dataDir, 'yoji.db')
};
