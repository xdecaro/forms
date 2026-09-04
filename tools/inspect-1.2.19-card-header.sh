#!/usr/bin/env bash
set -euo pipefail
ROOT=/tmp/forms-inspect-1219-header
OUTER="$ROOT/outer"
COMP="$ROOT/component"
OUT="releases/_inspect-1.2.19-card-header.txt"
rm -rf "$ROOT"
mkdir -p "$OUTER" "$COMP"
unzip -q releases/1.2.19/pkg_decaroforms_1.2.19.zip -d "$OUTER"
COM_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'com_decaroforms_*.zip' | head -n1)"
unzip -q "$COM_ZIP" -d "$COMP"
FILE="$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
{
  echo '=== CARD HEADER / BADGE MARKUP ==='
  grep -n -C 10 -E 'df-card|df-badge|<h3|SHORTCODE|df-card-main|df-card-head|df-card-title' "$FILE" | head -n 320 || true
  echo
  echo '=== RESPONSIVE CSS ==='
  grep -n -C 5 -E '@media|df-card|df-badge' "$FILE" | tail -n 360 || true
} > "$OUT"
