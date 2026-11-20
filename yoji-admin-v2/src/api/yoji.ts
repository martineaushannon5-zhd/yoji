import request from '@/utils/http'
import { useUserStore } from '@/store/modules/user'

/** Yoji 管理端 API 封装（后端统一返回 { code: 0, message, data }） */

export const API_ORIGIN = 'https://yoji.zhdstudy.cyou'
export const API_BASE = `${API_ORIGIN}/api`

/** 把后端返回的相对媒体路径补成可访问的绝对地址 */
export function mediaUrl(url?: string | null): string {
  if (!url) return ''
  if (/^https?:\/\//i.test(url)) return url
  return `${API_ORIGIN}${url}`
}

export interface LoginResult {
  token: string
  refreshToken?: string
  account: string
  expiresIn: number
}

export interface StatsTrendItem {
  date: string
  label: string
  newUsers: number
  activeUsers: number
}

export interface StatsResult {
  totalUsers: number
  todayActive: number
  totalWords: number
  masteredWords: number
  totalVideos: number
  newUsers7d: number
  trend: StatsTrendItem[]
}

export interface UserRow {
  id: string
  account: string
  nickname: string
  avatar: string
  createdAt: string
  mastered: number
  learning: number
  learnedDays: number
  lastLearnDate: string
  todayLearned: number
  streak: number
  favoriteCount: number
  favoriteVideoCount: number
  customWordCount: number
}

export interface UsersResult {
  users: UserRow[]
  total: number
  page: number
  pageSize: number
}

export interface VideoRow {
  id: string
  title: string
  description: string
  date: string
  videoUrl: string
  thumbUrl: string
  duration: number
  sortOrder: number
  visible: boolean
  createdAt?: string
}

export interface WordBookRow {
  id: string
  name: string
  subtitle?: string
  description?: string
  source?: string
  sortOrder: number
  visible: boolean
  wordCount: number
  createdAt?: string
  updatedAt?: string
}

export interface AuditRow {
  id: number
  account: string
  action: string
  target: string
  detail: string
  ip: string
  createdAt: string
}

export interface AuditResult {
  logs: AuditRow[]
  total: number
  page: number
  pageSize: number
}

export interface StorageInfo {
  mode: 'oss' | 'local'
  publicBase: string
  dir: string
}

export interface UploadTicket {
  mode: string
  host: string
  key: string
  policy: string
  signature: string
  accessKeyId: string
  expire: number
  maxBytes: number
  publicUrl: string
}

/** 登录 */
export function fetchLogin(data: { account: string; password: string }) {
  return request.post<LoginResult>({ url: '/admin/login', params: data })
}

/** 仪表盘统计 */
export interface SystemInfo {
  app: {
    name: string
    version: string
    node: string
    env: string
    startedAt: string
    uptimeSeconds: number
  }
  database: { file: string; bytes: number }
  media: { dir: string; files: number; bytes: number }
  storage: { mode: string; bucket: string; publicBase: string }
  content: {
    wordbooks: number
    visibleWordbooks: number
    words: number
    videos: number
    users: number
    auditLogs: number
  }
}

export function fetchStats() {
  return request.get<StatsResult>({ url: '/admin/stats' })
}

/** 系统信息（版本、运行时、数据库与媒体占用、存储模式） */
export function fetchSystem() {
  return request.get<SystemInfo>({ url: '/admin/system' })
}

/** 用户列表 */
export function fetchUsers(params: { search?: string; page: number; pageSize: number }) {
  return request.get<UsersResult>({ url: '/admin/users', params })
}

/** 删除用户 */
export function deleteUser(id: string) {
  return request.del<null>({ url: `/admin/users/${id}` })
}

/** 导出用户 CSV（直接走 fetch，避免拦截器处理二进制） */
export async function exportUsersCsv(search: string): Promise<Blob> {
  const token = useUserStore().accessToken
  const query = search ? `?search=${encodeURIComponent(search)}` : ''
  const res = await fetch(`${API_BASE}/admin/users/export.csv${query}`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {}
  })
  if (!res.ok) {
    throw new Error('导出失败，请确认登录状态')
  }
  return res.blob()
}

