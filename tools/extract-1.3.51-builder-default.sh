#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.51/pkg_decaroforms_1.3.51.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$BASE" -d "$TMP/outer"
COMP="$(find "$TMP/outer" -maxdepth 1 -type f -name 'com_decaroforms_1.3.51.zip' -print -quit)"
test -n "$COMP" && test -f "$COMP"
unzip -q "$COMP" -d "$TMP/component"
SRC="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
test -f "$SRC"
cp "$SRC" "$ROOT/tools/extracted-1.3.51-builder-default.php.txt"
