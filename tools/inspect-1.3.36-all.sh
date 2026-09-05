#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.36/pkg_decaroforms_1.3.36.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.36.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.36-all.txt"
: > "$OUT"
{
 echo '=== AI MODAL MARKUP ==='
 grep -n -E "Da pagina salvata|Analizza pagina|df-ai-html-file|df-ai-html-analyze|df-ai-mode" "$B" | head -n 220
 echo
 echo '=== HTML PARSER ==='
 grep -n -E "function aiHtmlParsePage|function aiHtmlLabelFor|function aiHtmlRowToken|function aiHtmlWidth|function aiHtmlControlType|function aiHtmlUploadConfig|querySelectorAll\('form'" "$B" | head -n 260
 L=$(grep -n "function aiHtmlParsePage" "$B"|head -1|cut -d: -f1); [ -n "$L" ] && sed -n "$((L-45)),$((L+90))p" "$B"
 echo
 echo '=== ACCORDION TITLES ==='
 grep -n -E "Quick templates|Field library|Email settings|Validation and confirmation|Custom code|Campi del modulo|Stati e visualizzazione" "$B" | head -n 120
 echo
 echo '=== IT LANGUAGE RELEVANT ==='
 IT="$TMP/component/administrator/components/com_decaroforms/language/it-IT/com_decaroforms.ini"
 grep -n -Ei "quick|template|field library|email|validation|custom|campi|libreria|stati|codice|modelli" "$IT" | head -n 220 || true
 echo
 echo '=== RUNTIME ==='
 grep -n "dfBuilderRuntime" "$B" | tail -n 3
} > "$OUT"
rm -rf "$ROOT/releases/_upload"
