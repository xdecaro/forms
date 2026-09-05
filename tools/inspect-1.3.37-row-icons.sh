#!/usr/bin/env bash
set -u
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
 L=$(grep -n "function aiHtmlParsePage" "$B"|head -1|cut -d: -f1 || true); if [ -n "${L:-}" ]; then sed -n "${L},$((L+35))p" "$B"; fi
 echo
 echo '=== section helpers ==='
 L=$(grep -n "function aiHtmlSectionCandidates" "$B"|head -1|cut -d: -f1 || true); if [ -n "${L:-}" ]; then sed -n "${L},$((L+45))p" "$B"; fi
 echo
 echo '=== row token / width ==='
 grep -n -E "aiHtmlRowToken|aiHtmlWidth" "$B" | head -30 || true
 echo
 echo '=== uiIcon ==='
 grep -n -E "uiIcon\s*=|uiIcon\(|function[[:space:]]+uiIcon" "$B" | head -50 || true
 echo
 echo '=== icon-only CSS ==='
 grep -n -E "df-icon-only|df-layout-actions|section-actions|row-actions|df-ai-ui-delete" "$B" | head -n 140 || true
 echo
 echo '=== row/section header render ==='
 grep -n -E "sectionActions=|rowHead.innerHTML|data-section-remove|data-canvas-remove" "$B" | head -n 100 || true
 echo
 echo '=== runtime ==='
 grep -n "dfBuilderRuntime" "$B" | tail -1 || true
} >> "$OUT"
rm -rf "$ROOT/releases/_upload"
