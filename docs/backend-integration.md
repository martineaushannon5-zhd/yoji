# 前后端对接说明

这份文档说明 `server/` 后端如何与现有 HarmonyOS ArkTS 工程对接，以及改造后需要检查的地方。

> **2026-10-20 更新**：前端已合并同事的 v1.2.0（`0484a76`），本文的接口约定、HTTP IP 临时方案、TLS/备案说明仍然适用。
> 新增的 `nickname/gender/birthday/favoriteVideos/customWords` 云端字段与合并细节见 [v1.2.0-merge.md](v1.2.0-merge.md)。

## 一、这次改了哪些前端文件

| 文件 | 作用 |
| --- | --- |
| `entry/src/main/module.json5` | 新增 `ohos.permission.INTERNET` 网络权限；引用 `network_config` |
| `entry/src/main/resources/base/profile/network_config.json` | 临时允许明文 HTTP（切换回 HTTPS 后可删除） |
| `entry/src/main/ets/common/Config.ets` | 后端 `API_BASE_URL`（当前为临时方案 `http://120.24.171.99`） |
| `entry/src/main/ets/common/Api.ets` | 基于 `@kit.NetworkKit` 的 HTTP 客户端：登录、注册、进度、视频列表 |
| `entry/src/main/ets/common/CloudSync.ets` | 云端同步：启动/登录时拉取合并，学习时 1.5s 防抖推送 |
| `entry/src/main/ets/model/ProgressModel.ets` | 与后端一致的进度快照类型 |
| `entry/src/main/ets/model/VideoModel.ets` | `thumb` / `src` 改为 `ResourceStr`，支持 http(s) 链接 |
| `entry/src/main/ets/data/VideoData.ets` | 后端视频 DTO → 页面模型；保留远程兜底列表 |
| `entry/src/main/ets/store/Store.ets` | 增加进度快照导出/应用、云端版本号、保存回调；修复连续天数统计 |
| `entry/src/main/ets/pages/LoginPage.ets` | 删除本地模拟登录，改调真实接口；登录后自动同步进度 |
| `entry/src/main/ets/pages/SplashPage.ets` | 注册上云回调；已登录时静默同步云端 |
| `entry/src/main/ets/pages/Index.ets` | 监听云端同步完成标记，自动刷新首页统计 |
| `entry/src/main/ets/pages/AboutPage.ets` | 清空学习记录时同步清空云端 |
| `entry/src/main/ets/view/MineView.ets` | 展示后端头像、增加退出登录 |
| `entry/src/main/ets/view/VideoListView.ets` | 启动时拉取后端视频列表，失败时回退到远程兜底列表 |
| `entry/src/main/ets/pages/FavoriteVideoPage.ets` | v1.2.0 新增：喜欢的视频；进入时补拉远端列表并接云端收藏 |
| `entry/src/main/ets/pages/ProfileEditPage.ets` | v1.2.0 新增：编辑资料；头像本地保存，昵称/性别/生日随进度同步 |

## 二、配置后端地址

打开 `entry/src/main/ets/common/Config.ets`。当前为了绕开域名备案拦截，临时使用「公网 IP + HTTP」：

```ts
export const API_BASE_URL: string = 'http://120.24.171.99';
```

**注意：**

- `yoji.zhdstudy.cyou` 在大陆阿里云服务器上未备案，`http://域名/...` 会返回阿里云备案拦截页（`Server: Beaver`，`Non-compliance ICP Filing`），根本到不了后端；所以不能把地址写成 `http://yoji.zhdstudy.cyou`。
- `http://120.24.171.99` 已在模拟器上验证：注册、登录、视频列表、封面、视频 Range 请求都正常。
- 这是**只适合课程演示的临时方案**：密码和 token 明文传输，不能正式上线。
- 明文 HTTP 依赖 `entry/src/main/resources/base/profile/network_config.json`（`cleartextTrafficPermitted: true`）和 `module.json5` 里的 `ohos.net.networkSecurityConfig` 元数据；以后切回 HTTPS 时把这两处一起删掉，避免 App 继续允许明文流量。
- 正式方案见第七节：备案域名 + HTTPS，或把后端迁到境外/香港。

