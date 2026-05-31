# Restoring Cursor Chat History After Moving a Project

When you move or rename a project folder, Cursor creates a **new workspace storage entry** for the new path, losing the link to the previous chat history. Two things need to be fixed.

---

## What Cursor Stores and Where

| Data | Location |
|---|---|
| Open files / editor state | `~/Library/Application Support/Cursor/User/workspaceStorage/<hash>/state.vscdb` |
| Agent chat history list | Same `state.vscdb` — key: `composer.composerData` → `allComposers` |
| Chat content / plans | `~/.cursor/plans/*.plan.md` |

Each workspace gets a unique `<hash>` folder. The mapping from hash → folder path is in:

```
~/Library/Application Support/Cursor/User/workspaceStorage/<hash>/workspace.json
```

---

## Step 1 — Find the Old and New Workspace Hashes

List all workspace paths to identify old and new hashes:

```bash
for f in ~/Library/Application\ Support/Cursor/User/workspaceStorage/*/workspace.json; do
  echo "$(basename $(dirname $f)): $(cat "$f")"
done
```

Or search by path keyword:

```bash
grep -rl "YourProjectName" \
  ~/Library/Application\ Support/Cursor/User/workspaceStorage/*/workspace.json
```

Note the **old hash** (previous path) and **new hash** (current path).

---

## Step 2 — Create the Merge Script

Save the following as `~/fix-cursor-history.sh`, replacing `OLD_HASH` and `NEW_HASH`:

```bash
#!/bin/bash
OLD_DB="$HOME/Library/Application Support/Cursor/User/workspaceStorage/OLD_HASH/state.vscdb"
NEW_DB="$HOME/Library/Application Support/Cursor/User/workspaceStorage/NEW_HASH/state.vscdb"

echo "Backing up current database..."
cp "$NEW_DB" "${NEW_DB}.pre-merge-bak"

echo "Merging chat history..."
python3 << 'PYEOF'
import sqlite3, json, os

OLD_DB = os.path.expanduser("~/Library/Application Support/Cursor/User/workspaceStorage/OLD_HASH/state.vscdb")
NEW_DB = os.path.expanduser("~/Library/Application Support/Cursor/User/workspaceStorage/NEW_HASH/state.vscdb")

old_conn = sqlite3.connect(OLD_DB)
old_data = json.loads(old_conn.execute("SELECT value FROM ItemTable WHERE key='composer.composerData'").fetchone()[0])
old_conn.close()

new_conn = sqlite3.connect(NEW_DB)
new_data = json.loads(new_conn.execute("SELECT value FROM ItemTable WHERE key='composer.composerData'").fetchone()[0])

new_ids = {c["composerId"] for c in new_data["allComposers"]}
old_unique = [c for c in old_data["allComposers"] if c["composerId"] not in new_ids]
new_data["allComposers"] += old_unique

new_conn.execute(
    "UPDATE ItemTable SET value=? WHERE key='composer.composerData'",
    (json.dumps(new_data),)
)
new_conn.commit()
new_conn.close()

print(f"Done. Total chats restored: {len(new_data['allComposers'])}")
PYEOF
```

---

## Step 3 — Run the Script

> **Cursor must be fully quit before running** (`Cmd+Q`). Open Terminal.app, then:

```bash
chmod +x ~/fix-cursor-history.sh
bash ~/fix-cursor-history.sh
```

Reopen Cursor — the full chat history will appear in the clock/history panel.

---

## Notes

- The script backs up the new database as `.pre-merge-bak` before making any changes
- Chats from after the move stay at the top; old chats are appended below
- The actual chat **content** (`.plan.md` files) lives in `~/.cursor/plans/` and is global — it never needs to be migrated
- This process can be repeated for multiple moved projects — just run the script once per project with the correct hashes
