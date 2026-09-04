#!/usr/bin/env bash
set -euo pipefail
ROOT=/tmp/forms-inspect-1216
OUTER="$ROOT/outer"
COMP="$ROOT/component"
OUT="releases/_inspect-1.2.16-badges.txt"
rm -rf "$ROOT"
mkdir -p "$OUTER" "$COMP"
unzip -q releases/1.2.16/pkg_decaroforms_1.2.16.zip -d "$OUTER"
COM_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'com_decaroforms_*.zip' | head -n1)"
unzip -q "$COM_ZIP" -d "$COMP"
FILE="$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
{
  echo '=== badge CSS ==='
  grep -nE 'df-badge|df-reason|df-on|df-off|dark-theme' "$FILE" || true
} > "$OUT"
