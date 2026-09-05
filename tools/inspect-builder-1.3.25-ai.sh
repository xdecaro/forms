#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.25/pkg_decaroforms_1.3.25.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$ROOT/tools/inspect-builder-1.3.25-ai"
rm -rf "$OUT"
mkdir -p "$TMP/o" "$TMP/c" "$OUT"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.25.zip" -d "$TMP/c"
cp "$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php" "$OUT/default.php"
cp "$TMP/c/administrator/components/com_decaroforms/decaroforms.xml" "$OUT/decaroforms.xml" 2>/dev/null || true
find "$TMP/c" -type f | sort > "$OUT/files.txt"
grep -RIl -E 'undo|history|Aggiungi campo|addField|builder' "$TMP/c/administrator/components/com_decaroforms" "$TMP/c/media" 2>/dev/null | sort > "$OUT/relevant-files.txt" || true
for f in $(cat "$OUT/relevant-files.txt" 2>/dev/null | head -n 12); do
  rel="${f#$TMP/c/}"
  safe="$(echo "$rel" | tr '/' '_')"
  cp "$f" "$OUT/$safe" 2>/dev/null || true
done
rm -rf "$ROOT/releases/_upload"
