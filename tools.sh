#!/bin/bash
# tools.sh — master tool registry. The agent discovers itself through this.
# Usage: tools.sh --list
#        tools.sh --describe "tool_name"
#        tools.sh --call "tool_name" [args...]
#        tools.sh --what-does-this-tool-do

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

TOOLS_DIR="${TOOLS_DIR:-$SCRIPT_DIR}"

if [ "$1" = "--what-does-this-tool-do" ]; then
  cat <<EOF
{
  "tool": "tools",
  "description": "Master tool registry. Discovers all available tools, returns their descriptions and capabilities as JSON. The agent calls this first when it needs to act. New tools dropped in the tools directory are automatically discovered.",
  "input": "flags and arguments",
  "output": "{\"status\": \"ok|error\", \"result\": \"...\"}",
  "flags": ["--list", "--describe tool_name", "--call tool_name [args]", "--what-does-this-tool-do"]
}
EOF
  exit 0
fi

case "$1" in
  --list)
    # Scan tools dir, call --what-does-this-tool-do on each, build manifest
    MANIFEST="["
    FIRST=1
    for TOOL in "$TOOLS_DIR"/*.sh; do
      [ -f "$TOOL" ] || continue
      TOOL_NAME=$(basename "$TOOL" .sh)
      [ "$TOOL_NAME" = "tools" ] && continue
      DESC=$(bash "$TOOL" --what-does-this-tool-do 2>/dev/null)
      [ -z "$DESC" ] && continue
      [ $FIRST -eq 0 ] && MANIFEST="${MANIFEST},"
      MANIFEST="${MANIFEST}${DESC}"
      FIRST=0
    done
    MANIFEST="${MANIFEST}]"
    echo "{\"status\":\"ok\",\"result\":$MANIFEST}"
    ;;
  --describe)
    TOOL="$TOOLS_DIR/$2.sh"
    if [ ! -f "$TOOL" ]; then
      echo "{\"status\":\"error\",\"result\":\"tool not found: $2\"}"
      exit 1
    fi
    DESC=$(bash "$TOOL" --what-does-this-tool-do 2>/dev/null)
    echo "{\"status\":\"ok\",\"result\":$DESC}"
    ;;
  --call)
    TOOL_NAME="$2"
    shift 2
    TOOL="$TOOLS_DIR/$TOOL_NAME.sh"
    if [ ! -f "$TOOL" ]; then
      echo "{\"status\":\"error\",\"result\":\"tool not found: $TOOL_NAME\"}"
      exit 1
    fi
    bash "$TOOL" "$@"
    ;;
  *)
    echo "{\"status\":\"error\",\"result\":\"unknown flag: $1\"}"
    ;;
esac
