# Yoji 接口模块与故障排除手册

> 适用版本：`integration/v1.2.0-backend`（2026-10-22 线上）
>
> 在线地址：
> - API：`http://120.24.171.99`（备案期）
> - API/后台：`https://yoji.zhdstudy.cyou`（域名备案完成后正式使用）
> - 后台：`http://120.24.171.99/`、`https://yoji.zhdstudy.cyou/`

---

## 一、整体结构

```text
HarmonyOS App
   │  HTTP/HTTPS
   ▼
Nginx (80/443)
   ├─ /           → /www/wwwroot/yoji-admin  静态后台
   ├─ /api/       → 127.0.0.1:3000           Node API
   ├─ /media/     → /www/wwwroot/yoji/server/media
   └─ /healthz    → 127.0.0.1:3000

Node（PM2: yoji_project，目录 /www/wwwroot/yoji/server）
   ├─ SQLite：data/yoji.db
   ├─ 视频：media/videos
   ├─ 封面：media/thumbs
   └─ 头像：media/avatars
```

### 鉴权矩阵

| 身份 | 凭证 | 可访问 |
| --- | --- | --- |
| 普通用户 | `Authorization: Bearer <用户 JWT>` | `/api/auth/me`、`/api/progress` |
| 管理后台 | `Authorization: Bearer <admin JWT>` | `/api/admin/stats`、`users`、`videos`、`wordbooks` |
| 运维脚本 | `X-Admin-Token: <ADMIN_TOKEN>` | `/api/admin/ping`、`/api/admin/videos*` |
| 公开 | 无 | `/healthz`、`/api/videos`、`/api/wordbooks*`、`/media/*` |

用户 JWT 与管理员 JWT 都使用 HS256，但管理员 JWT 带 `role=admin`，普通用户 token 不能访问后台接口。

---

## 二、接口模块

### 1. 健康检查与静态媒体

| 方法 | 路径 | 作用 |
| --- | --- | --- |
| GET | `/healthz` | 存活检查，返回 uptime/time |
| GET | `/media/videos/*` | 视频文件，支持 Range 拖动 |
| GET | `/media/thumbs/*` | 视频封面 |
| GET | `/media/avatars/*` | 用户头像 |

**作用**：确认 Node 是否活着；视频/封面/头像由 Nginx 直接静态返回，不占 Node。

---

### 2. 账号模块 `/api/auth`

| 方法 | 路径 | 作用 | 关键点 |
| --- | --- | --- | --- |
| POST | `/register` | 注册 | 账号 3–64 位；密码 6–72 位；注册限流 10 次/小时 |
| POST | `/login` | 登录 | 返回 `token`、`userId`、`nickname`、`avatar` |
| GET | `/me` | 当前用户资料 | 需要 Bearer |
| PATCH | `/me` | 改昵称/头像地址 | 头像可为 `/media/...` 或 http(s) |
| POST | `/avatar` | 上传头像原始字节 | JPG/PNG/WebP，≤2MB，写 `media/avatars/` |
| POST | `/logout` | 退出登录 | `token_version + 1`，旧 token 立即失效 |

**头像上传**：

```http
POST /api/auth/avatar
Authorization: Bearer <用户 JWT>
Content-Type: application/octet-stream

<图片二进制>
```

返回：

```json
{ "code": 0, "data": { "avatar": "/media/avatars/<userId>.jpg?v=..." } }
```

---

### 3. 学习进度 `/api/progress`

| 方法 | 路径 | 作用 |
| --- | --- | --- |
| GET | `/` | 拉取当前用户云端进度和 `version` |
| POST | `/sync` | 本地/云端**并集合并**（App 日常使用） |
| PUT | `/` | 覆盖写入；默认乐观锁，`force: true` 强制覆盖 |

进度快照包含：

- `statusMap`：单词学习状态 `0未学/1学习中/2已掌握`
- `learnedLog`：每日学习记录
- `favorites`：单词本收藏
- `favoriteVideos`：喜欢的视频
- `customWords`：视频里自填单词
- `currentBookId`、`dailyTarget`、`streak`、`todayLearned`
- `gender`、`birthday`、`nickname`

