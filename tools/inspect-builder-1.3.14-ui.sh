#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.14/pkg_decaroforms_1.3.14.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.14.zip" -d "$TMP/c"
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"
H="$TMP/c/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
C="$TMP/c/administrator/components/com_decaroforms/src/Controller/BuilderController.php"
echo '=== CSS TOKENS ==='
grep -n -E 'df-sub|df-email|df-validation|df-code|df-custom|df-layout-card|df-main-settings|df-condition|df-status|background:#1|background:var\(--bs-dark|#1f2937|#202c3c|#26364a' "$B" | head -n 220 || true
echo '=== FIELD SETTINGS / SAVE TOKENS ==='
grep -n -E 'renderField|field settings|Impostazioni campo|Salva|personalizz|custom field|localStorage|df-field|df-layout|Larghezza|Campo obbligatorio' "$B" | head -n 260 || true
echo '=== SECTION 5-8 HTML ==='
grep -n -E 'Stati e visualizzazione|Impostazioni email|Validazione e conferma|Codice personalizzato|Stati degli invii|Colonne dell.elenco|Controllo dei campi|Conferma dopo|Protezione dagli invii|CSS personalizzato' "$B" || true
echo '=== VERSION ==='
grep -n "public const VERSION" "$H" || true
echo '=== CONTROLLER CUSTOM ==='
grep -n -E 'custom|preset|field|save' "$C" | head -n 180 || true
