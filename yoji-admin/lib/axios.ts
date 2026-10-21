import axios from "axios";

export const TOKEN_KEY = "yoji_admin_token";

// 开发环境 .env.development 指向 http://120.24.171.99
// 生产环境 .env.production 留空，得到同源 /api，由 Nginx 反代，避免混合内容
const rawOrigin = process.env.NEXT_PUBLIC_API_ORIGIN ?? "";
const origin = rawOrigin.replace(/\/+$/, "");
export const API_BASE_URL = `${origin}/api`;

export const api = axios.create({
  baseURL: API_BASE_URL,
  timeout: 20000,
  headers: {
    "Content-Type": "application/json",
  },
});

api.interceptors.request.use((config) => {
  if (typeof window !== "undefined") {
    const token = window.localStorage.getItem(TOKEN_KEY);
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
  }
  return config;
});

api.interceptors.response.use(
  (response) => response,
  (error) => {
    if (typeof window !== "undefined") {
      const status = error?.response?.status;
      const isLoginRequest = String(error?.config?.url || "").includes("/admin/login");
      if (status === 401 && !isLoginRequest && window.location.pathname !== "/login") {
        window.localStorage.removeItem(TOKEN_KEY);
        window.location.assign("/login");
      }
    }
    return Promise.reject(error);
  }
);

export function getApiErrorMessage(error: unknown): string {
  if (axios.isAxiosError(error)) {
    const payload = error.response?.data as { message?: string } | undefined;
    if (payload?.message) {
      return payload.message;
    }
    if (error.code === "ECONNABORTED") {
      return "请求超时，请稍后重试";
    }
    if (!error.response) {
      return "无法连接服务器，请检查网络";
    }
  }
  return "请求失败，请稍后重试";
}
