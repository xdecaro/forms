#!/usr/bin/env bash
set -euo pipefail
BASE="releases/1.3.23/pkg_decaroforms_1.3.23.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o"
unzip -q "$BASE" -d "$TMP/o"
echo '=== OUTER CONTENTS ==='
find "$TMP/o" -maxdepth 2 -type f -printf '%P\n' | sort
echo '=== PACKAGE MANIFEST CANDIDATES ==='
for f in "$TMP/o"/*.xml "$TMP/o"/*/*.xml; do
  [ -f "$f" ] || continue
  echo "--- ${f#$TMP/o/} ---"
  sed -n '1,260p' "$f"
done
echo '=== PACKAGE PHP / SCRIPT CANDIDATES ==='
for f in "$TMP/o"/*.php; do
  [ -f "$f" ] || continue
  echo "--- ${f#$TMP/o/} ---"
  sed -n '1,320p' "$f"
done