修改后必须：

1. DevEco Studio 里 **Build → Clean Project**；
2. 重新 Build HAP；
3. 真机上先**卸载旧 App**，再安装新包（或确认覆盖安装成功）。

注意事项：

- **末尾不要带 `/`**；
- 路径不需要改：`Api.ets` 会自动拼 `/api/auth/register`、`/api/auth/login` 等；
- 视频已经全部改为服务器链接，本地 rawfile 不再打包大视频；后端不可用时视频列表会回退到“远程兜底列表”，但同样需要网络。

## 三、联调顺序

1. 按 `server/README.md` 在服务器上把后端跑起来；
2. 用 IP 验证接口：`curl http://120.24.171.99/healthz` 返回 `{"status":"ok"}`；
3. `curl http://120.24.171.99/api/videos` 能看到两条视频；
4. 确认 `Config.ets` 里是 `http://120.24.171.99`；
5. DevEco Studio 重新构建、真机/模拟器运行；
6. 注册一个账号 → 学几个词 → 杀掉 App 重开 → 进度应还在；
7. 用另一台设备/模拟器登录同一账号 → 进度应合并过来。

## 四、同步逻辑（重要）

- **登录 / 冷启动**：`CloudSync.bootstrap()`
  - 云端为空 → 把本地快照推上去；
  - 本地没有学习数据 → 直接采用云端；
  - 两边都有 → 调 `/api/progress/sync` 做并集合并，把权威结果写回本地。
- **学习过程中**：`Store.save()` 之后通过 `onSaved` 回调触发 `CloudSync.schedulePush()`，1.5 秒防抖后推一次，避免每滑一个词就发请求。
- **退出登录**：先把最新进度推上去，再让服务端把旧 token 全部作废。
- **清空学习记录**：`force=true` 覆盖云端，避免下次登录又被并集合并回来。

合并规则见 `server/src/progress.js`：状态取更高一级、学习记录/收藏取并集、计数取较大值。

## 五、视频链接怎么切

后端数据库只存链接，不再把 mp4 打进安装包。两条视频默认指向：

```
/media/videos/anxiety.mp4
/media/videos/sloppy.mp4
/media/thumbs/video_thumb_anxiety.png
/media/thumbs/video_thumb_sloppy.jpg
```

App 会把 `/` 开头的相对路径自动拼成 `http(s)://当前 API 地址/media/...`（当前是 `http://120.24.171.99/media/...`）。

以后换 CDN 或对象存储，只需要调后台接口改链接（不用发版）：

```bash
curl -X PATCH https://你的域名/api/admin/videos/ted-anxiety \
  -H "Content-Type: application/json" \
  -H "X-Admin-Token: 你的ADMIN_TOKEN" \
  -d '{"videoUrl":"https://cdn.example.com/ted/anxiety.mp4"}'
```

新增视频同理，用 `POST /api/admin/videos`。

### 本地大视频已移除

`entry/src/main/resources/rawfile/` 下的 `anxiety.mp4`（约 39 MB）和 `sloppy.mp4`（约 78 MB）已经删除，封面图也改成服务器链接，安装包因此减少约 **118 MB**。

`VideoData.ets` 里的兜底列表会随 `API_BASE_URL` 自动生成，当前指向：

```
http://120.24.171.99/media/videos/anxiety.mp4
http://120.24.171.99/media/videos/sloppy.mp4
```

以后如果服务器域名或 CDN 变化，优先改后台数据库里的 `videoUrl`（App 不用发版）；兜底列表只在 `/api/videos` 请求失败时使用。

## 六、常见问题

**Q：登录一直提示“无法连接服务器”？**

按这个顺序排查，基本能定位到具体环节：

