#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
ZIP="$ROOT/releases/1.3.46/pkg_decaroforms_1.3.46.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer"
unzip -q "$ZIP" -d "$TMP/outer"
OUT="$ROOT/tools/inspect-1.3.46-frontend-layout.txt"
: > "$OUT"
for z in "$TMP/outer"/*.zip; do
  d="$TMP/$(basename "$z" .zip)"; mkdir -p "$d"; unzip -q "$z" -d "$d" || continue
  grep -RniE "layout[^\n]{0,80}width|grid-template|flex-basis|config.*layout|layout.*row|layout.*col" "$d" --include='*.php' --include='*.js' --include='*.css' 2>/dev/null | head -n 200 >> "$OUT" || true
  echo "--- PACKAGE $(basename "$z") ---" >> "$OUT"
done
