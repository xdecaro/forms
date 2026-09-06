#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.49/pkg_decaroforms_1.3.49.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.49.zip" -d "$TMP/component"
cp "$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php" "$ROOT/tools/extracted-1.3.49-builder-default.php.txt"
