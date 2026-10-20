/** 统一响应格式：{ code: 0, message, data }，code 为 0 表示成功 */
export function ok(res, data = null, message = 'ok') {
  res.json({ code: 0, message, data });
}

/** 业务错误：HTTP 状态码 + 业务错误码，前端可同时用两者判断 */
export function fail(res, status, code, message) {
  res.status(status).json({ code, message, data: null });
}

/** 包裹 async 路由，异常统一交给 errorHandler，避免 unhandledRejection */
export function asyncRoute(fn) {
  return (req, res, next) => {
    Promise.resolve(fn(req, res, next)).catch(next);
  };
}

export const ErrorCode = {
  BAD_REQUEST: 1000,
  UNAUTHORIZED: 1001,
  INVALID_CREDENTIALS: 1002,
  ACCOUNT_EXISTS: 1003,
  ACCOUNT_NOT_FOUND: 1004,
  TOKEN_EXPIRED: 1005,
  FORBIDDEN: 1006,
  NOT_FOUND: 1007,
  CONFLICT: 1008,
  RATE_LIMITED: 1009,
  SERVER_ERROR: 1500
};
