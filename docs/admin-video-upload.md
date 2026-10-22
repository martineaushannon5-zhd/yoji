# 后台视频上传说明（超时修复）

## 为什么之前一直“请求超时”

后台 Axios 实例全局超时是 **20 秒**：

```ts
timeout: 20000
```

视频文件大、上传时间长，请求在 20 秒被 Axios 主动中断，所以无论怎么重试都失败。Nginx / Node 并没有拒绝。

## 已修改

后台 `/videos/` 的上传请求单独设置：

```ts
timeout: 60 * 60 * 1000
maxBodyLength: Infinity
maxContentLength: Infinity
```

Nginx `/api/`：

```nginx
client_max_body_size 1024m;
client_body_timeout 3600s;
proxy_request_buffering off;
proxy_read_timeout 3600s;
proxy_send_timeout 3600s;
```

Node Multer：

- 视频上限 900MB；
- 封面上限 5MB；
- 只接受 mp4/webm/m4v 和 png/jpg/webp。

## 实测

用 30MB 的 mp4 从浏览器上传：

```text
上传耗时 25.5 秒，成功
```

旧 20 秒超时下这个文件必然失败。

## 如果仍然失败

1. 确认打开的是 `http://120.24.171.99/videos/` 或已刷新的域名页面；
2. 浏览器开发者工具 Network 看 `upload` 请求状态：
   - `413`：Nginx `client_max_body_size` 没生效；
   - `401`：管理员登录过期，重新登录；
   - `timeout`：看是否还加载了旧缓存 JS，强刷 Ctrl+F5；
3. 域名备案期 TLS 可能被重置，先用服务器 IP 访问后台；
4. 超过 900MB 请先压缩/转码，不要直接传原片。
