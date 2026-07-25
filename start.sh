#!/bin/bash
set -e

echo "🚀 Starting X-UI + nginx reverse proxy..."

export NGINX_PORT=3000
cd /usr/local/x-ui

echo "🔧 Applying panel settings via x-ui CLI..."
./x-ui setting -port 2053 -webBasePath /managepanel/ || true

echo "🔧 Building nginx.conf for fixed port: $NGINX_PORT"
envsubst '${NGINX_PORT}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

echo "▶️  Starting x-ui in background..."
./x-ui &
X_UI_PID=$!
sleep 2

echo "▶️  Starting nginx in foreground on port $NGINX_PORT..."
nginx -t

# ==============================================
# 🔄 بخش خودکار همگام‌سازی با گیت‌هاب
# ==============================================
echo "🔄 Setting up GitHub auto-sync..."

# نصب پایتون و کتابخونه‌ها (اگه نصب نباشه)
if ! command -v python3 &> /dev/null; then
    echo "📦 Installing python3..."
    apk add --no-cache python3 py3-pip
    pip3 install requests --break-system-packages || true
fi

# دانلود sync.py از ریپوی 3xState (اگه نداره)
if [ ! -f /sync.py ]; then
    echo "📥 Downloading sync.py from GitHub..."
    curl -s https://raw.githubusercontent.com/TheOffend3r/3xState/main/sync.py -o /sync.py
fi

# اجرا برای برگردوندن اطلاعات (حالت download)
echo "⬇️ Restoring database from GitHub..."
python3 /sync.py download

# تنظیم کرون‌جاب برای آپلود خودکار هر ۵ دقیقه
echo "⏰ Setting up cron job for auto-sync..."
echo "*/5 * * * * cd / && python3 /sync.py >> /var/log/sync.log 2>&1" > /etc/crontab
crond -f &

echo "✅ Auto-sync setup complete!"
# ==============================================

exec nginx -g "daemon off;"
