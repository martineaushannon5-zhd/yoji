# 词库与词典 API 选型

当前 App 的 `WordData.ets` 只有约 60 个四级核心词，继续扩展建议不要手工维护，直接用现成词库 + 导入脚本。

> **2026-10-22 已导入后台词表：**
>
> - `CET-4 四级词汇`：4538 词
> - `CET-6 六级词汇`：2220 词
> - `CET-4+6 四六级合并`：8013 词（其中 1843 个词在源词表/补充词典中没有释义，App 仍可显示单词）
>
> 后台地址：<http://120.24.171.99/wordbooks/> 或 <https://yoji.zhdstudy.cyou/wordbooks/>。App 启动时请求 `/api/wordbooks/full` 获取启用的词表。

## 一、首选：ECDICT（开源、可离线、MIT）

- 项目：<https://github.com/skywind3000/ECDICT>
- 许可证：MIT（可商用、可修改，保留版权声明）
- 规模：约 77 万词条
- 字段：`word`、`phonetic`、`definition`、`translation`、`pos`、`collins`、`oxford`、`tag`、`bnc`、`frq`、`exchange`、`detail`、`audio`
- `tag` 里直接带 `cet4`、`cet6`、`ky`（考研）、`ielts`、`toefl`、`gre` 标签，适合按考试筛词。

**推荐做法：把 ECDICT 的 CSV/SQLite 放到服务器，按考试标签导出 JSON，再导入 App 词库。**

```sql
-- 示例：四级词
SELECT word, phonetic, translation, definition, exchange
FROM stardict
WHERE tag LIKE '%cet4%'
ORDER BY bnc ASC;
```

导入 App 时映射：

| App `Word` 字段 | ECDICT |
| --- | --- |
| `word` | `word` |
| `phonetic` | `/` + `phonetic` + `/` |
| `meaning` | `translation`（中文释义） |
| `example` | 可用 `definition` 或另外生成 |
| `exampleCn` | 可空，或用 LLM/例句库补 |
| `videoId` | 可空；后续按视频主题关联 |

> 注意：ECDICT 的 `definition` 是英文释义，`translation` 才是中文；App 里不要混用。

## 二、考试词表（只取范围，不取释义）

- `mahavivo/english-wordlists`：<https://github.com/mahavivo/english-wordlists>
  - CET4、CET4+6、TOEFL、GRE、COCA 20000 等；
  - 适合确定“考纲范围”，释义建议仍用 ECDICT；
  - 使用前看仓库说明和原始考纲来源。
- `KyleBing/english-vocabulary`：<https://github.com/KyleBing/english-vocabulary>
  - 带中文释义的常用词表，适合快速做 Demo；
  - 使用前确认仓库许可证。

## 三、在线词典 / 翻译 API

| 平台 | 能力 | 费用 | 适合 |
| --- | --- | --- | --- |
| [有道智云词典 API](https://ai.youdao.com/DOCSIRMA/html/dictionary/api/ydcd/index.html) | 中英释义、音标、例句、发音 | 按量付费/有免费额度 | 想要权威中文释义和发音 |
| [百度翻译开放平台](https://fanyi-api.baidu.com/) | 文本翻译 | 免费额度 + 按量 | 批量翻译例句/释义 |
| [腾讯云机器翻译](https://cloud.tencent.com/product/tmt) | 文本翻译 | 按量 | 已有腾讯云账号 |
| [Oxford Dictionaries API](https://developer.oxforddictionaries.com/) | 英文释义、例句 | 付费 | 英文词典质量要求高 |
| [Merriam-Webster API](https://dictionaryapi.com/) | 英文释义、发音 | 免费 key（限用途） | 英文释义/发音 |
| [Free Dictionary API](https://dictionaryapi.dev/) | 英文释义、例句、音标 | 免费 | 英文例句补充，无中文 |

**建议组合：**

1. **中文释义 + 音标**：ECDICT 离线导入，零请求成本；
2. **英文例句/发音**：Free Dictionary API 或 Merriam-Webster；
3. **需要商业级中文词典/发音**：有道智云；
4. 不建议爬取盗版词典网站，许可证和稳定性都有风险。

## 四、落地步骤

1. 下载 ECDICT 的 `ecdict.csv`（或 `stardict.csv`）；
2. 用 `tag` 过滤出 `cet4`、`cet6`、`ielts`，分别生成 `cet4.json`、`cet6.json`、`ielts.json`；
3. 每个词转成 App 的 `Word` 结构，保留 `word/phonetic/meaning`；
4. 把 JSON 放到 `entry/src/main/resources/rawfile/words/`，启动时读取；
5. 在 `WordData.ets` 注册新词库，替换现在硬编码的 60 词；
6. 在“关于”页加 ECDICT MIT 版权声明。

> 如果希望我直接做第 2–5 步，需要先把 ECDICT 的 CSV（或允许服务器下载）放到仓库/服务器；我可以写导入脚本并生成三个词库 JSON。
