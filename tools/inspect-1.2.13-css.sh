#!/usr/bin/env bash
set -euo pipefail
ROOT=/tmp/forms-inspect-1213
OUTER="$ROOT/outer"
COMP="$ROOT/component"
rm -rf "$ROOT"
mkdir -p "$OUTER" "$COMP"
unzip -q releases/1.2.13/pkg_decaroforms_1.2.13.zip -d "$OUTER"
COM_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'com_decaroforms_*.zip' | head -n1)"
unzip -q "$COM_ZIP" -d "$COMP"
FORM_VIEW="$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
echo '=== #29333f matches ==='
grep -n -C 2 -F '#29333f' "$FORM_VIEW" || true
echo '=== badge / df-on / df-off CSS matches ==='
grep -n -C 1 -E 'df-badge|df-on|df-off' "$FORM_VIEW" | head -n 240 || true
echo '=== title/card heading CSS matches ==='
grep -n -C 1 -E 'df-card[^,{]*h3|df-card-title|card-head|card-header' "$FORM_VIEW" | head -n 160 || true
echo '=== generic dark not-style rules ==='
grep -n -C 1 -E 'badge:not\(\[style\]\)|not\(\[style\]\).*badge' "$FORM_VIEW" || true
