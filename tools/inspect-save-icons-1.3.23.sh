#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.23/pkg_decaroforms_1.3.23.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.23.zip" -d "$TMP/c"
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"
C="$TMP/c/administrator/components/com_decaroforms/src/Controller/BuilderController.php"
V="$TMP/c/administrator/components/com_decaroforms/src/View/Builder/HtmlView.php"
H="$TMP/c/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
echo '=== BUILDER PHP / SELECTED INIT ==='
sed -n '840,980p' "$B"
sed -n '1058,1100p' "$B"
grep -n -E 'let selected|const selected|selected =|selected=|fields|this->fields|json_encode' "$B" | head -n 180 || true
echo '=== BUILDER VIEW ==='
sed -n '1,280p' "$V"
echo '=== CONTROLLER FIELD SAVE ==='
sed -n '110,250p' "$C"
echo '=== UI ICON / EMOJI MARKUP ==='
grep -n -E '💾|🗑|✎|✏|📋|🔒|×|⧉|df-save-structure|data-remove|data-delete|canvas-edit|canvas-duplicate|canvas-remove' "$B" | head -n 320 || true
