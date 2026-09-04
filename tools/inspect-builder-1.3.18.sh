#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.18/pkg_decaroforms_1.3.18.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.18.zip" -d "$TMP/c"
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"
echo '=== 680-780 CSS ==='
sed -n '680,780p' "$B"
echo '=== 930-1080 SAVED ==='
sed -n '930,1080p' "$B"
echo '=== 1145-1180 EMAIL ==='
sed -n '1145,1180p' "$B"
