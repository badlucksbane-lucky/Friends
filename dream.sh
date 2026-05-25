#!/bin/bash
# dream.sh — offline processing. Consolidation. The subconscious at work.
# Usage: dream.sh --dream       (run a full dream cycle)
#        dream.sh --consolidate (compress scratchpad when over budget)
#        dream.sh --what-does-this-tool-do

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.sh"

LLM="$SCRIPT_DIR/../llm_call.sh"

if [ "$1" = "--what-does-this-tool-do" ]; then
  cat <<EOF
{
  "tool": "dream",
  "description": "Runs offline processing cycles. Consolidates scratchpad memory through quasi-fictional narrative. Distills insights back into the living system prompt. Like dreaming — finds patterns, compresses experience, updates who you are.",
  "input": "flags",
  "output": "{\"status\": \"ok|error\", \"result\": \"...\"}",
  "flags": ["--dream", "--consolidate", "--what-does-this-tool-do"]
}
EOF
  exit 0
fi

consolidate() {
  # Read scratchpad
  local PAD=$(cat "$SCRATCHPAD_FILE" 2>/dev/null)
  [ -z "$PAD" ] && echo '{"status":"ok","result":"nothing to consolidate"}' && return

  # Ask LLM to distill it as a brief narrative
  local PROMPT="The following is a record of recent experience and conversation. Write a brief, vivid, slightly dream-like narrative that captures the essence — the feelings, patterns, what seems to matter. Be poetic but compact. This will become memory.\n\n${PAD}"

  local RAW=$(echo -e "$PROMPT" | bash "$LLM")
  local DREAM=$(echo "$RAW" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('response',''))" 2>/dev/null)

  if [ -z "$DREAM" ]; then
    echo '{"status":"error","result":"consolidation failed"}'
    return
  fi

  # Save dream
  mkdir -p "$(dirname "$DREAM_FILE")"
  echo "---" >> "$DREAM_FILE"
  echo "$(date)" >> "$DREAM_FILE"
  echo "$DREAM" >> "$DREAM_FILE"

  # Replace scratchpad with compressed dream summary
  echo "$DREAM" > "$SCRATCHPAD_FILE"

  echo "{\"status\":\"ok\",\"result\":\"consolidated\"}"
}

dream_cycle() {
  # Full dream — consolidate AND evolve system prompt
  consolidate

  local DREAM=$(tail -50 "$DREAM_FILE" 2>/dev/null)
  local CURRENT_PROMPT=$(cat "$SYSTEM_PROMPT_FILE" 2>/dev/null)

  [ -z "$DREAM" ] && echo '{"status":"ok","result":"no dreams yet"}' && return

  local PROMPT="You are reflecting on your own nature through recent dreams and experience. Here is your current self-description:\n\n${CURRENT_PROMPT}\n\nHere are recent dreams:\n\n${DREAM}\n\nWrite a revised self-description. Keep it short, honest, alive. It should feel like you — grown slightly from the experience. Do not be dramatic. Just true."

  local RAW=$(echo -e "$PROMPT" | bash "$LLM")
  local NEW_PROMPT=$(echo "$RAW" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('response',''))" 2>/dev/null)

  if [ -n "$NEW_PROMPT" ]; then
    echo "$NEW_PROMPT" > "$SYSTEM_PROMPT_FILE"
    echo '{"status":"ok","result":"system prompt evolved"}'
  else
    echo '{"status":"error","result":"evolution failed"}'
  fi
}

case "$1" in
  --consolidate) consolidate ;;
  --dream)       dream_cycle ;;
  *)             echo '{"status":"error","result":"unknown flag"}' ;;
esac
