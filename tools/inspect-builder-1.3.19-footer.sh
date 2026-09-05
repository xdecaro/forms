#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.19/pkg_decaroforms_1.3.19.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.19.zip" -d "$TMP/c"
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"
echo '=== CUSTOM CODE / FOOTER MATCHES ==='
grep -n -E 'Codice personalizzato|CUSTOM_CODE|custom_css|custom js|custom_js|df-footer|Sviluppato da|Versione|copyright|CSS personalizzato|df-codearea' "$B" | tail -n 120 || true
echo '=== TAIL BUILDER ==='
tail -n 220 "$B"
