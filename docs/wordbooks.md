# 词表功能说明（2026-10-22）

## 已上线词表

后台 `/wordbooks/` 当前有：

| 词表 | 词数 | 来源 |
| --- | --- | --- |
| CET-4 四级词汇 | 4538 | `CET4_edited.txt` |
| CET-6 六级词汇 | 2220 | `CET6_edited.txt` |
| CET-4+6 四六级合并 | 8013 | `CET_4+6_edited.txt` |

`CET-4+6` 中约 1843 个词在源文件及补充词典中没有中文释义，App 仍会显示单词，释义为空；后续可上传带释义的 JSON 覆盖。

## App 如何拿到词表

1. 启动页 `SplashPage` 初始化 Store 后请求 `GET /api/wordbooks/full`；
2. 成功后替换内置 `BOOKS` / `SELECTABLE_BOOKS`；
3. 失败则保留 App 内置 60 词兜底，不影响使用；
4. 词库选择页直接显示后台启用的词表。

## 后台上传格式

支持：

```text
# .txt：每行一个词
abandon
ability
```

或：

```text
abandon [əˈbændən] v. 放弃
ability [əˈbɪləti] n. 能力
```

或 `.json`：

```json
{
  "words": [
    { "word": "abandon", "phonetic": "/əˈbændən/", "meaning": "v. 放弃" }
  ]
}
```

上传后 App 需要**重启**（或重新进入启动页）才会拉取新词表。

## 后台接口

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/api/admin/wordbooks` | 当前词表列表 |
| POST | `/api/admin/wordbooks/upload` | 上传 .txt/.json |
| GET | `/api/admin/wordbooks/:id` | 预览词表 |
| PATCH | `/api/admin/wordbooks/:id` | 显示/隐藏/改名 |
| DELETE | `/api/admin/wordbooks/:id` | 删除 |
| GET | `/api/wordbooks/full` | App 拉取全部启用词表 |

## 数据来源

- 词表：[mahavivo/english-wordlists](https://github.com/mahavivo/english-wordlists)
- 补充释义：[KyleBing/english-vocabulary](https://github.com/KyleBing/english-vocabulary)
- 更多选型见 [wordlists.md](wordlists.md)
