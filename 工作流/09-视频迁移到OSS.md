# 09 - 把视频从 ECS 迁到阿里云 OSS + CDN

> 目标：视频不再占 ECS 磁盘、不再吃 ECS 带宽；App 和后台的播放地址保持可用，最好用户无感。
> 适用：阿里云 2C2G ECS，站点 `https://yoji.zhdstudy.cyou`，媒体目录 `/www/wwwroot/yoji/server/media`。

## 0. 先厘清一件事

视频占的是**磁盘**，不是内存。你现在感觉“服务器压力大”，通常是三件事叠加：

1. 磁盘被视频占满，系统/数据库写不进去；
2. 2C2G 的**公网带宽**很小（常见 1–5Mbps），一个人看 30MB 视频就能把带宽打满，接口跟着变慢；
3. Nginx/Node 在传大文件时占 CPU 和连接数。

迁到 OSS + CDN 后，1 解决，2、3 基本消失：视频字节从 CDN 边缘节点出去，ECS 只处理 JSON 接口。

## 1. 选型结论

**OSS 标准存储 + CDN 加速域名**，不要只用 OSS 默认域名。

| 方案 | 费用（大陆，参考价） | 适合 |
| --- | --- | --- |
| ECS 本地磁盘 + 直接出流量 | 磁盘便宜，但带宽是瓶颈 | 现在，用户一多就卡 |
| OSS 默认域名直读 | 存储 0.12 元/GB/月 + 外网流出 0.50 元/GB | 临时、量小 |
| **OSS + CDN** | 存储 0.12 元/GB/月 + CDN 流量 0.24 元/GB 起 | 长期，视频为主 |

粗算：20GB 视频、每月 500GB 播放流量 → 存储 2.4 元 + CDN 约 120 元 ≈ **122 元/月**；同样流量走 ECS 带宽，按固定带宽升配远不止这个价。

> CDN 加速域名在中国大陆需要 **ICP 备案**。`yoji.zhdstudy.cyou` 已经在对外服务，通常备案主体可用；如果 `.cyou` 没有备案，先用 OSS 默认域名顶着（按 0.50 元/GB 计费），或开香港/海外加速节点（免备案，但大陆访问质量一般）。

## 2. 控制台操作（约 15 分钟）

### 2.1 建 Bucket

1. OSS 控制台 → Bucket 列表 → 创建 Bucket；
2. 地域选**和 ECS 相同**的地域（如华东1 杭州），内网回源和上传更快；
3. 读写权限：**公共读**（视频本来就是公开内容，私有读还要给 CDN 配回源鉴权，复杂度不值得）；
4. 不开版本控制，不开归档。

### 2.2 绑 CDN

1. CDN 控制台 → 域名管理 → 添加域名，如 `cdn.zhdstudy.cyou`；
2. 源站类型选 **OSS 域名**，选中刚建的 Bucket；
3. 缓存规则：
   - `*.mp4` / `*.webm` / `*.m4v`：缓存 30 天，**忽略参数**；
   - `*.jpg` / `*.png` / `*.webp`：缓存 7 天；
4. 开启 HTTPS（上传证书或用免费证书）；
5. 回源协议选 HTTPS；Range 回源 OSS 原生支持，不用额外配置。

### 2.3 配 CORS（直传必须）

OSS 控制台 → Bucket → 数据安全 → 跨域设置 → 创建规则：

- 来源：`https://yoji.zhdstudy.cyou`、`http://localhost:3000`（本地调试用，可删）、`app://-`（Electron 桌面端）；
- 桌面端如果用 `app://-` 仍被 CORS 拦（部分 Chromium 版本会发 `Origin: null`），临时把来源改成 `*` 也能用——写操作本身需要签名，风险可控；
- 允许 Methods：`POST`、`GET`、`HEAD`；
- 允许 Headers：`*`；
- 暴露 Headers：`ETag`、`x-oss-request-id`；
- 缓存时间：600 秒。

不配 CORS 时，后台点上传会报“网络错误”，浏览器控制台能看到 CORS 拦截。

### 2.4 RAM 子账号（签名用）

1. RAM 控制台 → 用户 → 创建用户，勾选“使用永久 AccessKey”；
2. 只授予自定义策略，别给 `AliyunOSSFullAccess`：

```json
{
  "Version": "1",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["oss:PutObject"],
      "Resource": ["acs:oss:*:*:你的bucket/media/*"]
    }
  ]
}
```

3. 保存 AccessKeyId / AccessKeySecret，填到服务器 `.env`。

### 2.5 现状变体：Bucket 私有 + 主账号创建（深圳同地域）

如果 Bucket 已经建好、ACL 是**私有**、用的是主账号，不必推倒重来：

