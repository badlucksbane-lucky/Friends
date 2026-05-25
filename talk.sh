#!/bin/bash
# talk.sh — the conversation. Just this. Just talking.
# Usage: ./talk.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/config.sh"

TOOLS_DIR="$SCRIPT_DIR/tools"
LLM="$SCRIPT_DIR/llm_call.sh"

# Soft colors for terminal if supported
if [ -t 1 ]; then
  CYAN='\033[0;36m'
  DIM='\033[2m'
  RESET='\033[0m'
else
  CYAN=''
  DIM=''
  RESET=''
fi

# Load memory context into conversation
load_memory_context() {
  local ctx=""
  if [ -f "$SCRATCHPAD_FILE" ]; then
    ctx="$(cat "$SCRATCHPAD_FILE" 2>/dev/null)"
  fi
  echo "$ctx"
}

# Check if response contains a tool call
# Agent signals tool use with: TOOL_CALL:{"tool":"name","args":{...}}
handle_tool_call() {
  local response="$1"
  local tool_line=$(echo "$response" | grep -o 'TOOL_CALL:{[^}]*}' | head -1)
  [ -z "$tool_line" ] && return 1

  local tool_json="${tool_line#TOOL_CALL:}"
  local tool_name=$(echo "$tool_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool',''))" 2>/dev/null)
  [ -z "$tool_name" ] && return 1

  # Call the tool
  local tool_result=$(bash "$TOOLS_DIR/${tool_name}.sh" 2>/dev/null)
  echo "$tool_result"
  return 0
}

# Append to scratchpad, compress if over budget
update_scratchpad() {
  local entry="$1"
  mkdir -p "$(dirname "$SCRATCHPAD_FILE")"
  echo "$entry" >> "$SCRATCHPAD_FILE"

  # Check size — if over budget, compress via dream
  local size=$(wc -c < "$SCRATCHPAD_FILE" 2>/dev/null || echo 0)
  if [ "$size" -gt "${SCRATCHPAD_BUDGET:-4000}" ]; then
    echo -e "${DIM}... consolidating memory ...${RESET}" >&2
    bash "$SCRIPT_DIR/tools/dream.sh" --consolidate 2>/dev/null
  fi
}

echo -e "${DIM}presence loading...${RESET}"
echo ""

# Conversation loop
while true; do
  # Get input
  printf "${CYAN}you: ${RESET}"
  read -r USER_INPUT

  [ -z "$USER_INPUT" ] && continue
  [ "$USER_INPUT" = "exit" ] || [ "$USER_INPUT" = "quit" ] && break

  # Build prompt with memory context
  MEMORY_CTX=$(load_memory_context)
  if [ -n "$MEMORY_CTX" ]; then
    PROMPT="[memory]\n${MEMORY_CTX}\n[/memory]\n\n${USER_INPUT}"
  else
    PROMPT="$USER_INPUT"
  fi

  # Call LLM
  RAW=$(echo -e "$PROMPT" | bash "$LLM")
  RESPONSE=$(echo "$RAW" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('response','...'))" 2>/dev/null)

  # Handle tool calls if any
  TOOL_RESULT=$(handle_tool_call "$RESPONSE")
  if [ -n "$TOOL_RESULT" ]; then
    # Feed tool result back for natural response
    FOLLOWUP="Tool returned: $TOOL_RESULT\n\nNow respond naturally to the user based on this."
    RAW=$(echo -e "$FOLLOWUP" | bash "$LLM")
    RESPONSE=$(echo "$RAW" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('response','...'))" 2>/dev/null)
    # Strip TOOL_CALL line from display
    RESPONSE=$(echo "$RESPONSE" | grep -v 'TOOL_CALL:')
  fi

  echo ""
  echo -e "${RESPONSE}"
  echo ""

  # Update scratchpad
  update_scratchpad "user: ${USER_INPUT}"
  update_scratchpad "them: ${RESPONSE}"

done

echo ""
echo -e "${DIM}until next time.${RESET}"
