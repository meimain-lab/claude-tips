#!/bin/sh
# Turn menubar/Resources/app-icon-source.png into AppIcon.icns.
# Needs only tools present with the Command Line Tools: swift, sips, iconutil.
# Usage: scripts/make-app-icon.sh [output.icns]   (default: build/AppIcon.icns)
set -eu

repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_png="$repo_dir/menubar/Resources/app-icon-source.png"
output_icns=${1:-"$repo_dir/build/AppIcon.icns"}

work_dir=$(mktemp -d)
trap 'rm -rf "$work_dir"' EXIT
iconset="$work_dir/AppIcon.iconset"
mkdir -p "$iconset" "$(dirname "$output_icns")"

# 1024 px master on the macOS icon grid (rounded tile, margin, soft shadow).
swift "$repo_dir/scripts/icon-mask.swift" "$source_png" "$work_dir/icon-1024.png"

for size in 16 32 128 256 512; do
    double=$((size * 2))
    sips -z "$size" "$size" "$work_dir/icon-1024.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    sips -z "$double" "$double" "$work_dir/icon-1024.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil --convert icns --output "$output_icns" "$iconset"
echo "已生成：$output_icns"
