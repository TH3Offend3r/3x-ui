#!/bin/bash
set -e

echo "🚀 Starting X-UI..."

export NGINX_PORT=3000
cd /usr/local/x-ui

./x-ui setting -port 2053 -webBasePath /managepanel/ || true
envsubst '${NGINX_PORT}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# نصب پایتون اگه نیست
if ! command -v python3 &> /dev/null; then
    apk add --no-cache python3 py3-pip
    pip3 install requests --break-system-packages
fi

# دانلود sync.py از ریپو (یا استفاده از فایل محلی)
if [ ! -f /sync.py ]; then
    cp /app/sync.py /sync.py 2>/dev/null || curl -s -o /sync.py https://raw.githubusercontent.com/TheOffend3r/3x-ui/main/sync.py
fi

# برگردوندن اطلاعات از گیت‌هاب
echo "⬇️ Restoring database..."
python3 /sync.py

# اجرای بک‌آپ هر ۱ دقیقه در پس‌زمینه
while true; do
    sleep 60
    python3 /sync.py
done &

./x-ui &
nginx -t
exec nginx -g "daemon off;"
