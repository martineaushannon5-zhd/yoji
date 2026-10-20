import { app } from './app.js';
import { config } from './config.js';
import { db, seedVideosIfEmpty } from './db.js';

const seeded = seedVideosIfEmpty();
if (seeded > 0) {
  console.log(`[startup] 已写入 ${seeded} 条演示视频`);
}

const server = app.listen(config.port, config.host, () => {
  console.log(`[startup] Yoji API listening on http://${config.host}:${config.port}`);
  console.log(`[startup] env=${config.nodeEnv} dataDir=${config.dataDir} mediaDir=${config.mediaDir}`);
  if (!config.adminToken) {
    console.warn('[startup] 未配置 ADMIN_TOKEN，/api/admin 后台接口不可用');
  }
});

let closing = false;
function shutdown(signal) {
  if (closing) {
    return;
  }
  closing = true;
  console.log(`[shutdown] 收到 ${signal}，正在关闭…`);
  server.close(() => {
    try {
      db.close();
    } catch (err) {
      console.error('[shutdown] 关闭数据库失败', err);
    }
    process.exit(0);
  });
  // 兜底：10 秒内没关干净就强退，避免 systemd 一直等
  setTimeout(() => process.exit(1), 10000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
