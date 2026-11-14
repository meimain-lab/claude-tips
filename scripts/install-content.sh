#!/bin/sh
# Install content/tips.json into the runtime folder (~/.claude/claude-tips/).
# Validates first, then overwrites only tips.json. tips.local.json is never touched.
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_file="$repo_dir/content/tips.json"
target_dir="${CLAUDE_TIPS_HOME:-$HOME/.claude/claude-tips}"
target_file="$target_dir/tips.json"

python3 "$repo_dir/scripts/validate-tips.py" "$source_file"

mkdir -p "$target_dir"
# Write to a temp file in the same folder, then rename, so readers never see a half-written file.
temp_file=$(mktemp "$target_dir/.tips.json.XXXXXX")
cp "$source_file" "$temp_file"
chmod 644 "$temp_file"
mv -f "$temp_file" "$target_file"

echo "已安装：$target_file"
if [ -f "$target_dir/tips.local.json" ]; then
  echo "保留本机条目：$target_dir/tips.local.json（未改动）"
fi