**作用**：多设备不互相覆盖；`sync` 用并集，`PUT` 用于“清空记录”这类必须覆盖的场景。

---

### 4. 视频公开接口 `/api/videos`

| 方法 | 路径 | 作用 |
| --- | --- | --- |
| GET | `/` | App 视频列表，仅返回 `visible=1` |
| GET | `/:id` | 单个视频 |

返回 `videoUrl` / `thumbUrl`，App 用 `Api.resolveMediaUrl` 拼上服务器域名。

---

### 5. 词表公开接口 `/api/wordbooks`

| 方法 | 路径 | 作用 |
| --- | --- | --- |
| GET | `/` | 启用词表摘要（App 词库选择页） |
| GET | `/full` | 启用词表 + 全部单词（App 启动时一次拉取） |
| GET | `/:id` | 单个词表完整内容 |

当前词表：

| id | 名称 | 词数 |
| --- | --- | --- |
| `cet4` | CET-4 四级词汇 | 4538 |
| `cet6` | CET-6 六级词汇 | 2220 |
| `cet4-6` | CET-4+6 四六级合并 | 8013 |

`/api/wordbooks/full` 约 1.9MB；App 启动时拉取，失败保留内置 60 词。

---

### 6. 管理后台登录 `/api/admin/login`

| 方法 | 路径 | 作用 |
| --- | --- | --- |
| POST | `/api/admin/login` | 管理员账号密码换 admin JWT |

支持两类账号：

- 超级管理员：`admin` / 服务器 `.env` 的 `ADMIN_TOKEN`
- 测试管理员：`hans / 123456`、`zhd / 123456`（admins 表，全部权限）

JWT 默认 12 小时；登录限流 20 次/15 分钟。

---

### 7. 后台统计与用户 `/api/admin`

| 方法 | 路径 | 作用 |
| --- | --- | --- |
| GET | `/stats` | 总用户、今日活跃、累计掌握、14 天趋势 |
| GET | `/users` | 用户列表，支持 `search/page/pageSize` |
| DELETE | `/users/:id` | 删除用户及其进度（级联） |

`/stats` 返回：

- `totalUsers`
- `todayActive`
- `totalWords` / `masteredWords`
- `totalVideos`
- `newUsers7d`
- `trend[]`（`date/label/newUsers/activeUsers`）

---

### 8. 后台视频 `/api/admin/videos`

鉴权：管理员 JWT 或 `X-Admin-Token` 均可。

| 方法 | 路径 | 作用 |
| --- | --- | --- |
| GET | `/videos` | 全部视频（含隐藏） |
| POST | `/videos/upload` | multipart 上传视频 + 封面并建记录 |
| POST | `/videos/scan` | 扫描 `media/videos` 自动登记新视频 |
| POST | `/videos` | JSON 手动新增视频链接 |
| PATCH | `/videos/:id` | 修改标题/日期/排序/显示状态 |
| DELETE | `/videos/:id` | 删除视频记录（不删源文件） |
| GET | `/ping` | 验证运维 token |

上传表单字段：

```text
video   视频文件（mp4/webm/m4v，≤900MB）
cover   封面（png/jpg/webp，≤5MB，可选）
title   标题
description  简介
date    YYYY-MM-DD
sortOrder  排序
visible  true/false
```

---

### 9. 后台词表 `/api/admin/wordbooks`

鉴权：管理员 JWT。

| 方法 | 路径 | 作用 |
| --- | --- | --- |
| GET | `/` | 全部词表（含隐藏） |
| GET | `/:id` | 词表完整内容（预览） |
| POST | `/upload` | multipart 上传 `.txt` / `.json` |
| PATCH | `/:id` | 名称/副标题/显示状态/排序 |
| DELETE | `/:id` | 删除词表 |

支持格式：

```text
# .txt 一行一个词
abandon
ability
```

```text
# .txt 带音标/释义
abandon [əˈbændən] v. 放弃
ability [əˈbɪləti] n. 能力
```

