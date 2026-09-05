#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.38/pkg_decaroforms_1.3.38.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.38.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.38-smart-add-filters.txt"
: > "$OUT"
{
 echo '=== add/select ==='
 grep -n -E "function add\(|const add=|function selectField|activeStructureSelection" "$B" | head -n 120 || true
 echo
 echo '=== add body context ==='
 L=$(grep -n -E "function add\(|const add=" "$B"|head -1|cut -d: -f1 || true); [ -n "$L" ] && sed -n "$((L-10)),$((L+90))p" "$B" || true
 echo
 echo '=== row move helpers ==='
 grep -n -E "function moveFieldBeside|function moveFieldToRow|function moveFieldToNewRowAfter|function normalizeLayoutRows|function fieldsInRow|function setFieldWidth" "$B" | head -n 120 || true
 for fn in moveFieldBeside moveFieldToRow moveFieldToNewRowAfter normalizeLayoutRows fieldsInRow setFieldWidth; do L=$(grep -n "function $fn" "$B"|head -1|cut -d: -f1 || true); if [ -n "$L" ]; then echo "--- $fn ---"; sed -n "$L,$((L+55))p" "$B"; fi; done
 echo
 echo '=== AI preview toolbar / counters ==='
 grep -n -E "Seleziona tutti|Solo sicuri|aiSelect|aiPreview|duplicat|confidence|da controllare|da verificare" "$B" | head -n 260 || true
 echo
 echo '=== ai prepare/render context ==='
 for fn in aiPrepare aiRenderPreview aiRefreshPreview aiUpdatePreview aiDuplicate; do L=$(grep -n -E "function $fn|const $fn" "$B"|head -1|cut -d: -f1 || true); if [ -n "$L" ]; then echo "--- $fn ---"; sed -n "$L,$((L+100))p" "$B"; fi; done
 echo
 echo '=== runtime ==='
 grep -n "dfBuilderRuntime" "$B" | tail -1 || true
} >> "$OUT"
rm -rf "$ROOT/releases/_upload"
