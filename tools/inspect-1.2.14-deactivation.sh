#!/usr/bin/env bash
set -euo pipefail
ROOT=/tmp/forms-inspect-1214
OUTER="$ROOT/outer"
COMP="$ROOT/component"
OUT="releases/_inspect-1.2.14-deactivation.txt"
rm -rf "$ROOT"
mkdir -p "$OUTER" "$COMP"
unzip -q releases/1.2.14/pkg_decaroforms_1.2.14.zip -d "$OUTER"
COM_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'com_decaroforms_*.zip' | head -n1)"
unzip -q "$COM_ZIP" -d "$COMP"
ROOTC="$COMP/administrator/components/com_decaroforms"
{
  echo '=== forms/default.php lines 80-115 ==='
  nl -ba "$ROOTC/tmpl/forms/default.php" | sed -n '80,115p'
  echo
  echo '=== exact closed_reason / closed_message matches ==='
  grep -RniE 'closed_reason|closed_message' "$ROOTC" | head -n 80 || true
} > "$OUT"
