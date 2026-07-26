#!/bin/bash
set -e

echo "🚀 Starting X-UI + GitHub Sync..."

export NGINX_PORT=3000
cd /usr/local/x-ui

# نصب پایتون
if ! command -v python3 &> /dev/null; then
    apk add --no-cache python3 py3-pip
    pip3 install requests --break-system-packages
fi

# کپی sync.py از ریپو
cp /app/sync.py /sync.py 2>/dev/null || true

# برگردوندن اطلاعات از گیت‌هاب
echo "⬇️ Restoring database from GitHub..."
python3 /sync.py download

# بک‌آپ خودکار هر ۱ دقیقه
while true; do
    sleep 60
    python3 /sync.py >> /var/log/sync.log 2>&1
done &

# تنظیمات پنل
./x-ui setting -port 2053 -webBasePath /managepanel/ || true
envsubst '${NGINX_PORT}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

./x-ui &
nginx -t
exec nginx -g "daemon off;"
