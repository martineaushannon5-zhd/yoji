# Yoji 后端（server）

给 HarmonyOS「Yoji.（要记单词）」App 用的账号与数据服务，目标是一台 **2 核 2G / Ubuntu 22.04** 的纯净云服务器就能跑起来。

> App 端已经接入本后端，改了哪些文件、如何联调见 [`../docs/backend-integration.md`](../docs/backend-integration.md)。

- 运行时：Node.js 24 LTS（单进程，常驻内存约 60–100 MB）
- 数据库：SQLite（Node 内置 `node:sqlite`，无需额外安装 MySQL / Redis）
- 密码：bcrypt 哈希，不存明文
- 登录态：JWT（30 天）+ `token_version`，退出登录后旧 token 立即失效
- 用户数据：整份学习进度快照 JSON，多设备「并集合并」，不会互相覆盖
- 视频：数据库只存链接，真正的 mp4 由 Nginx 直接读磁盘并支持 Range 拖动

```
server/
├─ src/
│  ├─ server.js          启动入口
│  ├─ app.js             Express 装配、限流、静态媒体、错误处理
│  ├─ config.js          环境变量
│  ├─ db.js              SQLite 建表与数据访问
│  ├─ auth.js            bcrypt、JWT、鉴权中间件
│  ├─ progress.js        进度清洗 / 合并 / 连续天数计算
│  ├─ http.js            统一响应格式
│  └─ routes/            auth、progress、videos、admin
├─ deploy/
│  ├─ install.sh         Ubuntu 一键安装
│  ├─ yoji-api.service   systemd
│  └─ nginx-yoji.conf    Nginx 反代 + 静态视频
├─ test/api.test.mjs     接口冒烟测试
├─ data/                 SQLite 数据（自动生成，勿提交）
└─ media/                videos/ 与 thumbs/，放 mp4 和封面
```

---

## 一、服务器部署（从零开始）

下面命令都在服务器上、用 root 执行。

### 1. 上传代码

在**你自己的电脑**、项目根目录执行（把 `服务器IP` 换成真实 IP）：

```bash
ssh root@服务器IP "mkdir -p /opt/yoji"
scp -r server root@服务器IP:/opt/yoji/
```

### 2. 一键安装

```bash
ssh root@服务器IP
bash /opt/yoji/server/deploy/install.sh
```

脚本会自动：装 Node 24 / Nginx / certbot / sqlite3 / ufw → 建 `yoji` 用户和目录 → `npm ci` → 生成 `.env` 随机密钥 → 注册并启动 `yoji-api` 服务 → 本机健康检查。

看到 `{"status":"ok",...}` 就说明 Node 服务起来了。

### 3. 上传视频与封面

在项目根目录执行：

```bash
scp entry/src/main/resources/rawfile/anxiety.mp4 root@服务器IP:/opt/yoji/media/videos/
scp entry/src/main/resources/rawfile/sloppy.mp4  root@服务器IP:/opt/yoji/media/videos/
scp entry/src/main/resources/base/media/video_thumb_anxiety.png root@服务器IP:/opt/yoji/media/thumbs/
scp entry/src/main/resources/base/media/video_thumb_sloppy.jpg  root@服务器IP:/opt/yoji/media/thumbs/
ssh root@服务器IP "chown -R yoji:yoji /opt/yoji/media && chmod -R 755 /opt/yoji/media"
```

> 视频目录结构必须和数据库里的链接一致：
> `/media/videos/anxiety.mp4`、`/media/thumbs/video_thumb_anxiety.png`。
> 如果换了文件名，用后台接口改 `videoUrl` / `thumbUrl` 即可。

### 4. 域名 + HTTPS

HarmonyOS 应用默认不建议走明文 HTTP，正式使用请配 HTTPS。

1. 把域名（如 `api.yoji.com`）A 记录解析到服务器 IP。
2. 在服务器执行：

```bash
# 先启用 HTTP 配置（此时证书还不存在，不能直接启用带 ssl 的配置）
cp /opt/yoji/server/deploy/nginx-yoji-http.conf /etc/nginx/sites-available/yoji-api.conf
sed -i 's/api.example.com/你的域名/g' /etc/nginx/sites-available/yoji-api.conf
ln -sf /etc/nginx/sites-available/yoji-api.conf /etc/nginx/sites-enabled/yoji-api.conf
rm -f /etc/nginx/sites-enabled/default
mkdir -p /var/www/certbot
nginx -t && systemctl reload nginx

# 申请证书：certbot 会自动加上 443 / 证书路径 / HTTP 跳转
certbot --nginx -d 你的域名

nginx -t && systemctl reload nginx
```

