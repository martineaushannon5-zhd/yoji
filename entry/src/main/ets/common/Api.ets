import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { API_BASE_URL } from './Config';
import { ProgressPayload, ProgressSnapshot } from '../model/ProgressModel';
import { RemoteVideo } from '../model/VideoModel';

/* ----------------------------- 响应结构 ----------------------------- */

export interface AuthData {
  token: string;
  userId: string;
  account: string;
  nickname: string;
  avatar: string;
}

interface AuthEnvelope {
  code: number;
  message: string;
  data: AuthData | null;
}

interface ProgressEnvelope {
  code: number;
  message: string;
  data: ProgressPayload | null;
}

interface VideoListPayload {
  videos: RemoteVideo[];
}

interface VideoListEnvelope {
  code: number;
  message: string;
  data: VideoListPayload | null;
}

export interface AuthResult {
  ok: boolean;
  message: string;
  data: AuthData | null;
}

export interface ProgressResult {
  ok: boolean;
  message: string;
  data: ProgressPayload | null;
}

export interface VideoListResult {
  ok: boolean;
  message: string;
  videos: RemoteVideo[];
}

/* ----------------------------- 请求结构 ----------------------------- */

interface LoginBody {
  account: string;
  password: string;
}

interface SyncBody {
  data: ProgressSnapshot;
}

interface PutBody {
  data: ProgressSnapshot;
  force: boolean;
}

interface HttpReply {
  status: number;
  body: string;
  networkError: boolean;
}

function networkErrorText(): string {
  return `无法连接服务器（${API_BASE_URL}），请检查网络后重试`;
}

function authFail(message: string): AuthResult {
  const result: AuthResult = { ok: false, message: message, data: null };
  return result;
}

function progressFail(message: string): ProgressResult {
  const result: ProgressResult = { ok: false, message: message, data: null };
  return result;
}

function videoFail(message: string): VideoListResult {
  const result: VideoListResult = { ok: false, message: message, videos: [] };
  return result;
}

/* ---------------------------- HTTP 基础 ----------------------------- */

class Http {
  static async send(path: string, method: http.RequestMethod, body: string,
    token: string): Promise<HttpReply> {
    const request = http.createHttp();
    try {
      const headers: Record<string, string> = {};
      headers['Content-Type'] = 'application/json';
      if (token !== '') {
        headers['Authorization'] = `Bearer ${token}`;
      }
      const options: http.HttpRequestOptions = {
        method: method,
        header: headers,
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 8000,
        readTimeout: 15000
      };
      const response = await request.request(API_BASE_URL + path, options);
      const reply: HttpReply = {
        status: response.responseCode,
        body: response.result as string,
        networkError: false
      };
      return reply;
    } catch (err) {
      const error = err as BusinessError;
      console.error(`[Api] ${method} ${API_BASE_URL + path} 请求失败 code=${error.code} message=${error.message}`);
      const reply: HttpReply = { status: 0, body: '', networkError: true };
      return reply;
    } finally {
      request.destroy();
    }
  }
}

/* ------------------------------- API -------------------------------- */

export class Api {
  // 相对路径（/media/xxx）拼上服务器域名；完整 http(s) 原样返回
  static resolveMediaUrl(url: string): string {
    if (url === '') {
      return '';
    }
    if (url.indexOf('http://') === 0 || url.indexOf('https://') === 0) {
      return url;
    }
    const base: string = API_BASE_URL.endsWith('/')
      ? API_BASE_URL.substring(0, API_BASE_URL.length - 1)
      : API_BASE_URL;
    return url.startsWith('/') ? `${base}${url}` : `${base}/${url}`;
  }

  static async register(account: string, password: string): Promise<AuthResult> {
    const body: LoginBody = { account: account, password: password };
    const reply = await Http.send('/api/auth/register', http.RequestMethod.POST,
      JSON.stringify(body), '');
    return Api.parseAuth(reply, '注册失败，请稍后重试');
  }

  static async login(account: string, password: string): Promise<AuthResult> {
    const body: LoginBody = { account: account, password: password };
    const reply = await Http.send('/api/auth/login', http.RequestMethod.POST,
      JSON.stringify(body), '');
    return Api.parseAuth(reply, '登录失败，请稍后重试');
  }

  private static parseAuth(reply: HttpReply, fallback: string): AuthResult {
    if (reply.networkError) {
      return authFail(networkErrorText());
    }
    let envelope: AuthEnvelope = { code: -1, message: '', data: null };
    try {
      envelope = JSON.parse(reply.body) as AuthEnvelope;
    } catch (err) {
      return authFail(`服务器响应异常（HTTP ${reply.status}），请稍后重试`);
    }
    if (envelope.code === 0 && envelope.data !== null) {
      const result: AuthResult = { ok: true, message: envelope.message, data: envelope.data };
      return result;
    }
    return authFail(envelope.message !== '' ? envelope.message : fallback);
  }

  static async logout(token: string): Promise<boolean> {
    const reply = await Http.send('/api/auth/logout', http.RequestMethod.POST, '{}', token);
    return !reply.networkError && reply.status >= 200 && reply.status < 300;
  }

  static async getProgress(token: string): Promise<ProgressResult> {
    const reply = await Http.send('/api/progress', http.RequestMethod.GET, '', token);
    return Api.parseProgress(reply, '拉取进度失败');
  }

  static async syncProgress(token: string, snapshot: ProgressSnapshot): Promise<ProgressResult> {
    const body: SyncBody = { data: snapshot };
    const reply = await Http.send('/api/progress/sync', http.RequestMethod.POST,
      JSON.stringify(body), token);
    return Api.parseProgress(reply, '同步进度失败');
  }

  // 覆盖写入：清空学习记录时使用，force=true 表示以本地为准
  static async saveProgressForce(token: string, snapshot: ProgressSnapshot): Promise<ProgressResult> {
    const body: PutBody = { data: snapshot, force: true };
    const reply = await Http.send('/api/progress', http.RequestMethod.PUT,
      JSON.stringify(body), token);
    return Api.parseProgress(reply, '同步进度失败');
  }

  private static parseProgress(reply: HttpReply, fallback: string): ProgressResult {
    if (reply.networkError) {
      return progressFail(networkErrorText());
    }
    let envelope: ProgressEnvelope = { code: -1, message: '', data: null };
    try {
      envelope = JSON.parse(reply.body) as ProgressEnvelope;
    } catch (err) {
      return progressFail(`服务器响应异常（HTTP ${reply.status}），请稍后重试`);
    }
    if (envelope.code === 0 && envelope.data !== null) {
      const result: ProgressResult = { ok: true, message: envelope.message, data: envelope.data };
      return result;
    }
    return progressFail(envelope.message !== '' ? envelope.message : fallback);
  }

  static async fetchVideos(): Promise<VideoListResult> {
    const reply = await Http.send('/api/videos', http.RequestMethod.GET, '', '');
    if (reply.networkError) {
      return videoFail('无法连接服务器，已展示备用视频');
    }
    let envelope: VideoListEnvelope = { code: -1, message: '', data: null };
    try {
      envelope = JSON.parse(reply.body) as VideoListEnvelope;
    } catch (err) {
      return videoFail(`服务器响应异常（HTTP ${reply.status}），已展示备用视频`);
    }
    if (envelope.code === 0 && envelope.data !== null) {
      const result: VideoListResult = {
        ok: true,
        message: envelope.message,
        videos: envelope.data.videos
      };
      return result;
    }
    return videoFail(envelope.message !== '' ? envelope.message : '获取视频列表失败');
  }
}
