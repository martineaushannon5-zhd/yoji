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
    title: '【TED演讲】如何解决焦虑',
    date: today(),
    thumb: $r('app.media.video_thumb_anxiety'),
    src: $rawfile('anxiety.mp4')
  },
  {
    id: 'casey-sloppy',
    title: '【Casey Neistat】拖延是创造力的毒药',
    date: today(),
    thumb: $r('app.media.video_thumb_sloppy'),
    src: $rawfile('sloppy.mp4')
  },
  {
    id: 'graduation-speech',
    title: '【哥伦比亚大学】2025年毕业典礼优秀毕业生杨安泽演讲',
    date: today(),
    thumb: $r('app.media.video_thumb_graduation'),
    src: $rawfile('graduation.mp4')
  },
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
