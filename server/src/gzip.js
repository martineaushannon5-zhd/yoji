import crypto from 'node:crypto';
import zlib from 'node:zlib';

const JSON_TYPE = 'application/json; charset=utf-8';

/** 解析 Accept-Encoding，判断客户端是否接受 gzip 且未被 q=0 显式拒绝 */
function acceptsGzip(header) {
  if (!header) {
    return false;
  }
  for (const part of String(header).toLowerCase().split(',')) {
    const [coding, ...params] = part.trim().split(';');
    if (coding !== 'gzip') {
      continue;
    }
    for (const param of params) {
      const [key, value] = param.trim().split('=');
      if (key === 'q' && Number.parseFloat(value) === 0) {
        return false;
      }
    }
    return true;
  }
  return false;
}

/**
 * 对较大的 JSON 响应做 gzip 压缩，并按 ETag 复用压缩结果。
 *
 * 词表全量接口（/api/wordbooks/full）在真实数据下约 4–5MB，App 每次启动都会拉取。
 * Nginx 已开 gzip 的部署不受影响（它不会重复压缩），但开发直连、局域网调试、
 * 未经反代的单机部署能少传 90% 以上的字节；配合 If-None-Match 可整包返回 304。
 */
export function gzipJson({ threshold = 1024, cacheEntries = 8, cacheBytes = 8 * 1024 * 1024 } = {}) {
  const cache = new Map();
  let cacheSize = 0;

  function remember(etag, buffer) {
    if (cache.has(etag)) {
      return cache.get(etag);
    }
    while (cache.size > 0 && (cache.size >= cacheEntries || cacheSize + buffer.length > cacheBytes)) {
      const oldest = cache.keys().next().value;
      cacheSize -= cache.get(oldest).length;
      cache.delete(oldest);
    }
    cache.set(etag, buffer);
    cacheSize += buffer.length;
    return buffer;
  }

  return function gzipJsonMiddleware(req, res, next) {
    if (!acceptsGzip(req.headers['accept-encoding'])) {
      return next();
    }

    const originalJson = res.json.bind(res);

    res.json = (payload) => {
      const text = JSON.stringify(payload);
      if (typeof text !== 'string' || Buffer.byteLength(text) < threshold) {
        return originalJson(payload);
      }

      const etag = `W/"${crypto.createHash('sha1').update(text).digest('base64url').slice(0, 27)}"`;
      res.setHeader('Vary', 'Accept-Encoding');
      res.setHeader('ETag', etag);
      res.setHeader('Cache-Control', 'no-cache');

      const ifNoneMatch = req.headers['if-none-match'];
      if (ifNoneMatch && ifNoneMatch.split(',').some((value) => value.trim() === etag)) {
        res.statusCode = 304;
        res.removeHeader('Content-Type');
        res.removeHeader('Content-Encoding');
        res.removeHeader('Content-Length');
        return res.end();
      }

      const compressed = cache.get(etag) || remember(etag, zlib.gzipSync(text));
      res.setHeader('Content-Type', JSON_TYPE);
      res.setHeader('Content-Encoding', 'gzip');
      res.setHeader('Content-Length', compressed.length);
      return res.end(compressed);
    };

    next();
  };
}