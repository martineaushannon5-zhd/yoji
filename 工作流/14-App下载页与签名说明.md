# 14. App 下载页与签名说明

> 2026-11-20 · 目标：让用户能从网页拿到 Yoji 鸿蒙安装包，并说清当前为什么还不能“人人可装”。

## 1. 已完成

| 项 | 内容 |
| --- | --- |
| 下载页 | `https://yoji.zhdstudy.cyou/app/`（`/download` 302 到同页） |
| 安装包 | `yoji-1.3.0.hap`，1,451,128 B，SHA-256 `5aac23ab…b538a32` |
| 图标 | 页面与 favicon 都用 `entry/src/main/resources/base/media/appIcon.png` |
| 页面源码 | `deploy/app-download/index.html`（单文件、无构建、移动端优先） |
| 服务端目录 | `/www/wwwroot/yoji-app/{index.html,appicon.png,yoji-1.3.0.hap}` |
| Nginx | `/www/server/panel/vhost/nginx/extension/yoji_project/download.conf`：`location /app/` alias + `location = /download` 302 |
| 管理端入口 | 帮助中心“下载 App”卡片，指向同页 |

部署命令：

```bash
ssh root@120.24.171.99 'mkdir -p /www/wwwroot/yoji-app'
scp deploy/app-download/index.html entry/src/main/resources/base/media/appIcon.png \
    entry/build/default/outputs/default/entry-default-signed.hap root@120.24.171.99:/www/wwwroot/yoji-app/
ssh root@120.24.171.99 'cd /www/wwwroot/yoji-app && mv entry-default-signed.hap yoji-1.3.0.hap && mv appIcon.png appicon.png && chown -R www:www .'
# download.conf 见上，写好后 nginx -t && nginx -s reload
```

验证：

```bash
curl -sI https://yoji.zhdstudy.cyou/app/            # 200 text/html
curl -sI https://yoji.zhdstudy.cyou/download        # 200（302 跟随）
curl -sI https://yoji.zhdstudy.cyou/app/yoji-1.3.0.hap  # 200 application/octet-stream
```

## 2. 关键限制：当前是调试签名

`build-profile.json5` 里 `signingConfigs.default` 指向 `~/.ohos/config/default_*.p7b`，其内容是：

```json
{"type":"debug","bundle-name":"com.example.shixun",
 "debug-info":{"device-ids":["…","…","…"],"device-id-type":"udid"}}
```

也就是说，这个签名**只允许 3 台登记过的设备安装**（当初 DevEco 自动签名时连过的调试机）。其他手机哪怕手动装也会报签名/设备未授权。页面上已明确写“当前为开发调试版”，并给出 `hdc install` 的调试设备步骤。

## 3. 要让普通用户下载安装，需要

1. 在 [AppGallery Connect](https://developer.huawei.com/consumer/cn/service/josp/agc/index.html) 创建应用，`bundleName` 建议改为 `com.yoji.app`（当前 `com.example.shixun` 是示例名，上架前必须改）。
2. 申请**发布证书**与**发布 Profile**（release），在 DevEco 的 `Project Structure → Signing Configs` 里替换 `default`。
3. `hvigorw assembleHap --mode module -p product=default -p buildMode=release`，产物应为 release 签名的 `.hap`。
4. 上传 AGC，走“应用上架审核”，或先用“内部测试”轨发给指定账号。
5. 审核通过后把下载页按钮换成应用市场链接（或保留 HAP 直下 + 市场二选一）。

> 注意：HarmonyOS NEXT 不鼓励侧载未上架应用；即使 release 签名，普通用户仍需通过应用市场安装。HAP 直链更适合内部测试与开发者。

## 4. 待办

- [ ] 改 `bundleName` 为 `com.yoji.app`（会影响已安装调试版的升级路径，需重装一次）。
- [ ] 申请发布证书 / Profile，产出 release HAP。
- [ ] AGC 建应用、填隐私政策与截图、提交审核。
- [ ] 下载页加“应用市场”按钮与版本更新说明。
- [ ] 若上架周期长，可先发“内部测试”邀请链接给 10–20 个真实用户。

## 5. 回滚

- 下载页只是静态目录：删掉 `/www/wwwroot/yoji-app` 与 `download.conf`，`nginx -s reload` 即恢复。
- 不影响 App 本体、后台、API。