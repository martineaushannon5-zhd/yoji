// 后端 /api/videos 返回的视频结构（字段与 server/src/db.js 一致）
export interface RemoteVideo {
  id: string;
  title: string;
  description: string;
  date: string;
  thumbUrl: string;
  videoUrl: string;
  duration: number;
  sortOrder: number;
  visible: boolean;
}

// 视频条目模型：id、标题、上传日期、缩略图与视频资源
// thumb / src 允许是本地 Resource，也允许是后端返回的 http(s) 链接
export interface VideoItem {
  id: string;
  title: string;
  description: string;
  date: string;
  thumb: ResourceStr;
  src: ResourceStr;
}
