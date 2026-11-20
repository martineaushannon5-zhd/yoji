import fs from 'node:fs';
import path from 'node:path';

import { saveWordBook } from '../src/db.js';
import { parseWordList } from '../src/wordlist-parse.js';

const dir = path.resolve(process.argv[2] || 'wordlists');

if (!fs.existsSync(dir)) {
  console.error(`目录不存在：${dir}`);
  process.exit(1);
}

const files = fs.readdirSync(dir).filter((name) => name.endsWith('.json'));
if (files.length === 0) {
  console.error(`目录里没有 .json：${dir}`);
  process.exit(1);
}

for (const name of files) {
  const file = path.join(dir, name);
  const raw = fs.readFileSync(file, 'utf8');
  let meta;
  try {
    meta = JSON.parse(raw);
  } catch (error) {
    console.error(`跳过 ${name}：JSON 解析失败 (${error.message})`);
    continue;
  }
  const id = String(meta.id || path.basename(name, '.json')).trim();
  const words = parseWordList(raw, id);
  if (words.length === 0) {
    console.error(`跳过 ${name}：没有解析到单词`);
    continue;
  }
  saveWordBook({
    id,
    name: meta.name || id,
    subtitle: meta.subtitle || `${words.length} 词`,
    description: meta.description || '',
    source: meta.source || name,
    sortOrder: meta.sortOrder,
    words
  });
  console.log(`${id}: ${words.length} 词已写入`);
}