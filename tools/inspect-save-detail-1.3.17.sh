#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.17/pkg_decaroforms_1.3.17.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.17.zip" -d "$TMP/c"
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"
C="$TMP/c/administrator/components/com_decaroforms/src/Controller/BuilderController.php"
L="$TMP/c/administrator/language/it-IT/com_decaroforms.ini"
echo '=== CONTROLLER 1-130 ==='
sed -n '1,130p' "$C"
echo '=== BUILDER 740-900 ==='
sed -n '740,900p' "$B"
echo '=== BUILDER 1140-1195 ==='
sed -n '1140,1195p' "$B"
echo '=== LANGUAGE TOKEN/SAVE ==='
grep -n -E 'TOKEN|PERMISSION|SAVE|DRAFT|SESSION' "$L" | head -n 120 || true
