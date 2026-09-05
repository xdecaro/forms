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
OUT="$ROOT/tools/inspect-1.3.34-drag.txt"
: > "$OUT"
{
 echo '=== drag-related functions ==='
 grep -n -E "dragstart|dragover|drop|dragend|moveField|distributeRow|fieldsInRow|normalizeLayoutRows|renderLayoutFieldCard|renderLayoutCanvas|layoutNewRow|touch|pointer" "$B" | head -n 500
 echo
 echo '=== layout function block ==='
 L=$(grep -n "function normalizeLayoutRows" "$B"|head -1|cut -d: -f1); sed -n "${L},$((L+360))p" "$B"
 echo
 echo '=== drag css ==='
 grep -n -E "df-layout-card|df-layout-row|dragging|is-over|drop-guide|layout-handle|touch" "$B" | head -n 260
 echo
 echo '=== runtime/version ==='
 grep -n "dfBuilderRuntime" "$B" | tail -n 5
} > "$OUT"
rm -rf "$ROOT/releases/_upload"
