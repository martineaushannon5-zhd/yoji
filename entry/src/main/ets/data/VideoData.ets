import { VideoItem } from '../model/VideoModel';

// 生成今天日期标签（如 "2026-10-16"）：视频上传日期以今天为主
function today(): string {
  const d = new Date();
  return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
}

// 视频列表数据：缩略图位于 media，视频文件位于 rawfile
export const VIDEO_LIST: VideoItem[] = [
  {
    id: 'ted-anxiety',
    title: '【TED演讲】如何解决焦虑 - 1.中英字幕',
    date: today(),
    thumb: $r('app.media.video_thumb_anxiety'),
    src: $rawfile('anxiety.mp4')
  }
];

// 按 id 查找视频，未找到返回 undefined
export function findVideo(id: string): VideoItem | undefined {
  for (let i = 0; i < VIDEO_LIST.length; i++) {
    if (VIDEO_LIST[i].id === id) {
      return VIDEO_LIST[i];
    }
  }
  return undefined;
}
