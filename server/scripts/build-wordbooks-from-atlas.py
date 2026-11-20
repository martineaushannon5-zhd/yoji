#!/usr/bin/env python3
"""从开源数据构建 Yoji 词库 JSON。

数据来源：
- word-atlas（https://github.com/designfuchen/word-atlas，数据集 CC BY 4.0）
  data/word-atlas.csv：雅思核心词，含 CEFR、英/美音标、中文释义、双语例句。
- collins-vocabulary（https://github.com/cd155/collins-vocabulary，MIT）
  lists/collins.json：柯林斯 1-5 星词，含音标、中文释义。

输出：<out>/ielts.json、<out>/collins5.json，格式与 server/src/wordlist-parse.js 的
JSON 分支一致（{id,name,subtitle,description,source,sortOrder,words:[...]}）。

用法：
  python scripts/build-wordbooks-from-atlas.py \
    --atlas /tmp/wl2/word-atlas.csv \
    --collins /tmp/wl2/collins.json \
    --out /tmp/wl2/out
"""

import argparse
import csv
import json
import os
import re

MAX_MEANING = 1000


def clean(text, max_len=MAX_MEANING):
    value = re.sub(r"\s+", " ", str(text or "")).strip()
    return value[:max_len]


def atlas_meaning(row):
    raw = row.get("meanings_zh") or ""
    parts = [p.strip() for p in raw.split("|") if p.strip()]
    return clean("；".join(parts))


def build_ielts(csv_path):
    words = []
    seen = set()
    with open(csv_path, encoding="utf-8-sig", newline="") as fh:
        for row in csv.DictReader(fh):
            word = clean(row.get("word"), 80)
            key = word.lower()
            if not word or key in seen:
                continue
            meaning = atlas_meaning(row)
            if not meaning:
                continue
            seen.add(key)
            words.append(
                {
                    "id": f"ielts-w{len(words) + 1:04d}",
                    "word": word,
                    "phonetic": clean(row.get("ipa_uk") or row.get("ipa_us"), 120),
                    "meaning": meaning,
                    "example": clean(row.get("example1_en")),
                    "exampleCn": clean(row.get("example1_zh")),
                }
            )
    return {
        "id": "ielts",
        "name": "IELTS 雅思词汇",
        "subtitle": f"{len(words)} 词 · 雅思核心 · 含例句",
        "description": "雅思备考核心词，覆盖 CEFR A1–C2，含英式音标、中文释义与双语例句。数据来源：word-atlas（CC BY 4.0）。",
        "source": "word-atlas (CC BY 4.0)",
        "sortOrder": 8,
        "words": words,
    }


def build_collins5(json_path):
    with open(json_path, encoding="utf-8") as fh:
        rows = json.load(fh)
    words = []
    seen = set()
    for row in rows:
        if int(row.get("stars") or 0) != 5:
            continue
        word = clean(row.get("word"), 80)
        key = word.lower()
        if not word or key in seen:
            continue
        meaning = clean(row.get("translation"))
        if not meaning:
            continue
        seen.add(key)
        words.append(
            {
                "id": f"collins5-w{len(words) + 1:04d}",
                "word": word,
                "phonetic": clean(row.get("phonetic"), 120),
                "meaning": meaning,
                "example": "",
                "exampleCn": "",
            }
        )
    return {
        "id": "collins5",
        "name": "柯林斯五星核心词",
        "subtitle": f"{len(words)} 词 · Collins 5 星",
        "description": "柯林斯词典 5 星高频词，适合考前快速过核心词。数据来源：collins-vocabulary（MIT）。",
        "source": "collins-vocabulary (MIT)",
        "sortOrder": 9,
        "words": words,
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--atlas", required=True, help="word-atlas.csv 路径")
    parser.add_argument("--collins", required=True, help="collins.json 路径")
    parser.add_argument("--out", required=True, help="输出目录")
    args = parser.parse_args()

    os.makedirs(args.out, exist_ok=True)
    books = [build_ielts(args.atlas), build_collins5(args.collins)]
    for book in books:
        path = os.path.join(args.out, f"{book['id']}.json")
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(book, fh, ensure_ascii=False, separators=(",", ":"))
        size = os.path.getsize(path)
        print(f"{book['id']}: {len(book['words'])} 词, {size / 1024:.0f} KB -> {path}")


if __name__ == "__main__":
    main()