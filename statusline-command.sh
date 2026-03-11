#!/bin/bash

# Read JSON input from stdin and parse with python (avoids jq dependency)
input=$(cat)

eval "$(python3 -c "
import json, sys
data = json.loads('''$input''')
model_id = data.get('model', {}).get('id', '')
model = data.get('model', {}).get('display_name', 'Unknown')
cwd = data.get('workspace', {}).get('current_dir', data.get('cwd', ''))
ctx = data.get('context_window', {})
used = ctx.get('used_percentage', '')
total_in = ctx.get('total_input_tokens', 0) or 0
total_out = ctx.get('total_output_tokens', 0) or 0

# Pricing per million tokens (input, output)
pricing = {
    'claude-opus-4': (15.0, 75.0),
    'claude-opus-4-5': (15.0, 75.0),
    'claude-opus-4-6': (15.0, 75.0),
    'claude-sonnet-4': (3.0, 15.0),
    'claude-sonnet-4-5': (3.0, 15.0),
    'claude-sonnet-4-6': (3.0, 15.0),
    'claude-haiku-3-5': (0.8, 4.0),
    'claude-haiku-4': (0.8, 4.0),
}
in_rate, out_rate = next(
    (v for k, v in pricing.items() if k in model_id),
    (3.0, 15.0)
)
cost = (total_in / 1_000_000) * in_rate + (total_out / 1_000_000) * out_rate

print(f'model={model!r}')
print(f'cwd={cwd!r}')
print(f'used={used!r}')
print(f'total_in={total_in!r}')
print(f'total_out={total_out!r}')
print(f'cost={cost!r}')
" 2>/dev/null)"

# Fallbacks if python parsing failed
model="${model:-Unknown}"
cwd="${cwd:-$(pwd)}"
total_in="${total_in:-0}"
total_out="${total_out:-0}"
cost="${cost:-0}"

# Get git branch (if in a git repo)
if git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
  branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)

  git_status=""
  if [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
    git_status="*"
  fi

  git_info=$(printf "\033[36m%s%s\033[0m" "$branch" "$git_status")
else
  git_info=""
fi

# Format context percentage
if [ -n "$used" ]; then
  context_info=$(printf "ctx: %.0f%%" "$used")
else
  context_info=""
fi

# Build status line parts
parts=()

# Repo and branch together: ui-react (main*)
repo_name=$(basename "$cwd")
if [ -n "$git_info" ]; then
  parts+=("$(printf "\033[34m%s\033[0m (%s)" "$repo_name" "$git_info")")
else
  parts+=("$(printf "\033[34m%s\033[0m" "$repo_name")")
fi

parts+=("$(printf "\033[33m%s\033[0m" "$model")")

if [ -n "$context_info" ]; then
  parts+=("$(printf "\033[32m%s\033[0m" "$context_info")")
fi

# Format token usage and cost
if [ "$total_in" != "0" ] || [ "$total_out" != "0" ]; then
  in_fmt=$(python3 -c "v=int('${total_in}'); print(f'{v/1000:.1f}k' if v>=1000 else str(v))" 2>/dev/null)
  out_fmt=$(python3 -c "v=int('${total_out}'); print(f'{v/1000:.1f}k' if v>=1000 else str(v))" 2>/dev/null)
  cost_fmt=$(python3 -c "v=float('${cost}'); print(f'\${v:.4f}' if v<0.01 else f'\${v:.2f}')" 2>/dev/null)
  parts+=("$(printf "\033[35min:%s out:%s %s\033[0m" "$in_fmt" "$out_fmt" "$cost_fmt")")
fi

# Join parts with separator
result=""
for i in "${!parts[@]}"; do
  if [ $i -gt 0 ]; then
    result="$result │ "
  fi
  result="$result${parts[$i]}"
done

echo "$result"
