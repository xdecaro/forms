#!/usr/bin/env bash
set -euo pipefail
BASE="releases/1.3.23/pkg_decaroforms_1.3.23.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.23.zip" -d "$TMP/c"
echo '=== OUTER CONTENTS ==='
find "$TMP/o" -maxdepth 2 -type f -printf '%P\n' | sort
echo '=== PACKAGE MANIFEST CANDIDATES ==='
for f in "$TMP/o"/*.xml "$TMP/o"/*/*.xml; do
  [ -f "$f" ] || continue
  echo "--- ${f#$TMP/o/} ---"
  sed -n '1,260p' "$f"
done
echo '=== FORMS VIEW ==='
sed -n '1,320p' "$TMP/c/administrator/components/com_decaroforms/src/View/Forms/HtmlView.php" || true
echo '=== FORMS DEFAULT TMPL ==='
sed -n '1,420p' "$TMP/c/administrator/components/com_decaroforms/tmpl/forms/default.php" || true
echo '=== COMPONENT MANIFEST ==='
sed -n '1,320p' "$TMP/c/decaroforms.xml" 2>/dev/null || find "$TMP/c" -maxdepth 2 -name '*.xml' -print -exec sed -n '1,220p' {} \;
