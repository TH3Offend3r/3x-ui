#!/bin/bash
set -e

echo "🚀 Starting X-UI + nginx reverse proxy..."

# nginx همیشه روی پورت ثابت 3000 گوش می‌دهد
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

# ========== اضافه کردن sync ==========
echo "🔄 Setting up GitHub sync..."

# نصب پایتون اگه نیست
if ! command -v python3 &> /dev/null; then
    echo "📦 Installing python3..."
    apk add --no-cache python3 py3-pip
    pip3 install requests --break-system-packages || true
fi

# دانلود و اجرای sync.py
if [ -f /usr/local/x-ui/sync.py ]; then
    cd /usr/local/x-ui
    python3 sync.py &
    echo "*/5 * * * * cd /usr/local/x-ui && python3 sync.py >> /var/log/sync.log 2>&1" > /etc/crontab
    crond -f &
else
    echo "⚠️ sync.py not found in /usr/local/x-ui"
fi

# ========== اجرای nginx ==========
exec nginx -g "daemon off;"
