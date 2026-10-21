#!/usr/bin/env bash
# Yoji 后端一键安装脚本（Ubuntu 22.04）
#
# 前置条件：
#   1. 已经通过 scp / git 把整个 server 目录放到 /opt/yoji/server
#   2. 用 root 执行：bash /opt/yoji/server/deploy/install.sh
#
# 脚本会做：安装 Node 24 / Nginx / UFW / sqlite3，建 yoji 用户与目录，
# 安装 npm 依赖，生成 .env 密钥，注册 systemd 服务并启动。
# 域名、HTTPS 证书需要你手工改 Nginx 配置后再启用，见脚本最后的提示。

set -euo pipefail

APP_DIR="/opt/yoji"
SERVER_DIR="$APP_DIR/server"
DATA_DIR="$APP_DIR/data"
MEDIA_DIR="$APP_DIR/media"
BACKUP_DIR="$APP_DIR/backup"

log() { printf '\n\033[1;34m[yoji]\033[0m %s\n' "$*"; }
warn() { printf '\n\033[1;33m[yoji]\033[0m %s\n' "$*"; }
die() { printf '\n\033[1;31m[yoji]\033[0m %s\n' "$*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || die "请用 root 执行：sudo bash $0"

[[ -f "$SERVER_DIR/package.json" ]] || die "没有找到 $SERVER_DIR/package.json，请先把 server 目录上传到 $SERVER_DIR"

log "1/8 安装系统依赖"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl ca-certificates gnupg nginx ufw sqlite3 openssl certbot python3-certbot-nginx

log "2/8 安装 Node.js 24 LTS"
NEED_NODE=1
if command -v node >/dev/null 2>&1; then
  NODE_MAJOR="$(node -p "process.versions.node.split('.')[0]")"
  if [[ "$NODE_MAJOR" -ge 24 ]]; then
    NEED_NODE=0
  fi
fi
if [[ "$NEED_NODE" -eq 1 ]]; then
  curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
  apt-get install -y nodejs
fi
node -v
npm -v

log "3/8 创建运行用户与目录"
if ! id -u yoji >/dev/null 2>&1; then
  useradd --system --home "$APP_DIR" --shell /usr/sbin/nologin yoji
fi
mkdir -p "$DATA_DIR" "$MEDIA_DIR/videos" "$MEDIA_DIR/thumbs" "$BACKUP_DIR"
chown -R yoji:yoji "$DATA_DIR" "$MEDIA_DIR" "$BACKUP_DIR"
chmod 750 "$DATA_DIR" "$BACKUP_DIR"
chmod -R 755 "$MEDIA_DIR"

log "4/8 安装后端依赖"
cd "$SERVER_DIR"
if [[ -f package-lock.json ]]; then
  npm ci --omit=dev --no-audit --no-fund
else
  npm install --omit=dev --no-audit --no-fund
fi

log "5/8 生成 .env"
if [[ -f "$SERVER_DIR/.env" ]]; then
  warn ".env 已存在，跳过生成（如需重置请先备份删除）"
else
  cp "$SERVER_DIR/.env.example" "$SERVER_DIR/.env"
  JWT_SECRET="$(openssl rand -hex 32)"
  ADMIN_TOKEN="$(openssl rand -hex 24)"
  sed -i "s/replace-with-openssl-rand-hex-32/$JWT_SECRET/" "$SERVER_DIR/.env"
  sed -i "s/replace-with-another-random-token/$ADMIN_TOKEN/" "$SERVER_DIR/.env"
  sed -i "s#^DATA_DIR=.*#DATA_DIR=$DATA_DIR#" "$SERVER_DIR/.env"
  sed -i "s#^MEDIA_DIR=.*#MEDIA_DIR=$MEDIA_DIR#" "$SERVER_DIR/.env"
fi
chown root:yoji "$SERVER_DIR/.env"
chmod 640 "$SERVER_DIR/.env"

log "6/8 注册 systemd 服务"
install -m 644 "$SERVER_DIR/deploy/yoji-api.service" /etc/systemd/system/yoji-api.service
systemctl daemon-reload
systemctl enable yoji-api
systemctl restart yoji-api
sleep 1
systemctl --no-pager --full status yoji-api | head -n 12 || true

log "7/8 本机健康检查"
if curl -fsS "http://127.0.0.1:3000/healthz"; then
  echo
else
  warn "健康检查失败，请执行：journalctl -u yoji-api -n 80 --no-pager"
fi

log "8/8 防火墙"
ufw allow OpenSSH >/dev/null || true
ufw allow 80/tcp >/dev/null || true
ufw allow 443/tcp >/dev/null || true
ufw --force enable >/dev/null || true

cat <<EOF

================= 安装完成，还差 3 步 =================

1) 上传视频与封面（在你自己电脑的项目根目录执行）：
   scp entry/src/main/resources/rawfile/anxiety.mp4 root@服务器IP:$MEDIA_DIR/videos/
   scp entry/src/main/resources/rawfile/sloppy.mp4  root@服务器IP:$MEDIA_DIR/videos/
   scp entry/src/main/resources/base/media/video_thumb_anxiety.png root@服务器IP:$MEDIA_DIR/thumbs/
   scp entry/src/main/resources/base/media/video_thumb_sloppy.jpg  root@服务器IP:$MEDIA_DIR/thumbs/
   ssh root@服务器IP "chown -R yoji:yoji $MEDIA_DIR && chmod -R 755 $MEDIA_DIR"

2) 配置域名 + HTTPS（把 api.example.com 换成你的域名，并先解析到服务器 IP）：
   cp $SERVER_DIR/deploy/nginx-yoji-http.conf /etc/nginx/sites-available/yoji-api.conf
   sed -i 's/api.example.com/你的域名/g' /etc/nginx/sites-available/yoji-api.conf
   ln -sf /etc/nginx/sites-available/yoji-api.conf /etc/nginx/sites-enabled/yoji-api.conf
   rm -f /etc/nginx/sites-enabled/default
   mkdir -p /var/www/certbot
   nginx -t && systemctl reload nginx
   # certbot 会自动申请证书并加上 443 与 HTTP 跳转
   certbot --nginx -d 你的域名
   nginx -t && systemctl reload nginx

3) 记下后台管理令牌（后台登录密码 + 视频管理令牌）：
   grep ADMIN_TOKEN $SERVER_DIR/.env
   后台登录账号 admin，密码就是上面的 ADMIN_TOKEN

接口自测：
   curl https://你的域名/healthz
   curl https://你的域名/api/videos

常用命令：
   systemctl status yoji-api
   journalctl -u yoji-api -f
   nginx -t && systemctl reload nginx

EOF
