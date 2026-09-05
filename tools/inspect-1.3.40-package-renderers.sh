#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"; VER="1.3.40"; BASE="$ROOT/releases/$VER/pkg_decaroforms_$VER.zip"; TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/all"
unzip -q "$BASE" -d "$TMP/outer"
OUT="$ROOT/tools/inspect-1.3.40-package-renderers.txt"
{
  echo '=== OUTER PACKAGE ==='
  find "$TMP/outer" -maxdepth 2 -type f -printf '%P\n' | sort
  echo '\n=== INNER PACKAGE LAYOUT REFERENCES ==='
} > "$OUT"
for z in "$TMP/outer"/*.zip; do
  [ -f "$z" ] || continue
  n="$(basename "$z" .zip)"; d="$TMP/all/$n"; mkdir -p "$d"; unzip -q "$z" -d "$d"
  {
    echo "\n=== $n ==="
    grep -RInE "config.*layout|layout.*(row|col|width)|\['(row|col|width|layout)'\]|grid-template-columns|gridTemplateColumns|fields_json|config_json" "$d" --include='*.php' --include='*.js' --include='*.mjs' --include='*.xml' || true
  } >> "$OUT"
done
# Include full likely rendering files with relevant terms.
for f in $(grep -RlE "config.*layout|layout.*(row|col|width)|\['(row|col|width|layout)'\]" "$TMP/all" --include='*.php' --include='*.js' 2>/dev/null || true); do
  {
    echo "\n=== FULL RENDER FILE: ${f#$TMP/all/} ==="
    cat "$f"
  } >> "$OUT"
done
rm -rf "$ROOT/releases/_upload"
echo "Wrote $OUT"
