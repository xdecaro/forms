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
echo '=== CUSTOM CODE CSS ==='
grep -n -E 'df-custom-code-grid|df-footer|df-codearea' "$B" | head -n 120 || true
echo '=== SECTION 8 + FOOTER ==='
sed -n '870,930p' "$B"
