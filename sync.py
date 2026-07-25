cat > sync.py << 'EOF'
import os
import json
import sqlite3
import base64
import requests
import sys
from datetime import datetime

TOKEN = os.environ.get('GITHUB_TOKEN')
REPO = os.environ.get('GITHUB_REPO')
DB_FILE = os.environ.get('GITHUB_FILE', '3xui_data.json')
PANEL_DB = '/etc/x-ui/x-ui.db'

def read_sqlite():
    try:
        conn = sqlite3.connect(PANEL_DB)
        cursor = conn.cursor()
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
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
        return data
    except Exception as e:
        print(f"Error reading DB: {e}")
        return None

def write_sqlite(data):
    try:
        if os.path.exists(PANEL_DB):
            os.remove(PANEL_DB)
        conn = sqlite3.connect(PANEL_DB)
        cursor = conn.cursor()
        for table_name, rows in data.items():
            if not rows: continue
            columns = list(rows[0].keys())
            col_defs = ', '.join([f'"{col}" TEXT' for col in columns])
            cursor.execute(f'CREATE TABLE IF NOT EXISTS "{table_name}" ({col_defs})')
            for row in rows:
                placeholders = ', '.join(['?' for _ in columns])
                values = [row.get(col) for col in columns]
                cursor.execute(f'INSERT INTO "{table_name}" ({", ".join(columns)}) VALUES ({placeholders})', values)
        conn.commit()
        conn.close()
        return True
    except Exception as e:
        print(f"Error writing DB: {e}")
        return False

def read_from_github():
    if not TOKEN or not REPO:
        print("Missing token or repo")
        return None
    url = f"https://api.github.com/repos/{REPO}/contents/{DB_FILE}"
    headers = {"Authorization": f"token {TOKEN}", "Accept": "application/vnd.github+json"}
    try:
        resp = requests.get(url, headers=headers)
        if resp.status_code != 200:
            print(f"GitHub error: {resp.status_code}")
            return None
        content = resp.json()['content']
        decoded = base64.b64decode(content).decode()
        return json.loads(decoded)
    except Exception as e:
        print(f"Error reading from GitHub: {e}")
        return None

def write_to_github(data):
    if not TOKEN or not REPO:
        print("Missing token or repo")
        return False
    url = f"https://api.github.com/repos/{REPO}/contents/{DB_FILE}"
    headers = {"Authorization": f"token {TOKEN}", "Accept": "application/vnd.github+json"}
    try:
        resp = requests.get(url, headers=headers)
        sha = resp.json().get('sha') if resp.status_code == 200 else None
    except:
        sha = None
    content = json.dumps(data, indent=2, default=str)
    encoded = base64.b64encode(content.encode()).decode()
    payload = {"message": f"Auto-sync - {datetime.now()}", "content": encoded}
    if sha:
        payload["sha"] = sha
    resp = requests.put(url, headers=headers, json=payload)
    return resp.status_code in [200, 201]

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "download":
        print("⬇️ Downloading from GitHub...")
        data = read_from_github()
        if data and write_sqlite(data):
            print("✅ Database restored from GitHub")
        else:
            print("❌ Failed to restore")
    else:
        print("⬆️ Uploading to GitHub...")
        data = read_sqlite()
        if data and write_to_github(data):
            print("✅ Backup uploaded to GitHub")
        else:
            print("❌ Failed to upload")
EOF