```json
{
  "words": [
    { "word": "abandon", "phonetic": "/əˈbændən/", "meaning": "v. 放弃" }
  ]
}
```

> 不支持 `.zip`、`.xlsx`、`.pdf`。从 zip 里解压后，只上传里面的 `.txt` / `.json`。

---

## 三、统一响应与错误码

所有 JSON 接口：

```json
{ "code": 0, "message": "ok", "data": {} }
```

| code | 含义 | 常见处理 |
| --- | --- | --- |
| 0 | 成功 | — |
| 1000 | 参数错误 | 检查字段/格式 |
| 1001 | 未登录/token 无效 | 重新登录 |
| 1002 | 账号或密码错误 | 检查账号密码 |
| 1003 | 账号已存在 | 换账号 |
| 1005 | token 过期 | 重新登录 |
| 1006 | 无权限 | 检查管理员 JWT |
| 1007 | 资源不存在 | 检查 id/路径 |
| 1008 | 版本冲突 | 先 GET 最新 version，再同步 |
| 1009 | 请求过于频繁 | 等限流窗口结束 |
| 1500 | 服务器内部错误 | 看 PM2/Nginx 日志 |

---

## 四、故障排除

### 0. 通用排查顺序

```text
1. 浏览器/App 拿到 HTTP 状态码和响应 message
2. curl /healthz
3. PM2 是否 online
4. PM2/Nginx 日志
5. Nginx /api 代理是否指向 3000
6. 数据库/媒体目录权限
```

服务器命令：

```bash
export PATH=/www/server/nodejs/v24.22.0/bin:$PATH

pm2 status
pm2 logs yoji_project --lines 100 --nostream
curl http://127.0.0.1:3000/healthz

/www/server/nginx/sbin/nginx -t
tail -100 /www/wwwlogs/yoji_project.error.log
```

---

### 1. 网站 502 / 504

- `pm2 status` 不是 `online`：`pm2 restart yoji_project`
- `/healthz` 不通：看 `pm2 logs` 启动报错
- 常见启动报错：
  - `生产环境必须设置 JWT_SECRET...` → `/www/wwwroot/yoji/server/.env` 缺失或太短
  - SQLite 权限 → `chown -R www:www data`
- Nginx 502：`/api/` 是否代理到 `127.0.0.1:3000`
- 504：上传大视频时看 `proxy_read_timeout`、`client_max_body_size`

---

### 2. 接口 404

- `/api/xxx` 返回 `接口不存在`：Node 路由没有这个接口，检查部署版本；
- `/` 返回 JSON 404：Nginx 根路径还在代理 Node，应该指向 `/www/wwwroot/yoji-admin`；
- 只更新了前端、没重启/上传后端：用 `yoji-server-update.zip` 覆盖并重启。

---

### 3. 管理员登录失败

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| 401 账号或密码错误 | 密码不对 | `admin` 用 `.env` 的 `ADMIN_TOKEN`；测试账号 `hans/123456`、`zhd/123456` |
| 401 管理登录已过期 | JWT 12h | 重新登录 |
| 429 | 15 分钟超过 20 次 | 等窗口结束或换 IP |
| 登录成功但接口 401 | localStorage token 过期/被清 | 退出重登，清 `yoji_admin_token` |

```bash
grep '^ADMIN_TOKEN=' /www/wwwroot/yoji/server/.env
```

---

### 4. 用户登录后进度/收藏丢失

先确认后端版本：

```bash
curl http://127.0.0.1:3000/api/wordbooks/full >/dev/null && echo API_NEW
curl http://127.0.0.1:3000/api/progress -H 'Authorization: Bearer <token>'
```

`/api/progress` 返回里应有：

- `favoriteVideos`
- `customWords`
- `gender` / `birthday` / `nickname`

没有就是旧后端，需要部署 `yoji-server-update.zip`。

其他原因：

- 换了账号：客户端 `resetProgress` 会清空本机进度；
- 清除了 App 数据：本地丢了，只能靠云端；
- 旧服务端已经丢弃的字段无法恢复，但新 App 重新登录后会把本地仍存在的数据补传。

---

### 5. 进度同步 409

