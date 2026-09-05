#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.37/pkg_decaroforms_1.3.37.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.37.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.37-row-icons.txt"
: > "$OUT"
{
 echo '=== aiHtmlParsePage ==='
 L=$(grep -n "function aiHtmlParsePage" "$B"|head -1|cut -d: -f1); sed -n "${L},$((L+30))p" "$B"
 echo
 echo '=== section helpers ==='
 L=$(grep -n "function aiHtmlSectionCandidates" "$B"|head -1|cut -d: -f1); sed -n "${L},$((L+40))p" "$B"
 echo
 echo '=== row token / width ==='
 grep -n -E "function aiHtmlRowToken|function aiHtmlWidth" "$B" | head -20
 echo
 echo '=== uiIcon ==='
 L=$(grep -n "function uiIcon" "$B"|head -1|cut -d: -f1); sed -n "${L},$((L+28))p" "$B"
 echo
 echo '=== icon-only CSS ==='
 grep -n -E "df-icon-only|df-layout-actions|section-actions|row-actions" "$B" | head -n 100
 echo
 echo '=== row/section header render ==='
 grep -n -E "sectionActions=|rowHead.innerHTML|data-section-remove|data-canvas-remove" "$B" | head -n 80
 echo
 echo '=== runtime ==='
 grep -n "dfBuilderRuntime" "$B" | tail -1
} >> "$OUT"
rm -rf "$ROOT/releases/_upload"
