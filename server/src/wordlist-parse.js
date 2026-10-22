/**
 * 词表解析：
 * - .txt：每行 `word` 或 `word [phonetic] 中文释义`（mahavivo CET4/CET6 格式）
 * - .json：{ words: [...] } 或直接数组，字段兼容 App 的 Word
 */

const WORD_RE = /^([A-Za-z][A-Za-z'’\-]*(?:\s+[A-Za-z][A-Za-z'’\-]*){0,2})\s*(?:\[([^\]]*)\])?\s*(.*)$/;

function clean(value, max = 500) {
  return typeof value === 'string' ? value.trim().slice(0, max) : '';
}

function normalizeJsonWords(list, bookId) {
  const words = [];
  const seen = new Set();
  if (!Array.isArray(list)) {
    return words;
  }
  for (const item of list) {
    if (!item || typeof item !== 'object') {
      continue;
    }
    const word = clean(item.word, 80);
    const key = word.toLowerCase();
    if (!word || seen.has(key)) {
      continue;
    }
    seen.add(key);
    words.push({
      id: clean(item.id, 80) || `${bookId}-w${String(words.length + 1).padStart(4, '0')}`,
      word,
      phonetic: clean(item.phonetic, 120),
      meaning: clean(item.meaning || item.translation, 1000),
      example: clean(item.example, 1000),
      exampleCn: clean(item.exampleCn, 1000)
    });
  }
  return words;
}

export function parseWordList(text, bookId = 'book') {
  const raw = String(text || '').replace(/^\uFEFF/, '').trim();
  if (!raw) {
    return [];
  }

  if (raw.startsWith('[') || raw.startsWith('{')) {
    try {
      const parsed = JSON.parse(raw);
      const list = Array.isArray(parsed) ? parsed : parsed.words;
      return normalizeJsonWords(list, bookId);
    } catch {
      // 交给下面的纯文本解析
    }
  }

  const words = [];
  const seen = new Set();
  const lines = raw.split(/\r?\n/);
  for (const line of lines) {
    const value = line.replace(/\u00a0/g, ' ').trim();
    if (!value || value.startsWith('#')) {
      continue;
    }
    // 跳过标题、统计行、章节字母
    if (/^[A-Z]$/.test(value) || /大学英语|共\s*\d+\s*词|^\(/.test(value)) {
      continue;
    }
    let word = '';
    let phonetic = '';
    let meaning = '';
    if (value.includes('\t')) {
      const parts = value.split('\t');
      word = parts.shift() || '';
      meaning = parts.join(' ').trim();
    } else {
      const match = WORD_RE.exec(value);
      if (!match) {
        continue;
      }
      word = match[1].trim();
      phonetic = match[2] || '';
      meaning = match[3] || '';
    }

    // `a art` / `access v` 这种词性紧跟在词后的格式，把词性挪到释义里
    const posMatch = /^(.*?)\s+(art|n|v|vt|vi|a|ad|adj|adv|prep|pron|conj|num|int|aux|modal|pl)$/i.exec(word);
    if (posMatch) {
      word = posMatch[1].trim();
      meaning = `${posMatch[2]} ${meaning}`.trim();
    }
    const key = word.toLowerCase();
    if (!word || word.length > 80 || seen.has(key)) {
      continue;
    }
    seen.add(key);
    words.push({
      id: `${bookId}-w${String(words.length + 1).padStart(4, '0')}`,
      word,
      phonetic: clean(phonetic, 120),
      meaning: clean(meaning, 1000),
      example: '',
      exampleCn: ''
    });
  }
  return words;
}

/** 用带释义的词表补齐另一个词表中缺失的释义/音标 */
export function enrichWords(words, dictionaries) {
  const map = new Map();
  for (const dict of dictionaries) {
    for (const item of dict) {
      const key = item.word.toLowerCase();
      if (!map.has(key) || (map.get(key).meaning === '' && item.meaning !== '')) {
        map.set(key, item);
      }
    }
  }
  for (const item of words) {
    const found = map.get(item.word.toLowerCase());
    if (!found) {
      continue;
    }
    if (!item.phonetic) {
      item.phonetic = found.phonetic;
    }
    if (!item.meaning) {
      item.meaning = found.meaning;
    }
  }
  return words;
}
