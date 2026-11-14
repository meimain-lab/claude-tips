#!/bin/sh
# Copy content/tips.json into the pane mod as its bundled fallback copy.
# The copy is generated: never edit pane/assets/tips.json by hand.
set -eu
repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
python3 "$repo_dir/scripts/validate-tips.py" "$repo_dir/content/tips.json"
mkdir -p "$repo_dir/pane/assets"
cp "$repo_dir/content/tips.json" "$repo_dir/pane/assets/tips.json"
echo "已同步：pane/assets/tips.json"
