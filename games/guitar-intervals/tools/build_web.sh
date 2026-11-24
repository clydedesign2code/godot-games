#!/usr/bin/env bash
# Usage: GODOT_BIN=godot tools/build_web.sh [output-directory]
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
output_dir="${1:-$project_dir/build/web}"
godot_bin="${GODOT_BIN:-godot}"
version="$("$godot_bin" --version)"
if [[ "$version" != 4.6.2.stable* ]]; then
  echo "Web export requires Godot 4.6.2 stable and its matching Web export template (found $version)." >&2
  exit 1
fi

mkdir -p "$output_dir" "$project_dir/.godot"
output_dir="$(cd "$output_dir" && pwd)"
args=(--headless --path "$project_dir")
"$godot_bin" "${args[@]}" --log-file "$project_dir/.godot/web-export.log" --export-release Web "$output_dir/index.html"
"$godot_bin" "${args[@]}" --log-file "$project_dir/.godot/web-licenses.log" \
  --script res://tools/web_licenses.gd -- "$output_dir/licenses.txt"
