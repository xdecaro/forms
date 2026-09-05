#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.22/pkg_decaroforms_1.3.22.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.22.zip" -d "$TMP/c"
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"
for R in '108,140' '216,316' '600,684' '768,784'; do
  echo "=== CSS $R ==="
  sed -n "${R}p" "$B"
done
