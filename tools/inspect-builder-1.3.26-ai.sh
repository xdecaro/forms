#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.26/pkg_decaroforms_1.3.26.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$ROOT/tools/inspect-builder-1.3.26-ai"
rm -rf "$OUT"
mkdir -p "$TMP/o" "$TMP/c" "$OUT"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.26.zip" -d "$TMP/c"
cp "$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php" "$OUT/default.php"
find "$TMP/c" -type f | sort > "$OUT/files.txt"
rm -rf "$ROOT/releases/_upload"