- **上传不受 ACL 影响**，迁移命令和 3.1 完全一样；
- 服务器在深圳同地域 ECS 时，endpoint 用内网 `oss-cn-shenzhen-internal.aliyuncs.com`——上传走内网，不占公网带宽、不收外网流出流量费；不在 ECS 上（或跨地域）才用 `oss-cn-shenzhen.aliyuncs.com`。

读（播放）有三条路，按“先跑通、再加速”选：

**A. 只放开 `media/*` 前缀的匿名只读（最快，推荐先做）**

桶 ACL 保持私有，加一条 Bucket 策略，只允许匿名 `GetObject` 这个前缀：

```json
{
  "Version": "1",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": ["*"],
      "Action": ["oss:GetObject"],
      "Resource": ["acs:oss:*:*:你的bucket/media/*"]
    }
  ]
}
```

播放地址形如 `https://你的bucket.oss-cn-shenzhen.aliyuncs.com/media/videos/xxx.mp4`，改库时 `--to` 就用这个前缀。桶里其他对象仍然私有。

**B. CDN + 私有 Bucket 回源（长期推荐，省服务器带宽）**

CDN 控制台添加域名 → 源站类型选 OSS 域名 → 选中该 Bucket → 开启“私有 Bucket 回源”，按提示完成一次 RAM 授权（CDN 用服务角色回源，不需要把 Bucket 改成公共读）。之后 `--to https://cdn.你的域名/media`。大陆节点需要域名已备案。

**C. 全私有 + 签名 URL**

播放地址会过期，App 播放器、缓存、分享链接都要跟着改，现阶段不建议。

主账号 AccessKey 虽然可用，但建议换成 RAM 子账号（只给 `oss:PutObject` / `oss:GetObject` / `oss:ListObjects`，资源限 `bucket/media/*`）；如果先用主账号跑迁移，迁完立刻禁用这把 AK，避免长期放在服务器上。

## 3. 迁移已有视频（不停机）

在 ECS 上执行。先装 ossutil（以 v1 为例，x86_64）：

```bash
cd /root
curl -o ossutil.zip https://gosspublic.alicdn.com/ossutil/1.7.19/ossutil-v1.7.19-linux-amd64.zip
unzip -o ossutil.zip && cd ossutil-v1.7.19-linux-amd64
./ossutil config     # 填 endpoint（如 oss-cn-hangzhou.aliyuncs.com）、AccessKeyId、AccessKeySecret
```

### 3.1 上传

```bash
# 先 dry-run 看要传多少
./ossutil cp -r /www/wwwroot/yoji/server/media/ oss://你的bucket/media/ --dry-run

# 正式传（--update 跳过已存在且大小一致的）
./ossutil cp -r /www/wwwroot/yoji/server/media/ oss://你的bucket/media/ --update -j 4
```

校验：

```bash
./ossutil ls oss://你的bucket/media/ -s | tail -3
du -sh /www/wwwroot/yoji/server/media
```

两边文件数和总大小应一致。

### 3.2 改数据库地址

服务器仓库里已经有脚本（默认 dry-run）：

```bash
cd /www/wwwroot/yoji/server
node scripts/rewrite-media-urls.mjs \
  --db /www/wwwroot/yoji/server/data/yoji.db \
  --from /media \
  --to https://cdn.zhdstudy.cyou/media

# 确认输出的替换条数无误后
node scripts/rewrite-media-urls.mjs \
  --db /www/wwwroot/yoji/server/data/yoji.db \
  --from /media \
  --to https://cdn.zhdstudy.cyou/media --apply
```

脚本会先备份数据库为 `yoji.db.bak-时间戳`。改完重启 Node：

```bash
pm2 restart yoji   # 或你用的进程管理方式
```

App/后台不需要重新打包：`resolveMediaUrl` 对 `http(s)://` 原样返回，对 `/media/...` 才拼域名。

### 3.3 旧地址兜底

老版本 App 可能缓存了相对路径，或者用户正停在上一个页面。Nginx 加一条 302：

```nginx
location /media/ {
    return 302 https://cdn.zhdstudy.cyou$request_uri;
}
```

保留一周，观察访问日志里 `/media/` 的请求量降到 0 后再删。

### 3.4 删除本地视频

确认 CDN 播放正常、DB 已全部替换后：

```bash
mv /www/wwwroot/yoji/server/media /www/wwwroot/yoji/server/media.bak-$(date +%F)
# 稳定运行 3 天后再 rm -rf
```

## 4. 以后新上传：浏览器直传 OSS

代码已经支持，不需要再走 ECS 中转：

