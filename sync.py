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
    cursor = conn.cursor()
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';")
    tables = cursor.fetchall()
    data = {}
    for table in tables:
        name = table[0]
        cursor.execute(f"SELECT * FROM {name}")
        rows = cursor.fetchall()
        cursor.execute(f"PRAGMA table_info({name})")
        cols = [c[1] for c in cursor.fetchall()]
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
