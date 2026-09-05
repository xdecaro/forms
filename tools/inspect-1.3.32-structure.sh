#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.32/pkg_decaroforms_1.3.32.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.32.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.32-structure.txt"
: > "$OUT"
{
 echo '=== library / structure definitions ==='
 grep -n -E "heading|fieldset|separator|category:'structure'|category:\"structure\"|const library|library=|types:" "$B" | head -n 160
 echo
 echo '=== renderLayoutCanvas ==='
 start=$(grep -n "function renderLayoutCanvas" "$B" | head -1 | cut -d: -f1); if [ -n "$start" ]; then sed -n "${start},$((start+120))p" "$B"; fi
 echo
 echo '=== column exclusion / structural filters ==='
 grep -n -E "separator|pagebreak|heading|fieldset|columnItems|filter\(x=>!\[" "$B" | head -n 120
 echo
 echo '=== component frontend files ==='
 find "$TMP/component" -type f | grep -E '/site/|/components/com_decaroforms/' | head -n 100
 echo
 echo '=== frontend render references ==='
 grep -RIn -E "case ['\"](heading|fieldset|separator)|heading|fieldset|separator|switch.*type|field.type" "$TMP/component/components" "$TMP/component/src" 2>/dev/null | head -n 220 || true
} >> "$OUT"
rm -rf "$ROOT/releases/_upload"