> `deploy/nginx-yoji.conf` 是手动管理证书时的 HTTPS 参考模板；用 certbot 一键模式时不需要再替换它。

3. 验证：

```bash
curl https://你的域名/healthz
curl https://你的域名/api/videos
```

如果暂时没有域名，可以先只做本机调试（App 用模拟器访问宿主机 IP），但真机长期使用不建议裸 HTTP。

### 5. 常用运维命令

```bash
systemctl status yoji-api          # 服务状态
journalctl -u yoji-api -f          # 实时日志
systemctl restart yoji-api         # 重启
nginx -t && systemctl reload nginx # 改完 Nginx 后检查并重载
```

### 6. 备份（很重要）

SQLite 是单文件，备份非常简单。仓库里已经带了脚本 `deploy/backup.sh`：

```bash
chmod +x /opt/yoji/server/deploy/backup.sh
(crontab -l 2>/dev/null; echo "30 3 * * * /opt/yoji/server/deploy/backup.sh") | crontab -
```

脚本会调用 `sqlite3 .backup` 生成 `/opt/yoji/backup/yoji-日期.db`，并只保留最近 7 天。

视频文件不进数据库，建议用 `rsync` 定期同步到对象存储或另一台机器。

### 7. 2G 内存够不够？

够。常驻只有一个 Node 进程 + Nginx + SQLite，正常情况下内存占用 150–250 MB。建议顺手加 2G swap 兜底：

```bash
fallocate -l 2G /swapfile && chmod 600 /swapfile
mkswap /swapfile && swapon /swapfile
echo '/swapfile none swap sw 0 0' >> /etc/fstab
```

---

## 二、接口文档

统一前缀 `https://你的域名`，请求/响应都是 JSON。

统一响应格式：

```json
{ "code": 0, "message": "ok", "data": {} }
```

`code === 0` 表示成功。业务错误同时带 HTTP 状态码，例如密码错误返回 `401` + `code: 1002`。

需要登录的接口带请求头：

```
Authorization: Bearer <token>
```

### 1. 账号

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| POST | `/api/auth/register` | 注册 |
| POST | `/api/auth/login` | 登录 |
| GET | `/api/auth/me` | 当前用户 |
| PATCH | `/api/auth/me` | 改昵称 / 头像 |
| POST | `/api/auth/logout` | 退出登录（旧 token 全部失效） |

注册 / 登录请求：

```json
{ "account": "student01", "password": "secret123" }
```

返回（和 App 里 `LoginPage.ets` 注释的约定一致）：

```json
{
  "code": 0,
  "message": "登录成功",
  "data": {
    "token": "eyJhbGciOi...",
    "userId": "0b1c...",
    "account": "student01",
    "nickname": "Yoji.student01",
    "avatar": ""
  }
}
```

账号规则：3–64 位字母、数字或 `_ . @ + -`；密码 6–72 位。账号不区分大小写。

