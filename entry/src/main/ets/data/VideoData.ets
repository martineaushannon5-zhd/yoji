import { RemoteVideo, VideoItem } from '../model/VideoModel';
import { Api } from '../common/Api';

// 生成今天日期标签（如 "2026-10-16"）：视频上传日期以今天为主
function today(): string {
  const d = new Date();
  return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
}

// 兜底视频列表：媒体文件已全部迁移到服务器，本地 rawfile 不再打包大视频
export const VIDEO_LIST: VideoItem[] = [
  {
    id: 'ted-anxiety',
    title: '【TED演讲】如何解决焦虑',
    description: 'TED 演讲：如何解决焦虑。',
    date: today(),
    thumb: Api.resolveMediaUrl('/media/thumbs/video_thumb_anxiety.png'),
    src: Api.resolveMediaUrl('/media/videos/anxiety.mp4')
  },
  {
    id: 'casey-sloppy',
    title: '【Casey Neistat】拖延是创造力的毒药',
    description: 'Casey Neistat：拖延是创造力的毒药。',
    date: today(),
    thumb: Api.resolveMediaUrl('/media/thumbs/video_thumb_sloppy.jpg'),
    src: Api.resolveMediaUrl('/media/videos/sloppy.mp4')
  }
];

// 后端返回的视频列表（覆盖内置/兜底列表）
let REMOTE_LIST: VideoItem[] = [];

// 后端 DTO -> 页面 VideoItem：相对媒体路径拼上服务器域名
export function toVideoItems(list: RemoteVideo[]): VideoItem[] {
  const items: VideoItem[] = [];
  for (let i = 0; i < list.length; i++) {
    const v = list[i];
    const item: VideoItem = {
      id: v.id,
      title: v.title,
      description: v.description,
      date: v.date,
      thumb: v.thumbUrl !== '' ? Api.resolveMediaUrl(v.thumbUrl) : $r('app.media.logo'),
      src: Api.resolveMediaUrl(v.videoUrl)
    };
    items.push(item);
  }
  return items;
}

export function setRemoteVideos(items: VideoItem[]): void {
  REMOTE_LIST = items;
}

// 当前可展示的视频列表：优先使用后端数据
export function videoList(): VideoItem[] {
  return REMOTE_LIST.length > 0 ? REMOTE_LIST : VIDEO_LIST;
}

// 按 id 查找视频，未找到返回 undefined
export function findVideo(id: string): VideoItem | undefined {
  for (let i = 0; i < REMOTE_LIST.length; i++) {
    if (REMOTE_LIST[i].id === id) {
      return REMOTE_LIST[i];
    }
  }
  for (let i = 0; i < VIDEO_LIST.length; i++) {
    if (VIDEO_LIST[i].id === id) {
      return VIDEO_LIST[i];
    }
  }
  return undefined;
}
