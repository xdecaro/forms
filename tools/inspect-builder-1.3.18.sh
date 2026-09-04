#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.18/pkg_decaroforms_1.3.18.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.18.zip" -d "$TMP/c"
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"

echo '=== DRAG / LAYOUT MATCHES ==='
grep -n -E 'dragstart|dragover|dragleave|drop|dataTransfer|df-layout|renderLayout|layout-canvas|layout-row|layout-item|rowIndex|field_width|width' "$B" | head -n 420 || true

echo '=== EDIT / PROPERTY RENDER MATCHES ==='
grep -n -E 'Modifica campo|renderPropert|renderSelected|activeField|data-edit|editField|scrollIntoView|setTimeout|renderEmail|iframe' "$B" | head -n 320 || true

echo '=== DELETE / CONFIRM MATCHES ==='
grep -n -E 'confirm\(|delete|remove|trash|saved-quick|quick-template|status-remove|field-remove|additional.*remove' "$B" | head -n 360 || true

echo '=== CSS RELEVANT ==='
grep -n -E 'df-save-structure|df-btn-primary|df-btn-secondary|df-btn-danger|df-field-badge|df-chip|df-prop|df-inner|df-subaccordion|df-layout-item|df-layout-row|df-layout-drop' "$B" | head -n 420 || true

echo '=== SNIPPET 1080-1450 ==='
sed -n '1080,1450p' "$B"
echo '=== SNIPPET 1450-1870 ==='
sed -n '1450,1870p' "$B"
echo '=== SNIPPET 1870-2280 ==='
sed -n '1870,2280p' "$B"