### 2. 学习进度

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/api/progress` | 拉取云端进度 |
| POST | `/api/progress/sync` | 本地与云端并集合并（App 日常使用） |
| PUT | `/api/progress` | 覆盖写入（清空记录等，支持乐观锁 / force） |

`GET /api/progress` 返回：

```json
{
  "code": 0,
  "message": "ok",
  "data": {
    "version": 3,
    "updatedAt": "2026-10-20T00:00:00.000Z",
    "data": {
      "currentBookId": "cet4",
      "dailyTarget": 20,
      "statusMap": { "c4-1": 2, "c4-2": 1 },
      "masteredAt": { "c4-1": "2026-10-19" },
      "learnedLog": { "2026-10-20": ["c4-2"] },
      "favorites": { "c4-3": "2026-10-20" },
      "swipeGuideShown": true,
      "todayLearned": 1,
      "todayDate": "2026-10-20",
      "streak": 2,
      "totalLearned": 1,
      "learnedDays": 2,
      "lastLearnDate": "2026-10-20",
      "videoProgress": { "ted-anxiety": 30 },
      "darkMode": true
    }
  }
}
```

`POST /api/progress/sync` 请求：

```json
{ "data": { "currentBookId": "cet4", "statusMap": { "c4-1": 2 }, "...": "..." } }
```

合并规则：

- `statusMap`：同一个词取更高状态（已掌握 > 学习中 > 未学）
- `learnedLog`、`favorites`：取并集
- `totalLearned`、`videoProgress`：取较大值
- 词书 / 每日目标 / 深色模式：以有学习数据的一端为准
- `streak`（连续天数）：优先按学习日志重新计算，其次取两端较大值

返回的是**合并后的完整快照 + 新版本号**，App 用返回值覆盖本地即可。

清空学习记录：

```json
PUT /api/progress
{ "data": { "currentBookId": "cet4", "dailyTarget": 10, "statusMap": {}, "learnedLog": {} }, "force": true }
```

不传 `force` 时若 `expectedVersion` 与服务端不一致，会返回 `409`（`code: 1008`）和云端最新数据。

### 3. 视频

| 方法 | 路径 | 说明 |
| --- | --- | --- |
| GET | `/api/videos` | 视频列表（公开，仅 visible） |
| GET | `/api/videos/:id` | 单个视频 |

返回：

```json
{
  "code": 0,
  "message": "ok",
  "data": {
    "videos": [
      {
        "id": "ted-anxiety",
        "title": "【TED演讲】如何解决焦虑",
        "description": "",
        "date": "2026-10-20",
        "thumbUrl": "/media/thumbs/video_thumb_anxiety.png",
        "videoUrl": "/media/videos/anxiety.mp4",
        "duration": 0,
        "sortOrder": 1,
        "visible": true
      }
    ]
  }
}
```

`videoUrl` / `thumbUrl` 可以是站内相对路径 `/media/...`，也可以是完整的 CDN 地址 `https://cdn.example.com/xxx.mp4`。**App 端把相对路径拼上服务器域名即可。**

### 4. 后台管理

后台有两种鉴权方式，互不混用：

1. **管理后台（Yoji Admin）**：`POST /api/admin/login` 用管理员账号 + `ADMIN_TOKEN` 换 JWT，之后带 `Authorization: Bearer <token>` 访问统计/用户接口。
2. **视频运维脚本**：继续使用 `X-Admin-Token: <ADMIN_TOKEN>`，方便 curl 直接改视频。

管理员账号默认 `admin`（`ADMIN_ACCOUNT` 可改），**登录密码就是 `ADMIN_TOKEN`**。令牌在 `/opt/yoji/server/.env`：

```bash
grep ADMIN_ACCOUNT /opt/yoji/server/.env
grep ADMIN_TOKEN /opt/yoji/server/.env
```

| 方法 | 路径 | 鉴权 | 说明 |
| --- | --- | --- | --- |
| POST | `/api/admin/login` | 无 | 管理员登录，返回 JWT |
| GET | `/api/admin/stats` | Bearer JWT | 总用户、今日活跃、学习趋势 |
| GET | `/api/admin/users` | Bearer JWT | 用户列表，支持 `search/page/pageSize` |
| DELETE | `/api/admin/users/:id` | Bearer JWT | 删除用户及其进度 |
| GET | `/api/admin/ping` | X-Admin-Token | 验证运维令牌 |
| GET | `/api/admin/videos` | X-Admin-Token | 全部视频（含隐藏） |
| POST | `/api/admin/videos` | X-Admin-Token | 新增视频 |
| PATCH | `/api/admin/videos/:id` | X-Admin-Token | 修改视频 |
| DELETE | `/api/admin/videos/:id` | X-Admin-Token | 删除视频 |

管理员登录：

```bash
curl -X POST https://你的域名/api/admin/login \
  -H "Content-Type: application/json" \
  -d '{"account":"admin","password":"你的ADMIN_TOKEN"}'
```

返回：

```json
{
  "code": 0,
  "message": "登录成功",
  "data": { "token": "eyJ...", "account": "admin", "expiresIn": "12h" }
}
```

用户列表：

```bash
TOKEN=登录返回的 token

curl "https://你的域名/api/admin/users?search=&page=1&pageSize=10" \
  -H "Authorization: Bearer $TOKEN"
```

统计：

```bash
curl https://你的域名/api/admin/stats \
  -H "Authorization: Bearer $TOKEN"
```

新增视频示例（运维脚本仍用 X-Admin-Token）：

