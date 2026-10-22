import fs from 'node:fs';
import path from 'node:path';

import { db, saveWordBook } from '../src/db.js';
import { enrichWords, parseWordList } from '../src/wordlist-parse.js';

const dir = path.resolve(process.argv[2] || '/tmp/wordlists');

function readIfExists(name) {
  const file = path.join(dir, name);
  return fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
}

const cet4Text = readIfExists('CET4_edited.txt');
const cet6Text = readIfExists('CET6_edited.txt');
const cet46Text = readIfExists('CET_4+6_edited.txt');
if (!cet4Text || !cet6Text) {
  console.error(`找不到词表文件，请确认目录：${dir}`);
  process.exit(1);
}

const cet4 = parseWordList(cet4Text, 'cet4');
const cet6 = parseWordList(cet6Text, 'cet6');
const cet46 = cet46Text ? parseWordList(cet46Text, 'cet4-6') : [];
const kyle4 = parseWordList(readIfExists('cet4_kyle.txt'), 'kyle4');
const kyle6 = parseWordList(readIfExists('cet6_kyle.txt'), 'kyle6');
if (cet46.length > 0) {
  enrichWords(cet46, [cet4, cet6, kyle4, kyle6]);
}

const books = [
  {
    id: 'cet4',
    name: 'CET-4 四级词汇',
    subtitle: `${cet4.length} 词 · 四级大纲`,
    description: '大学英语四级词汇表，含音标与中文释义。',
    source: 'CET4_edited.txt',
    words: cet4,
    sortOrder: 1
  },
  {
    id: 'cet6',
    name: 'CET-6 六级词汇',
    subtitle: `${cet6.length} 词 · 六级大纲`,
    description: '大学英语六级词汇表，含音标与中文释义。',
    source: 'CET6_edited.txt',
    words: cet6,
    sortOrder: 2
  }
];

if (cet46.length > 0) {
  books.push({
    id: 'cet4-6',
    name: 'CET-4+6 四六级合并',
    subtitle: `${cet46.length} 词 · 四级 + 六级`,
    description: '四级与六级合并词表；能匹配到的词已补充释义。',
    source: 'CET_4+6_edited.txt',
    words: cet46,
    sortOrder: 3
  });
}

for (const book of books) {
  const saved = saveWordBook({ ...book, visible: true });
  const empty = saved.words.filter((word) => !word.meaning).length;
  console.log(`${saved.id}: ${saved.wordCount} 词，无释义 ${empty} 个`);
}
db.close();
