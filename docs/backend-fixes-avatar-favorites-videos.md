# 后端问题修复：头像 / 收藏 / 视频列表

## 一、先定位到的根因

### 1. 收藏视频、自填单词薄消失

线上 `120.24.171.99` 当前跑的还是**旧版后端**。实测：

```text
POST /api/progress/sync  提交 favoriteVideos + customWords
GET  /api/progress       只返回 favorites，favoriteVideos / customWords 字段根本不存在
```

旧版 `sanitizeSnapshot` 白名单里没有：

- `favoriteVideos`（喜欢的视频）
- `customWords`（视频里自填的单词）
- `gender` / `birthday` / `nickname`（资料）

所以：

- 内置词库的 `favorites` 一直能同步；
- **视频收藏、自填单词薄在旧服务端被直接丢掉**，换设备/清数据后必然消失；
- 头像也从未上传到服务器，只存在本机沙箱。

### 2. 上传视频/封面后 App 看不到

`GET /api/videos` 只返回 **数据库 `videos` 表**里的记录。只把 `mp4`/`png` 放进 `media/videos`、`media/thumbs` 不会自动建记录，所以 App 仍然只看到原来的 2 条。

### 3. 头像只存本地

旧流程 `ProfileEditPage` 只把相册图片复制到应用沙箱，`PATCH /api/auth/me` 也拒绝本地路径；退出登录后 `Store.logout()` 会清空 `avatar`，重新登录自然没有。

---

## 二、已经补上的代码

### 1. 头像上传（服务端 + App）

- 新增 `POST /api/auth/avatar`：
  - `Authorization: Bearer <token>`
  - `Content-Type: application/octet-stream`
  - 请求体为原始图片字节；
  - 服务端按文件头识别 JPG / PNG / WebP，限制 2MB；
  - 写入 `media/avatars/<userId>.<ext>`；
  - 更新 `users.avatar` 为 `/media/avatars/...?v=时间戳`。
- App `Api.uploadAvatar()` 用 `Http.sendRaw` 发送 `ArrayBuffer`；
- `ProfileEditPage` 点保存时先上传头像，成功后才写 Store；
- `MineView` / `ProfileEditPage` 都能解析后端返回的相对地址 `/media/...`。

> 需要重新编译安装 App 才生效，旧 APK 不包含上传逻辑。

### 2. 收藏/自填词同步

- 新后端已完整保存 `favoriteVideos`、`customWords`、`gender`、`birthday`、`nickname`；
- 退出登录前 `CloudSync.flush()` 会等待正在进行的推送并补推最新快照，避免刚收藏就退出导致漏传；
- 新 App 登录时会把这些字段与本地并集合并。

> **已经丢在旧服务端的数据无法凭空恢复**；如果本机还在，重新登录并触发一次同步就会补传。

### 3. 视频目录扫描

新增：

```bash
cd /opt/yoji/server
npm run sync-media
```

或调接口：

```bash
curl -X POST https://你的域名/api/admin/videos/scan \
  -H "X-Admin-Token: 你的ADMIN_TOKEN"
```

扫描规则：

- `media/videos/*.mp4|webm|m4v`；
- `media/thumbs/` 下同名封面自动匹配；
- 文件名生成 id / 标题（`focus-talk.mp4` → `focus talk`）；
- 重复扫描不会重复插入；
- 已存在的同文件记录只更新链接。

---

## 三、部署步骤（需要你在服务器操作）

### 1. 上传后端更新包

仓库根目录：`yoji-server-update.zip`，压缩包内是 `src/...`、`scripts/...`、`package.json`。

```bash
cd /opt/yoji/server
unzip -o /path/to/yoji-server-update.zip
# 只新增文件、无新依赖，不需要重新 npm install
systemctl restart yoji-api    # 或宝塔 PM2 里重启
```

检查：

```bash
curl https://你的域名/api/videos
curl -X POST https://你的域名/api/auth/avatar \
  -H "Content-Type: application/octet-stream" \
  -H "Authorization: Bearer <token>" \
  --data-binary @test.jpg
```

Nginx 需要允许 2MB 头像，`/api/` 里加：

```nginx
client_max_body_size 4m;
```

### 2. 扫描视频

先把文件放到：

```text
/opt/yoji/media/videos/xxx.mp4
/opt/yoji/media/thumbs/xxx.png   # 或 xxx.jpg / xxx.webp
```

然后：

```bash
cd /opt/yoji/server && npm run sync-media
```

App 切到视频 Tab 会重新请求 `/api/videos`；如果页面已经打开，切走再切回即可。

### 3. 重新安装 App

用 DevEco Studio 重新 build/run；只更新后端不会让旧 APK 长出头像上传逻辑。

---

## 四、验收清单

- [ ] 换头像 → 保存 → 杀掉 App → 重开，头像仍是新的；
- [ ] 换头像 → 退出登录 → 重新登录，头像仍是新的；
- [ ] 收藏视频 → 退出登录 → 重新登录，视频还在；
- [ ] 视频里添加自填单词 → 退出登录 → 重新登录，单词薄还在；
- [ ] 上传新 `mp4` + 同名封面 → 执行 `npm run sync-media` → App 视频列表出现新视频；
- [ ] 新视频能播放，封面能显示。

## 五、当前限制

- 我这边 `ssh root@120.24.171.99` 仍然是 `Permission denied (publickey,password)`，无法直接上传/重启/扫描；以上命令需要你在宝塔终端执行。
- 如果愿意临时加一个 SSH 公钥，我可以直接完成部署和验收。
