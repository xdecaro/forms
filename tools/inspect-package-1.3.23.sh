#!/usr/bin/env bash
set -euo pipefail
BASE="releases/1.3.23/pkg_decaroforms_1.3.23.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c" "$TMP/s"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.23.zip" -d "$TMP/c"
unzip -q "$TMP/o/plg_system_decaroforms_1.3.23.zip" -d "$TMP/s"
echo '=== OUTER CONTENTS ==='
find "$TMP/o" -maxdepth 2 -type f -printf '%P\n' | sort
echo '=== PACKAGE MANIFEST ==='
sed -n '1,260p' "$TMP/o/pkg_decaroforms.xml"
echo '=== COMPONENT SCRIPT ==='
sed -n '1,420p' "$TMP/c/script.php" || true
echo '=== SYSTEM PLUGIN MANIFEST ==='
find "$TMP/s" -maxdepth 1 -name '*.xml' -print -exec sed -n '1,260p' {} \;
echo '=== FORMS VIEW ==='
sed -n '1,240p' "$TMP/c/administrator/components/com_decaroforms/src/View/Forms/HtmlView.php" || true