1. **确认包里用的是当前地址**：`Config.ets` 应为 `http://120.24.171.99`（临时方案），不能是 `https://yoji.zhdstudy.cyou` 或 `api.example.com`，末尾不能有 `/`。改完要 **Clean Project → 重新 Build → 卸载旧 App → 安装新包**，否则手机上跑的还是旧包。
2. **用手机浏览器验证**：打开 `http://120.24.171.99/api/videos`。
   - 能看到 JSON（两条视频）→ 手机网络和 API 都正常，问题在 App 包或代码；
   - 打不开 → 看手机是否开了代理/VPN、是否禁止明文 HTTP，换 Wi-Fi/流量再试。
   - 注意：`http://yoji.zhdstudy.cyou/api/videos` 会返回阿里云备案拦截页（403），这是域名未备案，不是 App 问题。
3. **在服务器上直接打接口**，区分“后端挂了”还是“宝塔/WAF 拦了”：

   ```bash
   curl -i http://120.24.171.99/healthz
   curl -i http://120.24.171.99/api/videos

   # 预期 401 + {"code":1002,"message":"账号或密码错误"}，说明 POST 也能通
   curl -i -X POST http://120.24.171.99/api/auth/login \
     -H 'Content-Type: application/json' \
     -d '{"account":"nobody","password":"wrongpass"}'
   ```

   - `healthz` 失败：Node 进程没起，或宝塔反向代理没配好；
   - GET 正常、POST 返回 403/502/HTML：大概率是**宝塔网站防火墙 / WAF / CC 防护**拦了 POST，把 `/api` 加入白名单或对 API 关闭 POST 过滤；
   - POST 返回 404：反向代理把 `/api` 前缀吃掉了，检查代理路径是否保留 `/api`。
   - 用 `https://yoji.zhdstudy.cyou/...` 时如果握手被重置，先看第七节的备案说明。
4. **宝塔面板检查项**：
   - 网站 → 设置 → 反向代理：目标 URL 填 `http://127.0.0.1:3000`，发送域名 `$host`，不要改写 `/api` 路径；
   - 软件商店 → Node 项目/PM2：确认后端进程在运行，端口 `3000` 正在监听；
   - 安全 → 防火墙，以及云厂商安全组：临时方案要放行 **80**；正式 HTTPS 方案放行 443（80 用于证书续期）；
   - 当前用 IP + HTTP 时不经过宝塔 SSL，所以“强制 HTTPS”只对正式域名方案有意义。
5. **看 DevEco 日志**：过滤 `[Api]`，现在失败会打印完整 URL、HTTP 状态和系统错误码；登录页也会显示实际请求地址。
6. 如果切回 HTTPS 后报证书错误：检查手机系统时间是否准确，并确认访问的是域名而不是 IP。

**Q：注册返回 1003？**

账号已存在。账号不区分大小写，换一个即可。

**Q：登录后进度被云端覆盖了？**

服务端只在本地没有学习数据时直接采用云端；两边都有数据会做并集合并。如果你手动清空过本地偏好（清缓存），本地会被视为“新设备”，此时会采用云端数据，这是预期行为。

**Q：视频能播但拖不动进度？**

确认视频由 Nginx 的 `/media/` 提供（而不是 Node）。Nginx 原生支持 `Range`，配置里已经加了 `Accept-Ranges`。

**Q：忘记密码怎么办？**

当前版本没有做找回密码/邮箱验证。可以先用后台 SQL 重置密码（bcrypt 哈希需要在服务器上生成），或者后续加“修改密码”接口。建议下一步补上。

**Q：后端需要装 MySQL 吗？**

不需要。SQLite 单文件就够这个体量，服务器上连数据库服务都不用起，2G 内存更宽裕。

## 七、真机连不上的根因：域名未备案 + 备案拦截

这次问题不是 ArkTS 代码，也不是后端接口。实测结果：

