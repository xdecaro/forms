#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.34/pkg_decaroforms_1.3.34.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.34.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.34-structure-dnd.txt"
: > "$OUT"
{
 echo '=== move helpers ==='
 grep -n -E "function moveField|function layoutGroups|function renderLayoutCanvas|function normalizeLayoutRows|activeStructureSelection|rowMeta" "$B" | head -n 220
 echo
 echo '=== structure CSS ==='
 grep -n -E "df-layout-section-head|df-layout-row-head|df-layout-section-group|df-layout-row-group" "$B" | head -n 140
 echo
 echo '=== renderLayoutCanvas slice ==='
 L=$(grep -n "function renderLayoutCanvas" "$B"|head -1|cut -d: -f1); sed -n "$((L-30)),$((L+180))p" "$B"
} >> "$OUT"
rm -rf "$ROOT/releases/_upload"
