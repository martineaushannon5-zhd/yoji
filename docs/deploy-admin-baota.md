# 把 Yoji Admin 静态站点部署到 https://yoji.zhdstudy.cyou/

> 目标：让 `https://yoji.zhdstudy.cyou/` 打开后直接看到后台首页（Claude 风格预览页）。
> 当前域名根路径返回 `{"code":1007,"message":"接口不存在"}`，说明 Nginx 把 `/` 也代理给 Node 了，需要把根路径改成静态目录。

## 一、构建产物

- 构建目录：`yoji-admin/out/`
- 部署压缩包：`yoji-admin-site.zip`（约 618 KB）
- 压缩包内 **index.html 在根目录**，直接解压到站点根目录即可。

本地重新构建：

```bash
cd yoji-admin
npm install
npm run build
# 产物在 yoji-admin/out/
```

本地预览（不部署也能先看效果）：

```bash
cd yoji-admin
npm start          # http://localhost:4173
```

## 二、上传到服务器

推荐新建一个独立目录，避免覆盖原来的后端/代理文件：

```bash
# 在服务器上
mkdir -p /www/wwwroot/yoji-admin

# 在本机项目根目录上传
scp yoji-admin-site.zip root@120.24.171.99:/www/wwwroot/yoji-admin/

# 在服务器上解压
cd /www/wwwroot/yoji-admin
unzip -o yoji-admin-site.zip
ls -lh index.html _next
```

没有 SSH 权限时，用宝塔 **文件 → 上传** 把 `yoji-admin-site.zip` 传到 `/www/wwwroot/yoji-admin/`，再在宝塔里解压。

## 三、宝塔配置

### 1. 站点根目录

宝塔 → 网站 → `yoji.zhdstudy.cyou` → 设置 → **网站目录**：

- 根目录改成 `/www/wwwroot/yoji-admin`
- 运行目录保持 `/`
- 保存

### 2. 处理反向代理

当前根路径被代理到 Node，所以 `/` 返回接口 404。需要：

- 网站 → 设置 → **反向代理**：删除代理路径为 `/` 的规则；
- 只保留/新增 `/api` 代理到 `http://127.0.0.1:3000`。

> 如果直接用配置文件，确保 `server { }` 里只有一个 `location /`。

### 3. 站点 Nginx 配置参考

在宝塔站点配置文件里，保留原有 `ssl_certificate` / `ssl_certificate_key`，把 location 部分改成：

```nginx
root /www/wwwroot/yoji-admin;
index index.html;

# 静态后台首页 / 后续静态页面
location / {
    try_files $uri $uri/ /index.html;
}

# 后端 API：注意 proxy_pass 末尾不要加 /，否则会丢掉 /api 前缀
location /api/ {
    proxy_pass http://127.0.0.1:3000;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}

# 视频与封面
location /media/ {
    alias /opt/yoji/media/;
    sendfile on;
    add_header Accept-Ranges bytes always;
    add_header Cache-Control "public, max-age=604800" always;
}

location = /healthz {
    proxy_pass http://127.0.0.1:3000;
}
```

保存后：

```bash
nginx -t && nginx -s reload
```

## 四、验证

```bash
# 首页应返回 HTML，而不是 JSON 404
curl -I https://yoji.zhdstudy.cyou/

# API 仍然正常
curl https://yoji.zhdstudy.cyou/api/videos

# 视频仍然正常
curl -I https://yoji.zhdstudy.cyou/media/videos/anxiety.mp4
```

浏览器打开 `https://yoji.zhdstudy.cyou/`，应看到：

- 纸张底色 `#F9F8F6`
- 深咖色文字 `#2D2A26`
- 赤陶色强调 `#D97757`
- Lora 衬线标题 + Inter 正文
- 三张设计令牌卡片与基础组件预览

## 五、注意

1. **当前只是阶段一首页**，没有登录/数据请求；后面接入 Dashboard 后，前端应使用同源 `/api`（不要从 HTTPS 页面直接请求 `http://120.24.171.99`，会被浏览器 Mixed Content 拦截）。
2. `yoji.zhdstudy.cyou` 未备案，大陆阿里云仍可能拦截 80/443；如果浏览器打不开但服务器本机 `curl` 正常，是备案/网络问题，不是静态文件问题。正式上线需备案域名或迁境外。
3. 每次重新 `npm run build` 后，把新的 `out/` 内容覆盖到 `/www/wwwroot/yoji-admin/` 即可；`_next` 目录要整体覆盖，避免旧 chunk 缓存。
