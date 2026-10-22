# 宝塔端说明（本次部署后）

## 一、你这边还需要同步改吗？

**不需要。**

这次是在服务器上直接改的 Nginx 站点配置：

```text
/www/server/panel/vhost/nginx/node_yoji_project.conf
```

改完执行了：

```bash
/www/server/nginx/sbin/nginx -t
/www/server/nginx/sbin/nginx -s reload
```

宝塔只是管理这个文件；配置已经生效。你不需要在宝塔里再点一遍“保存”。

## 二、改了什么

```nginx
server_name yoji.zhdstudy.cyou 120.24.171.99;
root /www/wwwroot/yoji-admin;

location / {
    try_files $uri $uri/ /index.html;
}

location /api/ {
    client_max_body_size 1024m;
    client_body_timeout 3600s;
    proxy_request_buffering off;
    proxy_pass http://127.0.0.1:3000;
    proxy_read_timeout 3600s;
    proxy_send_timeout 3600s;
}

location /media/ {
    alias /www/wwwroot/yoji/server/media/;
}
```

- 后台静态文件：`/www/wwwroot/yoji-admin`
- 后端：PM2 `yoji_project`，目录 `/www/wwwroot/yoji/server`
- 媒体：`/www/wwwroot/yoji/server/media`

## 三、什么时候会被覆盖

如果你在宝塔里打开 **网站 → 设置 → 保存**，宝塔可能会按面板里的旧配置重新生成这个文件，把：

- `root` 改回 `/www/wwwroot/yoji/server`
- `/api`、`/media`、上传大小配置覆盖

**建议部署稳定后不要在宝塔里改这个站点的“网站目录/反向代理”并保存。**  
如果必须改，改完把上面的 location 重新贴回去，再 `nginx -t && nginx -s reload`。

## 四、日常操作

| 操作 | 命令/位置 |
| --- | --- |
| 重启后端 | `export PATH=/www/server/nodejs/v24.22.0/bin:$PATH && pm2 restart yoji_project` |
| 查看后端日志 | `pm2 logs yoji_project` |
| 查看 Nginx 配置 | `/www/server/panel/vhost/nginx/node_yoji_project.conf` |
| 后台静态文件 | `/www/wwwroot/yoji-admin` |
| 上传的视频 | `/www/wwwroot/yoji/server/media/videos` |
| 上传的封面 | `/www/wwwroot/yoji/server/media/thumbs` |
| 上传的头像 | `/www/wwwroot/yoji/server/media/avatars` |

## 五、安全组

后台视频上传走 80/443，不需要额外端口。详细规则见 [security-group.md](security-group.md)。