`PUT /api/progress` 返回 `1008` 表示版本冲突：

1. 先 `GET /api/progress` 拿最新 `version`；
2. 再带 `expectedVersion` 提交；
3. 只有“清空学习记录”才用 `force: true`。

日常学习请用 `POST /api/progress/sync`（并集合并），不要用 PUT。

---

### 6. 头像上传失败/退出后消失

按顺序检查：

1. **是否安装了新 App**：旧 APK 没有上传逻辑；
2. 浏览器/日志是否有 `POST /api/auth/avatar`：
   - 404：后端未部署头像接口；
   - 401：登录过期；
   - 400：图片不是 JPG/PNG/WebP 或超过 2MB；
3. 数据库 `users.avatar` 是否变成 `/media/avatars/...`：

```bash
sqlite3 /www/wwwroot/yoji/server/data/yoji.db \
  "select account,avatar from users where account='<账号>';"
```

4. 访问头像 URL 是否 200：

```bash
curl -I http://120.24.171.99/media/avatars/<文件>
```

5. Nginx `/media/` alias 是否正确、文件权限是否 `www:www`。

> 头像本地路径必须以 `/data/...` 开头，服务器路径才是 `/media/...`；App 已修复这个判断。

---

### 7. 视频列表看不到新视频

**上传文件 ≠ 数据库记录**。

1. 检查接口：

```bash
curl http://120.24.171.99/api/videos
```

2. 文件是否在：

```text
/www/wwwroot/yoji/server/media/videos
/www/wwwroot/yoji/server/media/thumbs
```

3. 手动扫描：

```bash
cd /www/wwwroot/yoji/server
export PATH=/www/server/nodejs/v24.22.0/bin:$PATH
npm run sync-media
```

或：

```bash
curl -X POST http://120.24.171.99/api/admin/videos/scan \
  -H "X-Admin-Token: <ADMIN_TOKEN>"
```

4. `visible=false` 的视频不会出现在 App；
5. 文件名不同（`3.mp4` + `【TED-Ed】.jpg`）不会自动配对，需要后台上传时一起选，或 PATCH `thumbUrl`。

---

### 8. 视频上传超时/失败

先看 HTTP 状态码：

| 状态 | 原因 | 处理 |
| --- | --- | --- |
| `timeout` | 前端 20s 超时（旧版） | 已改为 60 分钟；强刷后台 |
| 413 | Nginx 请求体限制 | `/api/` 加 `client_max_body_size 1024m;` |
| 401 | 管理员登录过期 | 重新登录 |
| 400 | 文件类型/大小不对 | mp4/webm/m4v ≤900MB |
| 502/504 | Node 挂了/代理超时 | 看 PM2、`proxy_read_timeout` |

当前配置：

```nginx
location /api/ {
    client_max_body_size 1024m;
    client_body_timeout 3600s;
    proxy_request_buffering off;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
}
```

实测 30MB 视频上传耗时约 25.5 秒，可成功。

---

### 9. 词表上传失败

先确认：

- 只支持 `.txt` / `.json`；
- **不要直接上传 zip / xlsx / pdf**；
- 从 zip 解压后上传单个 `CET4_edited.txt`；
- 文件 ≤8MB；
- 管理员 JWT 未过期。

手动测试：

```bash
curl -X POST http://120.24.171.99/api/admin/wordbooks/upload \
  -H "Authorization: Bearer <admin JWT>" \
  -F "name=CET-4 测试" \
  -F "file=@CET4_edited.txt"
```

成功返回 `wordCount: 4538` 左右。

常见错误：

- `只支持 .txt 或 .json 词表`：上传了 zip/xlsx；
- `没有解析到单词`：文件是二进制/编码异常，或格式不是一行一个词；
- 401：重新登录；
- 413：Nginx body 限制。

---

### 10. 后台显示词表，但 App 没有

App **只在启动时**拉取 `/api/wordbooks/full`。已加“词库页刷新”按钮：

1. App → 我的 → 当前词库；
2. 右上角点“刷新”；
3. 或彻底退出 App 重开。

还要确认：

