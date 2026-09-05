#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.35/pkg_decaroforms_1.3.35.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.35.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.35-structure-dnd.txt"
: > "$OUT"
{
 echo '=== structure render and helpers ==='
 grep -n -E "function layoutGroups|function renderLayoutCanvas|function normalizeLayoutRows|function sortSelectedByLayout|function fieldsInRow|activeStructureSelection|rowMeta|smartMove" "$B" | head -n 320
 echo
 L=$(grep -n "function layoutGroups" "$B"|head -1|cut -d: -f1); sed -n "$((L-40)),$((L+260))p" "$B"
 echo
 echo '=== structure CSS ==='
 grep -n -E "df-layout-section-head|df-layout-row-head|df-layout-section-group|df-layout-row-group|df-layout-handle|df-smart" "$B" | head -n 260
 echo
 echo '=== runtime ==='
 grep -n "dfBuilderRuntime" "$B" | tail -n 5
} > "$OUT"
rm -rf "$ROOT/releases/_upload"
