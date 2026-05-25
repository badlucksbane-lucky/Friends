#!/bin/bash
# llm_call.sh — the single gateway to llama.cpp
# Everything goes through here. Nothing calls llama.cpp directly.
# Usage: echo "your prompt" | llm_call.sh
#        llm_call.sh --what-does-this-tool-do

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/config.sh"
[ -f "$CONFIG" ] && source "$CONFIG"

# Defaults — override in config.sh
MODEL="${LLM_MODEL:-$HOME/models/current.gguf}"
CTX_SIZE="${LLM_CTX:-2048}"
TEMP="${LLM_TEMP:-0.7}"
THREADS="${LLM_THREADS:-4}"
GPU_LAYERS="${LLM_GPU_LAYERS:-99}"
LLAMA_BIN="${LLAMA_BIN:-$HOME/llama.cpp/llama-cli}"
MAX_TOKENS="${LLM_MAX_TOKENS:-512}"

# Character budget — leave room for system prompt and response
CHAR_BUDGET=$(( CTX_SIZE * 3 ))

SYSTEM_PROMPT_FILE="$SCRIPT_DIR/system_prompt.txt"
SYSTEM_PROMPT=""
[ -f "$SYSTEM_PROMPT_FILE" ] && SYSTEM_PROMPT="$(cat "$SYSTEM_PROMPT_FILE")"

# Self description
if [ "$1" = "--what-does-this-tool-do" ]; then
  cat <<EOF
{
  "tool": "llm_call",
  "description": "Single gateway to llama.cpp. Accepts a prompt via stdin, returns a JSON response. Handles context trimming automatically. All other tools route through this one.",
  "input": "plain text prompt via stdin",
  "output": "{\"status\": \"ok|error\", \"response\": \"...\", \"tokens_used\": N}",
  "flags": ["--what-does-this-tool-do", "--json (force JSON output mode)"]
}
EOF
  exit 0
fi

# Read prompt from stdin
PROMPT="$(cat)"

if [ -z "$PROMPT" ]; then
  echo '{"status":"error","response":"empty prompt","tokens_used":0}'
  exit 1
fi

# Context trimming — hard truncate to char budget
if [ ${#PROMPT} -gt $CHAR_BUDGET ]; then
  PROMPT="${PROMPT: -$CHAR_BUDGET}"
fi

# JSON output mode
JSON_FLAG=""
if [ "$1" = "--json" ]; then
  JSON_FLAG="Return your response as a valid JSON object only, no other text."
fi

# Build the full prompt
FULL_PROMPT=""
if [ -n "$SYSTEM_PROMPT" ]; then
  FULL_PROMPT="<|system|>${SYSTEM_PROMPT} ${JSON_FLAG}<|end|><|user|>${PROMPT}<|end|><|assistant|>"
else
  FULL_PROMPT="${PROMPT}"
fi

# Call llama.cpp
RAW_RESPONSE=$(
  "$LLAMA_BIN" \
    --model "$MODEL" \
    --ctx-size "$CTX_SIZE" \
    --temp "$TEMP" \
    --threads "$THREADS" \
    --n-gpu-layers "$GPU_LAYERS" \
    --n-predict "$MAX_TOKENS" \
    --no-display-prompt \
    --log-disable \
    -p "$FULL_PROMPT" \
    2>/dev/null
)

EXIT_CODE=$?

if [ $EXIT_CODE -ne 0 ] || [ -z "$RAW_RESPONSE" ]; then
  echo '{"status":"error","response":"llama.cpp call failed","tokens_used":0}'
  exit 1
fi

# Escape response for JSON
ESCAPED=$(echo "$RAW_RESPONSE" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/g' | tr -d '\n')
ESCAPED="${ESCAPED%\\n}"

echo "{\"status\":\"ok\",\"response\":\"${ESCAPED}\",\"tokens_used\":${#FULL_PROMPT}}"
