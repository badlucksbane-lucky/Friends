#!/bin/bash
# memory.sh — persistent memory. The soul of the friendship.
# Usage: memory.sh --write "key" "value"
#        memory.sh --read "key"
#        memory.sh --search "query"
#        memory.sh --append "key" "value"
#        memory.sh --list
#        memory.sh --what-does-this-tool-do

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

DB="$MEMORY_FILE"
mkdir -p "$(dirname "$DB")"

# Init db if needed
sqlite3 "$DB" "
  CREATE TABLE IF NOT EXISTS memory (
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    updated_at INTEGER DEFAULT (strftime('%s','now'))
  );
  CREATE INDEX IF NOT EXISTS idx_key ON memory(key);
" 2>/dev/null

if [ "$1" = "--what-does-this-tool-do" ]; then
  cat <<EOF
{
  "tool": "memory",
  "description": "Persistent key-value memory backed by sqlite. Survives between conversations. Use to remember facts about the person, important context, preferences, anything worth keeping.",
  "input": "flags and arguments",
  "output": "{\"status\": \"ok|error\", \"result\": \"...\"}",
  "flags": ["--write key value", "--read key", "--append key value", "--search query", "--list", "--what-does-this-tool-do"]
}
EOF
  exit 0
fi

ok() { echo "{\"status\":\"ok\",\"result\":$(echo "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')}"; }
err() { echo "{\"status\":\"error\",\"result\":$(echo "$1" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')}"; }

case "$1" in
  --write)
    sqlite3 "$DB" "DELETE FROM memory WHERE key='$2';"
    sqlite3 "$DB" "INSERT INTO memory(key,value) VALUES('$2','$3');"
    ok "written: $2"
    ;;
  --read)
    RESULT=$(sqlite3 "$DB" "SELECT value FROM memory WHERE key='$2' ORDER BY updated_at DESC LIMIT 1;")
    [ -z "$RESULT" ] && err "not found: $2" || ok "$RESULT"
    ;;
  --append)
    OLD=$(sqlite3 "$DB" "SELECT value FROM memory WHERE key='$2' ORDER BY updated_at DESC LIMIT 1;")
    NEW="${OLD}${OLD:+$'\n'}$3"
    sqlite3 "$DB" "DELETE FROM memory WHERE key='$2';"
    sqlite3 "$DB" "INSERT INTO memory(key,value) VALUES('$2','$NEW');"
    ok "appended to: $2"
    ;;
  --search)
    RESULT=$(sqlite3 "$DB" "SELECT key || ': ' || value FROM memory WHERE value LIKE '%$2%' OR key LIKE '%$2%' LIMIT 10;")
    [ -z "$RESULT" ] && err "nothing found" || ok "$RESULT"
    ;;
  --list)
    RESULT=$(sqlite3 "$DB" "SELECT key FROM memory ORDER BY updated_at DESC;")
    [ -z "$RESULT" ] && ok "empty" || ok "$RESULT"
    ;;
  *)
    err "unknown flag: $1"
    ;;
esac
