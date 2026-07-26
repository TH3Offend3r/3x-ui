import os, json, sqlite3, base64, requests, sys
from datetime import datetime

TOKEN = os.environ.get('GITHUB_TOKEN')
REPO = os.environ.get('GITHUB_REPO')
DB_FILE = os.environ.get('GITHUB_FILE', '3xui_data.json')
PANEL_DB = '/etc/x-ui/x-ui.db'

def log(msg):
    print(f"{datetime.now()} - {msg}")

def download():
    url = f"https://api.github.com/repos/{REPO}/contents/{DB_FILE}"
    headers = {"Authorization": f"token {TOKEN}", "Accept": "application/vnd.github+json"}
    r = requests.get(url, headers=headers)
    if r.status_code != 200:
        log(f"❌ GitHub error: {r.status_code}")
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
    log("✅ Database restored from GitHub")
    return True

def upload():
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

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "download":
        download()
    else:
        upload()
