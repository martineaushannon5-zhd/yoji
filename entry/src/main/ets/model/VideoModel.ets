// 视频条目模型：id、标题、上传日期、缩略图与视频资源
export interface VideoItem {
  id: string;
  title: string;
  date: string;
  thumb: Resource;
  src: Resource;
}
