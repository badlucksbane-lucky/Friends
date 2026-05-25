#!/bin/bash
# setup.sh — run once to initialize everything
# Usage: bash setup.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "initializing..."

# Create directory structure
mkdir -p "$SCRIPT_DIR/memory"
mkdir -p "$SCRIPT_DIR/tools"
mkdir -p "$SCRIPT_DIR/models"

# Move tools to tools directory
for f in memory.sh dream.sh; do
  [ -f "$SCRIPT_DIR/$f" ] && mv "$SCRIPT_DIR/$f" "$SCRIPT_DIR/tools/$f"
done

# Make everything executable
chmod +x "$SCRIPT_DIR"/*.sh
chmod +x "$SCRIPT_DIR/tools"/*.sh 2>/dev/null

# Init sqlite memory db
sqlite3 "$SCRIPT_DIR/memory/memory.db" "
  CREATE TABLE IF NOT EXISTS memory (
    key TEXT NOT NULL,
    value TEXT NOT NULL,
    updated_at INTEGER DEFAULT (strftime('%s','now'))
  );
" 2>/dev/null

echo "directory structure:"
echo "  $SCRIPT_DIR/"
echo "  ├── talk.sh          ← start here"
echo "  ├── llm_call.sh      ← single gateway to llama.cpp"
echo "  ├── tools.sh         ← tool registry"
echo "  ├── config.sh        ← all settings"
echo "  ├── system_prompt.txt ← living, grows over time"
echo "  ├── memory/"
echo "  │   ├── memory.db    ← persistent memory"
echo "  │   ├── scratchpad.txt"
echo "  │   └── dreams.txt"
echo "  └── tools/"
echo "      ├── memory.sh"
echo "      └── dream.sh"
echo ""
echo "edit config.sh to point to your llama.cpp binary and model"
echo "then: bash talk.sh"
