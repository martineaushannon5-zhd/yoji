/** 后端地址解析：自部署实例默认同源，官方域名与 Electron 走官方节点 */

const OFFICIAL_ORIGIN = 'https://yoji.zhdstudy.cyou'

/**
 * 解析 API 根地址（不含 /api）：
 * 1. localStorage.yoji_api_origin 覆盖（便于自部署实例临时指到别的机器）
 * 2. VITE_API_ORIGIN 构建时注入
 * 3. Electron（app://）没有同源后端，回退官方节点
 * 4. 本地开发（localhost/127.0.0.1）默认指向本机 3000 端口的后端
 * 5. 其余情况用当前站点同源 —— 自部署时前端与后端由同一个 Nginx 提供
 */
export function resolveApiOrigin(): string {
  const saved = (localStorage.getItem('yoji_api_origin') || '').trim()
  if (saved) return saved.replace(/\/+$/, '')

  const injected = (import.meta.env.VITE_API_ORIGIN || '').trim()
  if (injected) return injected.replace(/\/+$/, '')

  const { protocol, hostname, port, origin } = window.location
  if (protocol === 'app:') return OFFICIAL_ORIGIN
  if (hostname === 'localhost' || hostname === '127.0.0.1') {
    return 'http://127.0.0.1:3000'
  }
  if (!origin || origin === 'null') return OFFICIAL_ORIGIN
  return origin.replace(/\/+$/, '')
}

export const API_ORIGIN = resolveApiOrigin()
export const API_BASE = `${API_ORIGIN}/api`

/** 把后端返回的相对媒体路径补成可访问的绝对地址 */
export function mediaUrl(url?: string | null): string {
  if (!url) return ''
  if (/^https?:\/\//i.test(url)) return url
  return `${API_ORIGIN}${url}`
}

export { OFFICIAL_ORIGIN }