#!/usr/bin/env bash
set -euo pipefail
ROOT=/tmp/forms-inspect-1215
OUTER="$ROOT/outer"
COMP="$ROOT/component"
OUT="releases/_inspect-1.2.15-forms.txt"
rm -rf "$ROOT"
mkdir -p "$OUTER" "$COMP"
unzip -q releases/1.2.15/pkg_decaroforms_1.2.15.zip -d "$OUTER"
COM_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'com_decaroforms_*.zip' | head -n1)"
unzip -q "$COM_ZIP" -d "$COMP"
ROOTC="$COMP/administrator/components/com_decaroforms"
{
  echo '=== forms/default.php lines 1-260 ==='
  nl -ba "$ROOTC/tmpl/forms/default.php" | sed -n '1,260p'
  echo
  echo '=== language status labels ==='
  grep -RniE 'COM_DECAROFORMS_(ENABLED|DISABLED|CLOSED_REGISTRATIONS|LIMIT_REACHED|DEADLINE_EXPIRED|TEMPORARILY_CLOSED|CUSTOM_MESSAGE|COP)' "$ROOTC/language" || true
} > "$OUT"
