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
if (!cet4Text || !cet6Text) {
  console.error(`找不到 CET4_edited.txt / CET6_edited.txt，请确认目录：${dir}`);
  process.exit(1);
}

const cet4 = parseWordList(cet4Text, 'cet4');
const cet6 = parseWordList(cet6Text, 'cet6');
const cet46 = parseWordList(readIfExists('CET_4+6_edited.txt'), 'cet4-6');
const high = parseWordList(readIfExists('Highschool_edited.txt'), 'highschool');
const npee = parseWordList(readIfExists('NPEE_Wordlist.txt'), 'npee');
const toefl = parseWordList(readIfExists('TOEFL.txt'), 'toefl');
const gre = parseWordList(readIfExists('GRE_8000_Words.txt'), 'gre');
const kyle4 = parseWordList(readIfExists('cet4_kyle.txt'), 'kyle4');
const kyle6 = parseWordList(readIfExists('cet6_kyle.txt'), 'kyle6');
const oald = parseWordList(readIfExists('OALD8_abridged_edited.txt'), 'oald');

const dictionaries = [cet4, cet6, npee, toefl, gre, oald, kyle4, kyle6];
if (cet46.length > 0) {
  enrichWords(cet46, dictionaries);
}
if (high.length > 0) {
  enrichWords(high, dictionaries);
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

function addBook(id, name, subtitle, description, source, words, sortOrder) {
  if (words.length === 0) {
    return;
  }
  books.push({ id, name, subtitle, description, source, words, sortOrder });
}

addBook(
  'cet4-6',
  'CET-4+6 四六级合并',
  `${cet46.length} 词 · 四级 + 六级`,
  '四级与六级合并词表；已用考研/托福/GRE/OALD 补充能匹配到的释义。',
  'CET_4+6_edited.txt',
  cet46,
  3
);
addBook(
  'highschool',
  '高中英语词汇',
  `${high.length} 词 · 高中基础`,
  '高中英语常用词汇，适合作为四六级前的过渡词库。',
  'Highschool_edited.txt',
  high,
  4
);
addBook(
  'npee',
  '考研英语词汇',
  `${npee.length} 词 · 考研大纲`,
  '考研英语大纲词汇，含音标与中文释义。',
  'NPEE_Wordlist.txt',
  npee,
  5
);
addBook(
  'toefl',
  'TOEFL 托福词汇',
  `${toefl.length} 词 · 托福`,
  'TOEFL 托福词汇，含音标与中文释义。',
  'TOEFL.txt',
  toefl,
  6
);
addBook(
  'gre',
  'GRE 8000 词汇',
  `${gre.length} 词 · GRE`,
  'GRE 常考词汇，含音标与中文释义。',
  'GRE_8000_Words.txt',
  gre,
  7
);

for (const book of books) {
  const saved = saveWordBook({ ...book, visible: true });
  const empty = saved.words.filter((word) => !word.meaning).length;
  console.log(`${saved.id}: ${saved.wordCount} 词，无释义 ${empty} 个`);
}
db.close();
