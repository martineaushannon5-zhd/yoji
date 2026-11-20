# 16. App 词表响应超过 5MB，模拟器/真机都回退内置词表

- 日期：2026-11-21
- 影响：鸿蒙 App 启动时拉不到后台词表，词库页只剩内置 `四级核心词 60` / `六级核心词 40`
- 结论：**不是服务端挂了，是 HarmonyOS `http` 默认响应体上限 5MB**

## 现象

用户反馈：以前模拟器和真机都能拿到后台词表，扩充词表后两台设备都拿不到；视频还能正常打开。

App 没有弹错误，只是静默使用 `WordData.ets` 的内置词表，因此看起来像“后台没数据”。

## 证据

模拟器 `hdc shell hilog -x` 原文：

```text
E C015b0/NETSTACK: [http_exec.cpp:297] CURLcode result 23
I C015b0/NETSTACK: size:1425408 ... errCode:2300023, RespCode:200, method:GET
E A03d00/JSAPP: [Api] GET http://120.24.171.99/api/wordbooks/full 请求失败
  code=2300023 message=Failed writing received data to disk/application
W A03d00/JSAPP: [WordData] 远程词表不可用: 无法连接服务器，使用内置词表
```

服务端同时是正常的：

```text
GET /api/wordbooks/full  200
Content-Encoding: gzip
ETag: W/"5a9b9d-..."
解压后 5,938,077 bytes（8 本，37,950 词）
```

关键数字：

| 项目 | 值 |
| --- | ---: |
| HarmonyOS `HttpRequestOptions.maxLimit` 默认值 | 5 × 1024 × 1024 = 5,242,880 |
| 扩充后 `/full` 解压大小 | 5,938,077（超过默认上限） |
| 恢复 CET4 后 `/full` 解压大小 | 6,497,689（9 本，42,488 词） |
| gzip 后传输大小 | 1,811,543 |

`CURLcode 23` 是 `CURLE_WRITE_ERROR`；在 HarmonyOS 对应错误码 `2300023`：**Failed to write the received data to the disk or application**。响应体超过 `maxLimit` 后，网络栈写到上限就中断，并不是网络断开。

## 根因

`entry/src/main/ets/common/Api.ets` 的 `Http.send()` 没有设置 `maxLimit`，使用系统默认 5MB。

词表从 7 本（约 4.7MB）扩充到 8 本（5.94MB）后第一次越界；再加 CET4 后为 6.5MB。因为客户端捕获异常后只 `console.error`，并保留内置词表，用户看到的就是“词表没了”。

## 修复

`entry/src/main/ets/common/Api.ets`：

```ts
// 后台全量词表约 6.5MB；HarmonyOS http 默认 maxLimit 为 5MB，
// 超过后会在写入响应体时报 2300023（CURLcode 23）。
const HTTP_MAX_RESPONSE_BYTES: number = 10 * 1024 * 1024;
```

并在 `Http.send()` 的 `HttpRequestOptions` 中增加：

```ts
maxLimit: HTTP_MAX_RESPONSE_BYTES
```

## 附带修复：CET-4 被隐藏

排查时发现服务端 `word_books` 里 `cet4` 的 `visible=0`（2026-11-20 14:40 被更新过），所以公开 `/api/wordbooks` 只有 8 本。已通过管理员接口恢复：

```http
PATCH /api/admin/wordbooks/cet4
{ "visible": true, "sortOrder": 1 }
```

恢复后：9 本，42,488 词。

## 验证

- `cmd /c build.bat`：`BUILD SUCCESSFUL`，HAP 1.4MB。
- 用 `entry-default-signed.hap` 覆盖安装模拟器（unsigned 会报 `install sign info inconsistent`）。
- 重启 App 后 hilog 不再出现 `2300023` / `WordData 远程词表不可用`。
- App 首页显示 `CET-4 四级词汇 / 4538 词`。
- 词库页可滚到 `TOEFL / GRE / IELTS / 柯林斯五星`，共 9 本。
- 视频列表与 `VideoPlayPage` 正常，`anxiety.mp4` 时长 15:15。
- `server && npm test`：12/12 通过。

## 风险与后续

- `maxLimit` 只解决当前 9 本；如果以后继续加词表超过 10MB，还会复现。更稳的方案是 App 先拉 `/api/wordbooks` 摘要，选中某本时再拉 `/api/wordbooks/:id`，避免一次下载全部单词。
- `fetchWordBooks` 读取超时仍为 30s；6.5MB 在慢网下可能超时，后续可单独提高到 60s 或改成分本加载。
- 真机必须重新用 DevEco 签名安装新 HAP；旧安装包仍会走 5MB 上限。
- 未提交/未推送，等确认后提交到 `sync/2026-11-20`。