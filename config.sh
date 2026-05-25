# config.sh — all settings in one place
# Source this file, never edit the scripts themselves

# Paths
export LLAMA_BIN="$HOME/llama.cpp/llama-cli"
export LLM_MODEL="$HOME/models/current.gguf"
export AGENT_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Model settings
export LLM_CTX=2048
export LLM_TEMP=0.7
export LLM_THREADS=4
export LLM_GPU_LAYERS=99
export LLM_MAX_TOKENS=512

# Memory
export MEMORY_FILE="$AGENT_HOME/memory/memory.db"
export SCRATCHPAD_FILE="$AGENT_HOME/memory/scratchpad.txt"
export DREAM_FILE="$AGENT_HOME/memory/dreams.txt"
export SYSTEM_PROMPT_FILE="$AGENT_HOME/system_prompt.txt"

# Scratchpad size budget in characters before dream compression triggers
export SCRATCHPAD_BUDGET=4000

# Tools directory
export TOOLS_DIR="$AGENT_HOME/tools"
