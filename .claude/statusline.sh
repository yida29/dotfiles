#!/bin/bash
input=$(cat)

# Parse JSON
DIR=$(echo "$input" | jq -r '.workspace.current_dir // ""' | xargs basename 2>/dev/null)
MODEL=$(echo "$input" | jq -r '.model.display_name // "Claude"')
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
TOKENS_IN=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
TOKENS_OUT=$(echo "$input" | jq -r '.context_window.current_usage.output_tokens // 0')
CTX_SIZE=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')

# Git branch
CURRENT_DIR=$(echo "$input" | jq -r '.workspace.current_dir // ""')
if [ -n "$CURRENT_DIR" ] && [ -d "$CURRENT_DIR" ]; then
  cd "$CURRENT_DIR" 2>/dev/null
  BRANCH=$(git branch --show-current 2>/dev/null)
fi

# Format cost
COST_FMT=$(printf "\$%.2f" "$COST")

# Format tokens (K units)
TOKENS_IN_K=$(awk "BEGIN {printf \"%.1f\", $TOKENS_IN / 1000}")
TOKENS_OUT_K=$(awk "BEGIN {printf \"%.1f\", $TOKENS_OUT / 1000}")

# Context usage percentage
CTX_PCT=$(awk "BEGIN {printf \"%.0f\", ($TOKENS_IN + $TOKENS_OUT) * 100 / $CTX_SIZE}")

# ANSI colors
CYAN='\033[36m'
YELLOW='\033[33m'
GREEN='\033[32m'
MAGENTA='\033[35m'
BLUE='\033[34m'
DIM='\033[2m'
RESET='\033[0m'

# Build output
OUT="${CYAN}${MODEL}${RESET}"
OUT+=" ${DIM}│${RESET} "
OUT+="${GREEN}${DIR:-unknown}${RESET}"
if [ -n "$BRANCH" ]; then
  OUT+=" ${DIM}(${RESET}${MAGENTA}${BRANCH}${RESET}${DIM})${RESET}"
fi
OUT+=" ${DIM}│${RESET} "
OUT+="${YELLOW}${COST_FMT}${RESET}"
OUT+=" ${DIM}│${RESET} "
OUT+="${BLUE}↑${TOKENS_IN_K}k ↓${TOKENS_OUT_K}k${RESET}"
OUT+=" ${DIM}(${CTX_PCT}%)${RESET}"

echo -e "$OUT"