- `http://yoji.zhdstudy.cyou/...` 返回 **403**，响应头 `Server: Beaver`，页面标题 `Non-compliance ICP Filing`，里面跳到 `aliyun.com/beian/beian-block`；
- 这是阿里云对**未备案域名**的拦截，请求根本到不了你的 Nginx / Node；
- 所以把 URL 改成 `http://yoji.zhdstudy.cyou/api/auth/register` 永远不会成功；
- HTTPS 也不稳定：鸿蒙/curl 握手会被重置（HiLog：`CURLcode 35`、`tls:0.000`、`osErr:104`），而 `https://120.24.171.99`（IP、无域名 SNI）以及部分新版浏览器能通，说明拦截层对不同握手/SNI 的处理不一致；
- 结论：**只要域名未备案，这个域名在大陆服务器上的 80/443 都不可靠**，只调 TLS 参数可能今天通、明天又被拦。

### 临时方案（当前代码已采用，仅限课程演示）

用「公网 IP + HTTP」绕过域名备案拦截：

```ts
export const API_BASE_URL: string = 'http://120.24.171.99';
```

已在模拟器实际验证：注册成功、登录成功、视频列表/封面/视频 Range 请求都正常。

但它有硬伤：**密码和 token 明文传输**，容易被抓包；不能作为正式上线方案，也不建议在公共 Wi-Fi 下长期使用。

### 正式方案（二选一）

1. **备案域名 + HTTPS（推荐、合规）**
   - 使用 `.com` / `.cn` 等可备案域名，在阿里云完成 ICP 备案（通常 1–3 周）；
   - 域名解析到 `120.24.171.99`，宝塔配置 SSL；
   - 然后把 `API_BASE_URL` 换回 `https://已备案域名`。
   - 注意：`.cyou` 通常无法完成大陆 ICP 备案，继续用 `yoji.zhdstudy.cyou` 在大陆服务器上会一直被拦。
2. **把后端迁到境外 / 香港服务器**
   - 不需要 ICP，现有 `.cyou` 域名 + HTTPS 可以继续用；
   - 延迟高一些，但课程演示和初期用户够用。

### 如果换回 HTTPS，再检查 TLS 兼容

```bash
# 只允许 TLS1.2：失败说明服务器没开 TLS1.2
curl -I --tlsv1.2 --tls-max 1.2 https://你的已备案域名/healthz

# 只允许 X25519：失败说明服务器只认后量子曲线
openssl s_client -connect 你的已备案域名:443 \
  -servername 你的已备案域名 -groups X25519 </dev/null
```

宝塔 → 网站 → 设置 → **SSL → 高级设置**：同时勾选 TLS 1.2/1.3，关闭“仅 TLS 1.3 / 后量子加密”，加密套件选默认/兼容。站点配置里建议：

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305;
ssl_prefer_server_ciphers on;
ssl_ecdh_curve X25519:prime256v1:secp384r1;
```

改完 `nginx -t && nginx -s reload`。

## 八、当前限制 / 待办

- ArkTS 端已用 DevEco 的 hvigor 编译通过（`BUILD SUCCESSFUL`），并在模拟器上实测：注册、登录、进度同步、视频列表/封面/视频 Range 请求均正常（当前走 `http://120.24.171.99` 临时方案）。
- **域名 `yoji.zhdstudy.cyou` 未备案**，大陆阿里云服务器会拦截 80/443；正式上线必须换备案域名 + HTTPS，或把后端迁到境外/香港。HTTP + IP 只适合课程演示，密码/token 明文传输有安全风险。
- 没有做头像上传，头像目前是后端返回的 URL 字符串（可为空，展示占位图标）。
- 没有做找回密码、邮箱/手机验证码、第三方登录。
- 词库与单词仍写在 `WordData.ets` 里，后续可以改成后端下发。
- 多设备合并是“并集优先”，如果用户想把某个已掌握词降级为学习中，另一台设备上又保留着“已掌握”，合并后可能被抬回已掌握。当前版本接受这个取舍，后续可改为按单词时间戳合并。
