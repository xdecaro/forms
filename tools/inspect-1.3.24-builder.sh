#!/usr/bin/env bash
set -euo pipefail
BASE="releases/1.3.24/pkg_decaroforms_1.3.24.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.24.zip" -d "$TMP/c"
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"
C="$TMP/c/administrator/components/com_decaroforms/src/Controller/BuilderController.php"
H="$TMP/c/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
echo '=== BUILDER RENDER / SELECTED ==='
grep -n -E 'function render|renderCanvas|renderLayout|selected=|dfBuilderSync|saveDraft|clearDraft|DOMContentLoaded|requestAnimationFrame|renderAll|render\(' "$B" | head -n 220 || true
echo '=== BUILDER AROUND SELECTED ==='
LINE=$(grep -n 'selected=selected.map' "$B" | head -1 | cut -d: -f1 || true); if [ -n "$LINE" ]; then START=$((LINE-80)); [ $START -lt 1 ] && START=1; END=$((LINE+160)); sed -n "${START},${END}p" "$B"; fi
echo '=== BUILDER CUSTOM CODE ==='
grep -n -E 'Codice personalizzato|custom_css|custom_js|CSS personalizzato|JavaScript personalizzato' "$B" | head -n 120 || true
LINE=$(grep -n 'CSS personalizzato' "$B" | head -1 | cut -d: -f1 || true); if [ -n "$LINE" ]; then START=$((LINE-40)); [ $START -lt 1 ] && START=1; END=$((LINE+130)); sed -n "${START},${END}p" "$B"; fi
echo '=== BUILDER FORM/TOKEN ==='
grep -n -E 'df-builder-form|form.token|csrf|token' "$B" | head -n 160 || true
echo '=== CONTROLLER SAVE TOP ==='
sed -n '1,220p' "$C"
echo '=== HELPER VERSION ==='
grep -n 'VERSION' "$H" | head