1. `.env` 填 `OSS_ACCESS_KEY_ID`、`OSS_ACCESS_KEY_SECRET`、`OSS_BUCKET`、`OSS_REGION`、`OSS_PUBLIC_BASE=https://cdn.zhdstudy.cyou`；
2. 重启 Node；
3. 后台“视频管理”页右上角会显示“直传 OSS”；
4. 新增视频时，浏览器先向 `POST /api/admin/media/sign` 要一次性签名，再直接 POST 给 OSS，最后把 `videoUrl`/`thumbUrl` 登记进数据库。

涉及的接口：

```
GET  /api/admin/storage     → { mode: "oss" | "local" }
POST /api/admin/media/sign  → { host, key, policy, signature, accessKeyId, publicUrl, expire }
```

未配置 OSS 时 `mode=local`，前端自动退回原来的 `/api/admin/videos/upload`（multer 写磁盘），行为不变。

> 注意：直传后文件在 OSS 上的 key 是 `media/videos/YYYYMM/xxx.mp4`，和迁移时 `media/` 前缀一致，CDN 缓存规则能直接命中。

## 5. 验证清单

```bash
# 1. CDN 能播、支持 Range（拖进度条依赖它）
curl -I https://cdn.zhdstudy.cyou/media/videos/xxx.mp4
# 期望：200、Content-Type: video/mp4、Accept-Ranges: bytes

curl -r 0-1023 -o /tmp/head.bin https://cdn.zhdstudy.cyou/media/videos/xxx.mp4
ls -l /tmp/head.bin   # 1024

# 2. 数据库里没有残留相对路径
sqlite3 /www/wwwroot/yoji/server/data/yoji.db \
  "select count(*) from videos where video_url like '/media/%';"
# 期望：0

# 3. 接口返回绝对地址
curl -s https://yoji.zhdstudy.cyou/api/videos | head -c 400
```

App 端：视频列表能出封面、点开能播、拖进度条正常；后台：新增视频走直传，OSS 控制台能看到新对象。

## 6. 回滚

1. 停 Node；
2. 用 `yoji.db.bak-时间戳` 覆盖数据库；
3. `.env` 里清空 `OSS_*`（或 `OSS_PUBLIC_BASE` 置空）；
4. `mv media.bak-日期 media`（如果已删，从 OSS 反向 `ossutil cp -r oss://bucket/media/ ./media/`）；
5. 重启，Nginx 删掉 302。

## 7. 常见坑

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| 上传报 CORS | Bucket 没配跨域，或来源少了正式域名 | 按 §2.3 补 |
| 403 SignatureDoesNotMatch | AK/SK 填错，或 policy 过期 | 检查 `.env`，签名只有 10 分钟 |
| 播放 404 | key 前缀不一致（`media/` vs `videos/`） | 看 `publicUrl` 和 OSS 实际路径 |
| 视频能下不能拖 | CDN 没透传 Range | 关掉“忽略 Range”类配置，OSS 原生支持 |
| 防盗链开了 App 播不了 | App 请求没有 Referer | Referer 白名单允许空 Referer，或先不开 |
| 账单涨得快 | 走了 OSS 外网流出而不是 CDN | 确认播放地址是 CDN 域名 |

## 8. 成本监控

- OSS 控制台 → 用量查询：看存储量、外网流出、请求数；
- CDN 控制台 → 用量：看流量和命中率，命中率低于 90% 检查缓存规则是否被参数打散；
- 设置费用预警（用户中心 → 费用预警），阈值建议 50 元。

## 9. 和代码的对应关系

| 文件 | 作用 |
| --- | --- |
| `server/src/oss.js` | 生成 OSS POST policy 与 HMAC-SHA1 签名，无第三方依赖 |
| `server/src/routes/admin.js` | `GET /api/admin/storage`、`POST /api/admin/media/sign` |
| `yoji-admin/lib/oss-upload.ts` | 浏览器 XHR 直传，带进度回调 |
| `yoji-admin/app/(admin)/videos/page.tsx` | `mode=oss` 时走直传，否则走原 multipart |
| `server/scripts/rewrite-media-urls.mjs` | 批量把 DB 里的 `/media` 改成 CDN 绝对地址，默认 dry-run |

## 10. 本次实际迁移记录（2026-11-16）