/** 视频列表 */
export function fetchVideos() {
  return request.get<{ videos: VideoRow[] }>({ url: '/admin/videos' })
}

/** 新建视频（登记 URL） */
export function createVideo(data: Partial<VideoRow>) {
  return request.post<VideoRow>({ url: '/admin/videos', params: data })
}

/** 更新视频 */
export function updateVideo(id: string, data: Partial<VideoRow>) {
  return request.request<VideoRow>({ url: `/admin/videos/${id}`, method: 'PATCH', params: data })
}

/** 删除视频 */
export function deleteVideo(id: string) {
  return request.del<null>({ url: `/admin/videos/${id}` })
}

/** 词库列表 */
export function fetchWordbooks() {
  return request.get<{ books: WordBookRow[] }>({ url: '/admin/wordbooks' })
}

/** 更新词库（重命名、排序、显隐） */
export function updateWordbook(id: string, data: Partial<WordBookRow>) {
  return request.request<WordBookRow>({ url: `/admin/wordbooks/${id}`, method: 'PATCH', params: data })
}

/** 删除词库 */
export function deleteWordbook(id: string) {
  return request.del<null>({ url: `/admin/wordbooks/${id}` })
}

/** 审计日志 */
export function fetchAudit(params: { page: number; pageSize: number; action?: string; account?: string }) {
  return request.get<AuditResult>({ url: '/admin/audit', params })
}

/** 存储模式 */
export function fetchStorage() {
  return request.get<StorageInfo>({ url: '/admin/storage' })
}

/** 申请 OSS 直传票据 */
export function signMedia(data: { kind: 'video' | 'thumb'; filename: string }) {
  return request.post<UploadTicket>({ url: '/admin/media/sign', params: data })
}

/** 带进度的 multipart 上传（本地模式） */
export function uploadForm<T>(path: string, form: FormData, onProgress?: (percent: number) => void): Promise<T> {
  const token = useUserStore().accessToken
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest()
    xhr.open('POST', `${API_BASE}${path}`)
    if (token) xhr.setRequestHeader('Authorization', `Bearer ${token}`)
    xhr.upload.onprogress = (event) => {
      if (onProgress && event.lengthComputable) {
        onProgress(Math.round((event.loaded / event.total) * 100))
      }
    }
    xhr.onerror = () => reject(new Error('上传失败，请检查网络'))
    xhr.onload = () => {
      try {
        const payload = JSON.parse(xhr.responseText)
        if (payload.code !== 0) {
          reject(new Error(payload.message || '上传失败'))
          return
        }
        resolve(payload.data as T)
      } catch {
        reject(new Error('上传响应解析失败'))
      }
    }
    xhr.send(form)
  })
}

/** OSS 直传 */
export function putToOss(ticket: UploadTicket, file: File, onProgress?: (percent: number) => void): Promise<void> {
  return new Promise((resolve, reject) => {
    const form = new FormData()
    form.append('key', ticket.key)
    form.append('policy', ticket.policy)
    form.append('OSSAccessKeyId', ticket.accessKeyId)
    form.append('signature', ticket.signature)
    form.append('success_action_status', '200')
    form.append('file', file)
    const xhr = new XMLHttpRequest()
    xhr.open('POST', ticket.host)
    xhr.upload.onprogress = (event) => {
      if (onProgress && event.lengthComputable) {
        onProgress(Math.round((event.loaded / event.total) * 100))
      }
    }
    xhr.onerror = () => reject(new Error('直传 OSS 失败，请检查 Bucket CORS 配置'))
    xhr.onload = () => {
      if (xhr.status >= 200 && xhr.status < 300) resolve()
      else reject(new Error(`OSS 返回 ${xhr.status}`))
    }
    xhr.send(form)
  })
}