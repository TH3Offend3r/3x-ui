#!/bin/bash
set -e

echo "🚀 Starting X-UI + nginx reverse proxy..."

export NGINX_PORT=3000
cd /usr/local/x-ui

echo "🔧 Applying panel settings via x-ui CLI..."
./x-ui setting -port 2053 -webBasePath /managepanel/ || true

echo "🔧 Building nginx.conf for fixed port: $NGINX_PORT"
envsubst '${NGINX_PORT}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

# ==============================================
echo "🔄 Setting up GitHub auto-sync..."

if ! command -v python3 &> /dev/null; then
    echo "📦 Installing python3..."
    apk add --no-cache python3 py3-pip
    pip3 install requests --break-system-packages || true
fi

cat > /sync.py << 'INNEREOF'
import os, json, sqlite3, base64, requests, sys
from datetime import datetime

TOKEN = os.environ.get('GITHUB_TOKEN')
REPO = os.environ.get('GITHUB_REPO')
DB_FILE = os.environ.get('GITHUB_FILE', '3xui_data.json')
PANEL_DB = '/etc/x-ui/x-ui.db'

def log_msg(msg):
    print(msg)
    try:
        with open('/var/log/sync.log', 'a') as f:
            f.write(f"{datetime.now()} - {msg}\n")
    except:
        pass

try:
    log_msg("🚀 Sync started")
    conn = sqlite3.connect(PANEL_DB)
    cursor = conn.cursor()
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    tables = cursor.fetchall()
    data = {}
    for table in tables:
        table_name = table[0]
        cursor.execute(f"SELECT * FROM {table_name}")
        rows = cursor.fetchall()
        cursor.execute(f"PRAGMA table_info({table_name})")
        columns = [col[1] for col in cursor.fetchall()]
        table_data = []
        for row in rows:
            table_data.append(dict(zip(columns, row)))
        data[table_name] = table_data
    conn.close()
    log_msg(f"📊 Read {len(tables)} tables")
    
    url = f"https://api.github.com/repos/{REPO}/contents/{DB_FILE}"
    headers = {"Authorization": f"token {TOKEN}", "Accept": "application/vnd.github+json"}
    resp = requests.get(url, headers=headers)
    sha = resp.json().get('sha') if resp.status_code == 200 else None
    
    content = json.dumps(data, indent=2, default=str)
    encoded = base64.b64encode(content.encode()).decode()
    payload = {"message": f"Auto-sync - {datetime.now()}", "content": encoded}
    if sha:
        payload["sha"] = sha
    
    resp = requests.put(url, headers=headers, json=payload)
    if resp.status_code in [200, 201]:
        log_msg("✅ Backup uploaded to GitHub")
    else:
        log_msg(f"❌ GitHub error: {resp.status_code}")
        
except Exception as e:
    log_msg(f"❌ ERROR: {e}")
INNEREOF

echo "⬇️ Restoring database from GitHub..."
python3 /sync.py

echo "🔄 Starting auto-sync loop..."
nohup bash -c 'while true; do python3 /sync.py >> /var/log/sync.log 2>&1; sleep 60; done' &

echo "✅ Auto-sync setup complete!"
# ==============================================

echo "▶️  Starting x-ui..."
./x-ui &

echo "▶️  Starting nginx..."
nginx -t
exec nginx -g "daemon off;"
