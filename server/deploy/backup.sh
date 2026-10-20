#!/usr/bin/env bash
# SQLite 每日备份：建议用 root 的 crontab 每天 03:30 执行
#   (crontab -l 2>/dev/null; echo "30 3 * * * /opt/yoji/server/deploy/backup.sh") | crontab -
set -euo pipefail

DATA_DIR="${DATA_DIR:-/opt/yoji/data}"
BACKUP_DIR="${BACKUP_DIR:-/opt/yoji/backup}"
KEEP_DAYS="${KEEP_DAYS:-7}"

mkdir -p "$BACKUP_DIR"
sqlite3 "$DATA_DIR/yoji.db" ".backup '$BACKUP_DIR/yoji-$(date +%F).db'"
find "$BACKUP_DIR" -name 'yoji-*.db' -mtime +"$KEEP_DAYS" -delete

echo "[backup] $(date '+%F %T') -> $BACKUP_DIR/yoji-$(date +%F).db"
