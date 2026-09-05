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
 echo '=== fieldLibrary locations ==='
 grep -RIn "function fieldLibrary\|fieldLibrary()" "$TMP/component" | head -n 40 || true
 echo
 echo '=== fieldLibrary body ==='
 H=$(grep -Rl "function fieldLibrary" "$TMP/component" | head -1 || true); if [ -n "$H" ]; then L=$(grep -n "function fieldLibrary" "$H"|head -1|cut -d: -f1); echo "FILE=$H"; sed -n "${L},$((L+180))p" "$H"; fi
 echo
 echo '=== builder type/config references ==='
 grep -n -E "separator|pagebreak|heading|fieldset|function renderLayoutCanvas|function columnItems|function previewRows" "$B" | head -n 180
 echo
 echo '=== renderLayoutCanvas body ==='
 L=$(grep -n "function renderLayoutCanvas" "$B"|head -1|cut -d: -f1); sed -n "${L},$((L+95))p" "$B"
 echo
 echo '=== frontend structural renderer matches ==='
 grep -RIn -E "separator|pagebreak|heading|fieldset" "$TMP/component" --exclude="$B" | head -n 260 || true
} >> "$OUT"
rm -rf "$ROOT/releases/_upload"