```bash
curl -X POST https://你的域名/api/admin/videos \
  -H "Content-Type: application/json" \
  -H "X-Admin-Token: 你的ADMIN_TOKEN" \
  -d '{
    "id": "ted-focus",
    "title": "【TED演讲】如何专注",
    "date": "2026-10-20",
    "thumbUrl": "/media/thumbs/focus.png",
    "videoUrl": "/media/videos/focus.mp4",
    "sortOrder": 3
  }'
```

把视频换成外部链接（例如对象存储 / CDN）：

```bash
curl -X PATCH https://你的域名/api/admin/videos/ted-focus \
  -H "Content-Type: application/json" \
  -H "X-Admin-Token: 你的ADMIN_TOKEN" \
  -d '{"videoUrl":"https://cdn.example.com/ted/focus.mp4","visible":true}'
```

管理后台前端在 `yoji-admin/`，静态部署与 Nginx 反代见 [../docs/deploy-admin-baota.md](../docs/deploy-admin-baota.md)。

### 5. 错误码

| code | 含义 |
| --- | --- |
| 1000 | 参数错误 |
| 1001 | 未登录 / token 无效 |
| 1002 | 账号或密码错误 |
| 1003 | 账号已存在 |
| 1005 | token 过期 |
| 1006 | 无权限 |
| 1007 | 资源不存在 |
| 1008 | 版本冲突 |
| 1009 | 请求过于频繁 |
| 1500 | 服务器内部错误 |

---

## 三、本地开发

```bash
cd server
cp .env.example .env      # 本地可把 DATA_DIR / MEDIA_DIR 改成相对路径
npm install
npm run dev               # http://127.0.0.1:3000
npm test                  # 接口冒烟测试（使用临时数据库，不影响 data/）
```

本地 `.env` 示例：

```
NODE_ENV=development
JWT_SECRET=dev-secret-0123456789abcdef0123456789abcdef
ADMIN_TOKEN=dev-admin-token
DATA_DIR=./data
MEDIA_DIR=./media
```

> Node 24 的 `node:sqlite` 启动时会打印一条 `ExperimentalWarning`，属于正常提示，不影响使用。若你更希望用成熟第三方库，可换成 `better-sqlite3`，接口层不用改。

---

## 四、安全设计（答辩可讲）

1. **密码**：bcrypt（cost 10）加盐哈希；登录时账号不存在也做一次同成本比对，避免时间侧信道枚举账号。
2. **登录态**：JWT HS256，30 天；数据库存 `token_version`，退出登录 / 改密码后旧 token 立刻失效。
3. **限流**：全局 300 次/分钟/IP；登录注册 100 次/15 分钟；注册 10 次/小时；管理后台登录 20 次/15 分钟。
4. **输入校验**：账号、密码、进度快照全部白名单清洗，限制字段数量和长度，进度请求最大 1 MB。
5. **管理接口隔离**：`ADMIN_TOKEN` 与用户体系完全分开；管理后台走独立 `role=admin` JWT，普通用户 token 无法访问后台接口，令牌同样使用常量时间比较。
6. **SQL 注入**：全部使用参数化查询，不拼接 SQL。
7. **部署**：Node 只监听 `127.0.0.1`，外部只能经 Nginx；systemd 开了 `NoNewPrivileges`、`ProtectSystem` 等加固。

---

## 五、容量参考

- 每个用户进度约 5–50 KB（词库越大越多）
- 1 万用户约 0.2–0.5 GB 数据库，SQLite 完全无压力
- 视频走 Nginx 静态文件，瓶颈是带宽而不是 CPU；2G 内存不影响
- 真到几万日活再考虑 PostgreSQL / 对象存储，当前架构不用提前复杂化

---

## 六、大陆服务器备案提醒

如果服务器在**中国大陆**（阿里云 / 腾讯云等），域名必须完成 **ICP 备案**，否则：

- 80 端口会返回 `403 Non-compliance ICP Filing`（阿里云的拦截页，响应头 `Server: Beaver`）；
- 443 也可能对部分客户端重置握手；
- 未备案域名换端口、换协议都不算合规，随时可能被再次拦截。

临时联调可以先用「公网 IP + HTTP」（本项目当前就是这样做的），但密码/token 会明文传输，**不能作为正式上线方案**。正式方案：

1. 用可备案域名（`.com` / `.cn` 等）完成 ICP 备案，再走 HTTPS；
2. 或者把后端部署到境外 / 香港服务器，不需要 ICP。

`.cyou` 等部分新顶级域名通常无法完成大陆 ICP 备案，选域名前先确认。
