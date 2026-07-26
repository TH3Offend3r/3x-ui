#!/bin/bash
set -e

echo "🚀 Starting X-UI..."

export NGINX_PORT=3000
cd /usr/local/x-ui

./x-ui setting -port 2053 -webBasePath /managepanel/ || true
envsubst '${NGINX_PORT}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

./x-ui &
nginx -t
exec nginx -g "daemon off;"