- 词表是“显示”状态；
- `/api/wordbooks/full` 返回了该词表；
- App 已安装新 HAP（旧包没有远程词表逻辑）。

---

### 11. 后台页面空白/旧页面

- `Ctrl + F5` 强刷；
- Nginx 根目录是否 `/www/wwwroot/yoji-admin`；
- `/api/` 是否代理到 Node；
- 浏览器 localStorage 里 `yoji_admin_token` 是否过期；
- 后台静态包是否重新上传（`yoji-admin-site.zip`）。

---

### 12. 媒体 404 / 视频不能播放

```bash
curl -I http://120.24.171.99/media/videos/<文件名>
```

- 404：文件不在 `/www/wwwroot/yoji/server/media/videos`；
- 403：权限/alias 配置；
- 中文/特殊字符：URL 需要编码；
- Range 拖动失败：Nginx `/media/` 需要 `Accept-Ranges bytes`；
- 确认 `alias /www/wwwroot/yoji/server/media/;` 尾部斜杠正确。

---

### 13. 域名 HTTPS 被重置 / 备案

现象：`curl (35) Recv failure: Connection was reset`，但 IP 的 80 端口正常。

- `zhdstudy.cyou` 备案未下放，阿里云可能拦截；
- 备案期用 `http://120.24.171.99`；
- 后台也支持 `http://120.24.171.99/`；
- 不要从 HTTPS 页面请求 HTTP API（Mixed Content）；线上用同源 `/api`；
- 备案完成后把 App 的 `API_BASE_URL` 切到 `https://yoji.zhdstudy.cyou`。

---

### 14. 宝塔保存后配置被覆盖

直接改的配置文件：

```text
/www/server/panel/vhost/nginx/node_yoji_project.conf
```

在宝塔里点“网站设置 → 保存”可能重新生成并覆盖 `root`、`/api`、`/media`。  
如果被覆盖，把 [deploy-admin-baota.md](deploy-admin-baota.md) 里的 location 贴回，然后：

```bash
/www/server/nginx/sbin/nginx -t
/www/server/nginx/sbin/nginx -s reload
```

---

### 15. 安全组/端口

- 入方向：22（只允许自己的 IP）、80、443；
- **不要开放 3000**（Node 只监听 127.0.0.1）；
- 视频/词表上传走 80/443，不需要额外端口；
- 详细规则：[security-group.md](security-group.md)。

---

## 五、数据与运维

### 数据库

```text
/www/wwwroot/yoji/server/data/yoji.db
```

备份：

```bash
sqlite3 /www/wwwroot/yoji/server/data/yoji.db \
  ".backup '/root/yoji-$(date +%F).db'"
```

### 媒体目录

```text
media/videos    视频
media/thumbs    封面
media/avatars   头像
```

权限：

```bash
chown -R www:www /www/wwwroot/yoji/server/media
chmod -R 755 /www/wwwroot/yoji/server/media
```

### 重启

```bash
export PATH=/www/server/nodejs/v24.22.0/bin:$PATH
pm2 restart yoji_project --update-env
pm2 save
```

### 更新后端

```bash
cd /www/wwwroot/yoji/server
unzip -o /tmp/yoji-server-update.zip
npm install --omit=dev
pm2 restart yoji_project --update-env
pm2 save
```

> 含 `multer` 等新依赖时必须 `npm install`。

---

## 六、当前线上状态

- 后台：`http://120.24.171.99/`、`https://yoji.zhdstudy.cyou/`
- 测试管理员：`hans / 123456`、`zhd / 123456`
- 超级管理员：`admin` / `.env` 的 `ADMIN_TOKEN`
- 词表：CET4 4538、CET6 2220、CET4+6 8013
- 视频：3 个（含 `【TED-Ed】`）
- 后端测试：`npm test` 11/11
- 关键文档：
  - [admin-video-upload.md](admin-video-upload.md)
  - [wordbooks.md](wordbooks.md)
  - [security-group.md](security-group.md)
  - [baota-notes.md](baota-notes.md)
  - [deploy-admin-baota.md](deploy-admin-baota.md)
