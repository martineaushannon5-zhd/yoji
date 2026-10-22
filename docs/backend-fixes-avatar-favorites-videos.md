# 后端修复与上线记录（2026-10-22）

## 一、线上已完成

服务器：`120.24.171.99`
后端目录：`/www/wwwroot/yoji/server`
PM2 进程：`yoji_project`
后台静态目录：`/www/wwwroot/yoji-admin`
Nginx 配置：`/www/server/panel/vhost/nginx/node_yoji_project.conf`

已完成：

- 后端代码更新并重启；
- 生成生产 `.env`，启用 `NODE_ENV=production`、强随机 `JWT_SECRET` 和 `ADMIN_TOKEN`；
- 后台静态站点部署到 `https://yoji.zhdstudy.cyou/`；
- `/api/` 反向代理到 Node，`/media/` 指向媒体目录；
- 媒体扫描已执行，新增视频 `【TED-Ed】`（`3.mp4` + `【TED-Ed】.jpg`）；
- App 视频列表已能看到 3 个视频，封面正常。

## 二、当时的根因

### 1. 收藏视频、自填单词薄消失

旧后端 `sanitizeSnapshot` 不认：

- `favoriteVideos`
- `customWords`
- `gender` / `birthday` / `nickname`

实测旧版同步 `favoriteVideos` / `customWords` 后，再拉取时字段直接不存在。内置词库的 `favorites` 一直能同步；视频收藏和自填单词被丢弃。

### 2. 头像只存本地

旧版只把相册图片复制到应用沙箱，没有上传接口；退出登录会清空本地 `avatar`。

### 3. 上传视频/封面后 App 看不到

`/api/videos` 只返回数据库 `videos` 表记录。只往 `media/videos`、`media/thumbs` 放文件不会自动建记录。

## 三、现在的实现

### 头像

- `POST /api/auth/avatar`：`Authorization: Bearer <token>`，`Content-Type: application/octet-stream`，原始图片字节；
- 支持 JPG / PNG / WebP，≤2MB；
- 写入 `/www/wwwroot/yoji/server/media/avatars/`；
- 更新 `users.avatar`，登录 / `/api/auth/me` 返回 `/media/avatars/...`；
- App 保存资料时先上传，再用服务器地址更新 Store。

### 收藏

- 新后端完整保存 `favoriteVideos`、`customWords`、`gender`、`birthday`、`nickname`；
- 退出登录前 `CloudSync.flush()` 会等待正在进行的推送并补推最新快照。

### 视频

```bash
cd /www/wwwroot/yoji/server
export PATH=/www/server/nodejs/v24.22.0/bin:$PATH
npm run sync-media
```

或：

```bash
curl -X POST https://yoji.zhdstudy.cyou/api/admin/videos/scan \
  -H "X-Admin-Token: 你的ADMIN_TOKEN"
```

规则：

- 扫描 `media/videos/*.mp4|webm|m4v`；
- `media/thumbs/` 下同名封面自动匹配；
- 重复扫描不会重复插入；
- 文件名生成 id / 标题。

## 四、线上验证结果

- 后端测试：**9/9 通过**；
- 管理后台登录、Dashboard、用户列表：通过；
- 新视频 `【TED-Ed】`：App 列表显示、封面显示、`/media/videos/3.mp4` 返回 200；
- 头像：上传返回 200，头像 URL 返回 `image/png`；
- 收藏：`favorites=1`、`favoriteVideos=1`、`customWords=1` 同步后均保留；
- 管理后台：`https://yoji.zhdstudy.cyou/` 200，`/api/videos` 200。

## 五、注意

1. 本次把 `JWT_SECRET` 换成了生产随机值，**旧登录 token 已全部失效**，App 需要退出后重新登录一次。
2. 旧服务端已经丢掉的收藏无法恢复；如果手机上本地数据还在，重新登录并触发一次同步会补传。
3. 管理后台账号：`admin`，密码在服务器：

```bash
grep ADMIN_TOKEN /www/wwwroot/yoji/server/.env
```

4. 以后再上传视频：先把 `mp4` 和同名封面放到 `server/media/videos`、`server/media/thumbs`，再执行 `npm run sync-media`。
5. 真机安装需要重新用 DevEco 构建并签名；当前仓库里的 HAP 是未签名模拟器包。
