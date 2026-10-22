import { db } from '../src/db.js';
import { syncMedia } from '../src/media-sync.js';

const result = syncMedia();
console.log(`媒体扫描完成：新增 ${result.created} 个，更新 ${result.updated} 个，共 ${result.total} 个视频`);
for (const video of result.videos) {
  console.log(`- ${video.id}  ${video.title}  ${video.videoUrl}`);
}
db.close();
