import { db, seedVideosIfEmpty } from '../src/db.js';

const count = seedVideosIfEmpty();
if (count === 0) {
  console.log('videos 表已有数据，跳过演示数据写入');
} else {
  console.log(`已写入 ${count} 条演示视频`);
}
db.close();
