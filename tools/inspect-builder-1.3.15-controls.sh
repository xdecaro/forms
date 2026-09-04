#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.15/pkg_decaroforms_1.3.15.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.15.zip" -d "$TMP/c"
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"
echo '=== TOP / TOOLBAR ==='
grep -n -E 'Elenco moduli|Annulla|Ripristina|Bloccato|Modifica|Salva modulo|df-history|df-lock|df-mode|df-toolbar|df-actions|df-builder-head|df-top' "$B" | head -n 260 || true
echo '=== FORM / SAVE ==='
grep -n -E '<form|</form>|task|builder\.save|save|Salva|submit|formToken' "$B" | head -n 260 || true
echo '=== SOURCE 600-735 ==='
sed -n '600,735p' "$B"
echo '=== CLOSED REASON ==='
grep -n -E 'Quando disattivato|Messaggio di chiusura|closed_reason|closure|df-close|df-warning|df-disabled' "$B" | head -n 220 || true
