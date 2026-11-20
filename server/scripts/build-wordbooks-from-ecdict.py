#!/usr/bin/env python3
"""从 ECDICT（MIT License）生成 Yoji 词库 JSON。

用法：
    python build-wordbooks-from-ecdict.py <ecdict.csv> <输出目录>

生成 ielts / gmat / sat / oxford3000 四本，字段与 server/src/wordlist-parse.js
的 JSON 分支一致（word / phonetic / meaning）。
"""
import csv
import json
import os
import re
import sys

WORD_RE = re.compile(r"^[A-Za-z][A-Za-z' -]{0,39}$")

BOOKS = [
    # (输出 id, 标签, 名称, 副标题, 描述, 排序)
    ("ielts", "ielts", "雅思 IELTS 词汇", "雅思考试核心词", "雅思（IELTS）常考词汇，来自 ECDICT 考试标签，含音标与中文释义。", 8),
    ("gmat", "gmat", "GMAT 词汇", "GMAT 考试核心词", "GMAT 常考词汇，来自 ECDICT 考试标签，含音标与中文释义。", 9),
    ("sat", "sat", "SAT 词汇", "SAT 考试核心词", "SAT 常考词汇，来自 ECDICT 考试标签，含音标与中文释义。", 10),
    ("oxford3000", "oxford", "牛津 3000 核心词", "Oxford 3000", "牛津 3000 核心词汇（ECDICT oxford 标记），适合作为通用高频词库。", 11),
]


def clean_meaning(text: str) -> str:
    lines = [line.strip() for line in (text or "").replace("\r", "").split("\n")]
    lines = [line for line in lines if line]
    return "；".join(lines)[:1000]


def main() -> int:
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    src, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)

    headers = {
        "ielts": [],
        "gmat": [],
        "sat": [],
        "oxford": [],
    }
    seen = {key: set() for key in headers}

    with open(src, "r", encoding="utf-8", newline="") as fh:
        reader = csv.DictReader(fh)
        for row in reader:
            word = (row.get("word") or "").strip()
            if not word or not WORD_RE.match(word):
                continue
            meaning = clean_meaning(row.get("translation"))
            if not meaning:
                continue
            phonetic = (row.get("phonetic") or "").strip()[:120]
            tags = (row.get("tag") or "").split()
            oxford = (row.get("oxford") or "").strip() == "1"
            frq = int(row.get("frq") or 0) if (row.get("frq") or "").isdigit() else 0

            def add(key: str) -> None:
                lower = word.lower()
                if lower in seen[key]:
                    return
                seen[key].add(lower)
                headers[key].append({
                    "word": word,
                    "phonetic": phonetic,
                    "meaning": meaning,
                    "_frq": frq if frq > 0 else 999999,
                })

            for tag in ("ielts", "gmat", "sat"):
                if tag in tags:
                    add(tag)
            if oxford:
                add("oxford")

    for book_id, tag, name, subtitle, description, sort_order in BOOKS:
        words = sorted(headers[tag], key=lambda item: (item["_frq"], item["word"].lower()))
        for index, item in enumerate(words, start=1):
            item.pop("_frq", None)
            item["id"] = f"{book_id}-w{index:04d}"
        payload = {
            "id": book_id,
            "name": name,
            "subtitle": f"{len(words)} 词 · {subtitle}",
            "description": description,
            "source": "ECDICT (MIT) · https://github.com/skywind3000/ECDICT",
            "sortOrder": sort_order,
            "words": words,
        }
        path = os.path.join(out_dir, f"{book_id}.json")
        with open(path, "w", encoding="utf-8") as fh:
            json.dump(payload, fh, ensure_ascii=False, indent=0)
        print(f"{book_id}: {len(words)} words -> {path} ({os.path.getsize(path)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())