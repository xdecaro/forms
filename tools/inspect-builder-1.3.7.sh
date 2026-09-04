#!/usr/bin/env bash
set -euo pipefail
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q releases/1.3.7/pkg_decaroforms_1.3.7.zip -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.7.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
echo '=== LIBRARY RENDER ==='
grep -n -E 'renderLibrary|libraryItems|libraryFiltered|df-library-item|df-library-grid|Personalizzati|custom' "$B" | head -n 260 || true
echo '=== SELECTED RENDER/ACTIONS ==='
grep -n -E 'function renderSelected|df-mini-actions|data-act=|data-act\]|data-field-toggle' "$B" | head -n 260 || true
echo '=== LIBRARY STATE ==='
grep -n -E 'const library|let library|library=|libByKey|category|df-library-tab' "$B" | head -n 260 || true
