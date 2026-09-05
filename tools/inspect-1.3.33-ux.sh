#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.33/pkg_decaroforms_1.3.33.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.33.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.33-ux.txt"
: > "$OUT"
{
 echo '=== AI modal HTML + upload rows ==='
 grep -n -E "df-ai-(file|html|drop|mode|workflow)|Analizza pagina|Controlla e mostra|Aggiungi campo|Importa con AI" "$B" | head -n 260
 echo
 echo '=== AI parser upload functions ==='
 L=$(grep -n "function aiHtmlControlType" "$B"|head -1|cut -d: -f1); sed -n "$((L-20)),$((L+85))p" "$B"
 echo
 echo '=== AI preview renderer ==='
 grep -n -E "function aiRenderPreview|ai-preview|Placeholder|Opzioni|confidence" "$B" | head -n 220
 echo
 echo '=== field editor functions ==='
 grep -n -E "function renderSelected|function renderField|function selectField|fieldEditor|Impostazioni campo|data-cfg=|df-field-editor" "$B" | head -n 280
 echo
 echo '=== renderSelected body ==='
 L=$(grep -n "function renderSelected" "$B"|head -1|cut -d: -f1); if [ -n "$L" ]; then sed -n "$L,$((L+190))p" "$B"; fi
 echo
 echo '=== layout accordions ==='
 L=$(grep -n "const layoutSectionState" "$B"|head -1|cut -d: -f1); sed -n "$L,$((L+220))p" "$B"
} >> "$OUT"
rm -rf "$ROOT/releases/_upload"
