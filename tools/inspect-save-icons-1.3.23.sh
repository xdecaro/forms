#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.23/pkg_decaroforms_1.3.23.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.23.zip" -d "$TMP/c"
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"
echo '=== BUILDER TOP ==='
sed -n '1,90p' "$B"
echo '=== SAVE SCRIPT ==='
sed -n '860,945p' "$B"
