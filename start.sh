#!/bin/bash
set -e

echo "🚀 Starting X-UI..."

export NGINX_PORT=3000
cd /usr/local/x-ui

./x-ui setting -port 2053 -webBasePath /managepanel/ || true
envsubst '${NGINX_PORT}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# نصب پایتون
if ! command -v python3 &> /dev/null; then
    apk add --no-cache python3 py3-pip
    pip3 install requests --break-system-packages
fi

# دانلود sync.py از ریپو
curl -s -o /sync.py https://raw.githubusercontent.com/TheOffend3r/3x-ui/main/sync.py

# برگردوندن اطلاعات
echo "⬇️ Restoring database..."
python3 /sync.py

# بک‌آپ هر ۱ دقیقه (با nohup که بعد از exec هم بمونه)
nohup bash -c 'while true; do python3 /sync.py; sleep 60; done' > /var/log/sync.log 2>&1 &

./x-ui &
nginx -t
exec nginx -g "daemon off;"