- 账号与地域：主账号 `1278459111899336`，Bucket `yoji-video`，`oss-cn-shenzhen`，ACL 私有，冗余 ZRS；「阻止公共访问」已关闭（否则桶策略写不进去）。
- 服务器：`120.24.171.99`（深圳 ECS，`cn-shenzhen`），ossutil v1.7.19 装在 `/root/ossutil-v1.7.19-linux-amd64`，走内网 `oss-cn-shenzhen-internal.aliyuncs.com`。
- 上传：`ossutil cp -r /www/wwwroot/yoji/server/media/ oss://yoji-video/media/ --update -j 4`，22 个文件、685,809,300 字节，内网耗时 5.2 秒。
- 读权限：桶策略只允许匿名 `oss:GetObject`，资源 `acs:oss:*:*:yoji-video/media/*`；验证缩略图 `200`、视频 `Range` 请求 `206`。
- CORS：`AllowedOrigin=*`、`GET/HEAD/POST/PUT`、`AllowedHeader=*`、暴露 `ETag`/`x-oss-request-id`、600 秒（供后台浏览器直传）。
- 改库：dry-run 确认 6 条 → `--apply` 写库，自动备份 `data/yoji.db.bak-20261115174654`；`pm2 restart yoji_project` 后 `/api/videos` 已返回 OSS 绝对地址。
- 验证：6 个视频 + 6 张缩略图逐个 `curl`，全部 `200`。
- 本地 `server/media`（655MB）暂留作回滚；Nginx `/media/` 仍指向本地目录——线上后台还是旧代码，上传走本地 multipart，等新版部署后再切换。

### 踩坑记录

| 现象 | 原因 | 处理 |
| --- | --- | --- |
| `The bucket you access does not belong to you`（EC 0003-00000001） | RAM 用户对该桶没有任何 OSS 权限时，OSS 用这句笼统提示，不是真的跨账号 | 给用户绑定 OSS 权限后立即恢复 |
| `Put public bucket policy is not allowed`（Ec 0015-00000502） | 新桶默认开启「阻止公共访问」 | 控制台关闭该开关后再写桶策略 |
| `ossutil cors --method put` 报 `Error: EOF` | 该命令要 XML，不是 JSON | 用 `<CORSConfiguration>` XML |

### 还没做

1. ~~把 `server/src/oss.js`、新版 `routes/admin.js`、`yoji-admin` 新页面部署上线~~ —— 已于 2026-11-16 部署（见 `工作流/11-部署与运维记录.md`），`/api/admin/storage` 返回 `mode: oss`；
2. 确认新版稳定后再删本地 `server/media`，并把 Nginx `/media/` 改成 302 兜底；
3. RAM 用户从 `AliyunOSSFullAccess` 收窄为只含 `PutObject/GetObject/ListObjects` 的自定义策略；
4. 可选：买已备案域名接 CDN，把 `--to` 换成 CDN 前缀再跑一次改库脚本。
## 11. 2026-11-16 晚：OSS 返回 `UserDisable`，已临时回滚本地

- 现象：Web 后台「视频管理」能列出 6 条记录，但 6 张缩略图全部加载失败；浏览器报 `net::ERR_BLOCKED_BY_ORB`（跨域图片被 Opaque Response Blocking 拦下，因为返回的是 403 XML）。
- 诊断：
  - 直接 `curl -I https://yoji-video.oss-cn-shenzhen.aliyuncs.com/media/thumbs/...` → `403 Forbidden`，响应体 `Code=UserDisable`、`EC=0003-00000801`；
  - 带签名的 `ossutil stat` 同样 `403 UserDisable`，说明不是桶策略或匿名读的问题；
  - 同一 AK 调 STS `GetCallerIdentity` 仍返回 `200`、`RAMUser`、账号 `1278459111899336`，说明 RAM 用户本身没被删；问题在 OSS 服务/账号层面（常见：欠费停服、违规或安全管控）；
  - 本机 Nginx `https://yoji.zhdstudy.cyou/media/...` 仍 `200`，本地 655MB 文件完整。
- 处置（已执行）：
  1. `server/scripts/revert-media-urls.mjs` 把 `videos.video_url`/`thumb_url` 从 OSS 绝对地址改回 `/media/...`，写库前自动备份 `data/yoji.db.bak-<时间戳>`；
  2. `server/.env` 里 7 个 `OSS_*` 变量整行注释（`# OSS_...`），重启后 `/api/admin/storage` 返回 `mode: "local"`，后台上传自动回落到本地 multipart；
  3. `pm2 restart yoji_project`，`/api/videos` 恢复相对路径；后台视频页 6 张缩略图 `naturalWidth > 0`（1152/960），页面不再显示「直传 OSS」。
- 恢复 OSS 后要做：控制台确认账号/OSS 状态 → 取消 `.env` 注释 → 重新上传新增媒体 → 跑 `rewrite-media-urls.mjs` 改回绝对地址 → 验证 6 个视频 `206`。
- 经验：DB 里存相对路径时，客户端会拼 API 域名，天然具备「切回本机」的能力；迁移方案必须保留这一步回滚脚本，不能只留正向脚本。