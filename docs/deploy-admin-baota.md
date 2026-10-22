# 把 Yoji Admin 部署到 https://yoji.zhdstudy.cyou/

> **2026-10-22 已部署完成。**
>
> - 站点根目录：`/www/wwwroot/yoji-admin`
> - Nginx 配置：`/www/server/panel/vhost/nginx/node_yoji_project.conf`
> - `/api/` → `http://127.0.0.1:3000`，`/media/` → `/www/wwwroot/yoji/server/media/`
> - 线上地址：<https://yoji.zhdstudy.cyou/>
>
> 下面是可复现的部署步骤，后续换服务器或重装时使用。

## 一、构建产物

```bash
cd yoji-admin
npm install
npm run build
# 产物：yoji-admin/out/
```

`npm run build` 会读取 `.env.production`，其中 `NEXT_PUBLIC_API_ORIGIN=` 为空，所以前端请求同源：

```
https://yoji.zhdstudy.cyou/api/admin/...
```

不要把生产包构建成 `http://120.24.171.99`，HTTPS 页面会被 Mixed Content 拦截。

本地预览：

```bash
npm start          # http://localhost:4173（仅静态页；登录需要 /api 代理）
```

需要本地联调登录时用 `npm run dev`（`.env.development` 直连远程后端）。

## 二、上传静态文件

仓库根目录已经打好包：**`yoji-admin-site.zip`**（`index.html` 在压缩包根目录）。也可以自己 `npm run build` 后上传 `yoji-admin/out/`。

推荐独立目录，避免覆盖原来的后端/代理文件：

```bash
# 服务器
mkdir -p /www/wwwroot/yoji-admin
cd /www/wwwroot/yoji-admin
unzip -o /path/to/yoji-admin-site.zip
ls index.html _next

# 或者本机直接 scp
scp yoji-admin-site.zip root@120.24.171.99:/www/wwwroot/yoji-admin/
```

没有 SSH 权限时，用宝塔 **文件 → 上传**：把 `yoji-admin-site.zip` 传到 `/www/wwwroot/yoji-admin/` 并在宝塔里解压，确保 `index.html` 直接在该目录下。

## 三、宝塔配置

### 1. 站点根目录

网站 → `yoji.zhdstudy.cyou` → 设置 → **网站目录**：

- 根目录：`/www/wwwroot/yoji-admin`
- 运行目录：`/`
- 保存

### 2. 处理反向代理

当前 `/` 被代理到 Node，导致首页是接口 404。需要：

- 网站 → 设置 → **反向代理**：删除代理路径为 `/` 的规则；
- 保留/新增 `/api` 代理到 `http://127.0.0.1:3000`。

### 3. 站点 Nginx 配置参考

保留宝塔的 `ssl_certificate` / `ssl_certificate_key`，location 部分：

```nginx
root /www/wwwroot/yoji-admin;
index index.html;

# 静态后台
location / {
    try_files $uri $uri/ /index.html;
}

# 后台 API：proxy_pass 末尾不要加 /，保留 /api 前缀
location /api/ {
    client_max_body_size 1024m;
    client_body_timeout 3600s;
    proxy_request_buffering off;
    proxy_pass http://127.0.0.1:3000;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 60s;
}

# 视频 / 封面
location /media/ {
    alias /www/wwwroot/yoji/server/media/;
    sendfile on;
    add_header Accept-Ranges bytes always;
    add_header Cache-Control "public, max-age=604800" always;
}

location = /healthz {
    proxy_pass http://127.0.0.1:3000;
}
```

```bash
nginx -t && nginx -s reload
```

## 四、后端也要更新（否则登录 404）

后台依赖以下新增文件/接口：

- `server/src/routes/adminPanel.js`（新增）
- `server/src/auth.js`（管理员 JWT）
- `server/src/config.js`（`ADMIN_ACCOUNT` / `ADMIN_JWT_TTL`）
- `server/src/app.js`（挂载 `/api/admin/login`、`/api/admin/stats`、`/api/admin/users`）
- `server/src/db.js`（用户列表/删除、昵称回写）
- `server/src/routes/progress.js`（昵称同步）
- `server/src/progress.js`（v1.2.0 新字段）

仓库根目录已经打包 **`yoji-server-update.zip`**（压缩包内为 `src/...`）。在服务器上解压到 Node 项目根目录即可：

```bash
cd /www/wwwroot/yoji/server
unzip -o /path/to/yoji-server-update.zip
```

上传后重启 Node：

```bash
export PATH=/www/server/nodejs/v24.22.0/bin:$PATH
pm2 restart yoji_project --update-env
```

`.env` 确认：

```ini
ADMIN_ACCOUNT=admin
ADMIN_TOKEN=你的随机令牌
ADMIN_JWT_TTL=12h
```

**登录密码就是 `ADMIN_TOKEN`**。

验证：

```bash
curl https://yoji.zhdstudy.cyou/api/videos
curl -X POST https://yoji.zhdstudy.cyou/api/admin/login \
  -H "Content-Type: application/json" \
  -d '{"account":"admin","password":"你的ADMIN_TOKEN"}'
```

## 五、验收

1. 打开 `https://yoji.zhdstudy.cyou/` → Claude 风格首页；
2. 点「进入控制台」→ 登录页；
3. 账号 `admin` + `ADMIN_TOKEN` 登录；
4. 进入 `/dashboard`：3 张卡片 + 14 天趋势面积图；
5. 进入 `/users`：搜索、分页、删除确认；
6. 刷新页面仍保持登录（localStorage token）。

> 当前 `yoji.zhdstudy.cyou` 未备案，大陆阿里云可能拦截 80/443；若服务器本机 `curl` 正常但浏览器打不开，是备案/网络问题，不是静态文件问题。正式上线需备案域名或迁境外。
