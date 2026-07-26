#!/bin/bash
set -e

echo "🚀 Starting X-UI..."

export NGINX_PORT=3000
cd /usr/local/x-ui

# نصب پایتون (اگه نیست)
if ! command -v python3 &> /dev/null; then
    apk add --no-cache python3 py3-pip
    pip3 install requests --break-system-packages
fi

# کپی sync.py از ریپو
if [ -f /app/sync.py ]; then
    cp /app/sync.py /sync.py
else
    echo "❌ sync.py not found in /app"
    exit 1
fi

# برگردوندن اطلاعات از گیت‌هاب (فقط موقع دیپلوی)
echo "⬇️ Restoring database from GitHub..."
python3 /sync.py download

# اجرای پنل
./x-ui setting -port 2053 -webBasePath /managepanel/ || true
envsubst '${NGINX_PORT}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

./x-ui &
nginx -t
exec nginx -g "daemon off;"
