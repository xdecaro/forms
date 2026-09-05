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
H="$TMP/c/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
echo '=== HIDDEN / FIELDS JSON ==='
grep -n -E 'fields_json|layout_json|selectedFields|sync\(|JSON.stringify|builderForm|FormData|requestSubmit|submit' "$B" | head -n 260 || true
echo '=== CONTROLLER SAVE ==='
sed -n '1,240p' "$C"
echo '=== HELPER SAVE/FIELDS ==='
grep -n -E 'fields|layout|save|upsert|insert|update|json' "$H" | head -n 260 || true
echo '=== UI ICON / EMOJI MARKUP ==='
grep -n -E '💾|🗑|✎|✏|📋|×|df-save-structure|data-remove|data-delete|trash|copy|pencil|save' "$B" | head -n 320 || true
