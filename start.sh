#!/bin/bash
set -e

echo "🚀 Starting X-UI + GitHub Sync..."

export NGINX_PORT=3000
cd /usr/local/x-ui

# ==============================================
# نصب پایتون
if ! command -v python3 &> /dev/null; then
    apk add --no-cache python3 py3-pip
    pip3 install requests --break-system-packages
fi

# ساخت sync.py
cat > /sync.py << 'EOF'
import os, json, sqlite3, base64, requests
from datetime import datetime

TOKEN = os.environ.get('GITHUB_TOKEN')
REPO = os.environ.get('GITHUB_REPO')
DB_FILE = os.environ.get('GITHUB_FILE', '3xui_data.json')
PANEL_DB = '/etc/x-ui/x-ui.db'

def log(msg):
    print(f"{datetime.now()} - {msg}")

try:
    conn = sqlite3.connect(PANEL_DB)
    c = conn.cursor()
    c.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    tables = c.fetchall()
    data = {}
    for t in tables:
        name = t[0]
        c.execute(f"SELECT * FROM {name}")
        rows = c.fetchall()
        c.execute(f"PRAGMA table_info({name})")
        cols = [col[1] for col in c.fetchall()]
        data[name] = [dict(zip(cols, row)) for row in rows]
    conn.close()
    
    url = f"https://api.github.com/repos/{REPO}/contents/{DB_FILE}"
    headers = {"Authorization": f"token {TOKEN}", "Accept": "application/vnd.github+json"}
    r = requests.get(url, headers=headers)
    sha = r.json().get('sha') if r.status_code == 200 else None
    
    payload = {
        "message": f"Backup {datetime.now()}",
        "content": base64.b64encode(json.dumps(data, indent=2, default=str).encode()).decode()
    }
    if sha: payload["sha"] = sha
    
    r = requests.put(url, headers=headers, json=payload)
    log("✅ Backup OK" if r.status_code in [200, 201] else f"❌ Error: {r.status_code}")
except Exception as e:
    log(f"❌ {e}")
EOF

# ==============================================
# برگردوندن اطلاعات از گیت‌هاب
echo "⬇️ Restoring database from GitHub..."
python3 /sync.py

# ==============================================
# اجرای بک‌آپ خودکار (با while)
echo "🔄 Starting auto-backup (every 1 minute)..."
while true; do
    sleep 60
    python3 /sync.py >> /var/log/sync.log 2>&1
    echo "✅ Backup sent to GitHub"
done &

# ==============================================
./x-ui setting -port 2053 -webBasePath /managepanel/ || true
envsubst '${NGINX_PORT}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

./x-ui &
nginx -t
exec nginx -g "daemon off;"
