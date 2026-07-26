#!/bin/bash
set -e

echo "🚀 Starting X-UI..."

export NGINX_PORT=3000
cd /usr/local/x-ui

# نصب پایتون فقط اگه لازم باشه
if ! command -v python3 &> /dev/null; then
    apk add --no-cache python3 py3-pip
    pip3 install requests --break-system-packages
fi

# ساخت sync.py (فقط برای برگردوندن)
cat > /sync.py << 'EOF'
import os, json, sqlite3, base64, requests, sys
from datetime import datetime

TOKEN = os.environ.get('GITHUB_TOKEN')
REPO = os.environ.get('GITHUB_REPO')
DB_FILE = os.environ.get('GITHUB_FILE', '3xui_data.json')
PANEL_DB = '/etc/x-ui/x-ui.db'

def download():
    url = f"https://api.github.com/repos/{REPO}/contents/{DB_FILE}"
    headers = {"Authorization": f"token {TOKEN}", "Accept": "application/vnd.github+json"}
    r = requests.get(url, headers=headers)
    if r.status_code != 200:
        print(f"❌ GitHub error: {r.status_code}")
        return False
    data = json.loads(base64.b64decode(r.json()['content']).decode())
    
    if os.path.exists(PANEL_DB):
        os.remove(PANEL_DB)
    conn = sqlite3.connect(PANEL_DB)
    c = conn.cursor()
    for table_name, rows in data.items():
        if not rows or table_name.startswith('sqlite_'): continue
        cols = list(rows[0].keys())
        col_defs = ', '.join([f'"{col}" TEXT' for col in cols])
        c.execute(f'CREATE TABLE IF NOT EXISTS "{table_name}" ({col_defs})')
        for row in rows:
            placeholders = ', '.join(['?' for _ in cols])
            values = [row.get(col) for col in cols]
            c.execute(f'INSERT INTO "{table_name}" ({", ".join(cols)}) VALUES ({placeholders})', values)
    conn.commit()
    conn.close()
    print("✅ Database restored from GitHub")
    return True

if __name__ == "__main__":
    download()
EOF

# فقط یک بار اطلاعات رو برگردون (هیچ بک‌آپ خودکاری نیست)
python3 /sync.py

# اجرای پنل
./x-ui setting -port 2053 -webBasePath /managepanel/ || true
envsubst '${NGINX_PORT}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

./x-ui &
nginx -t
exec nginx -g "daemon off;"
