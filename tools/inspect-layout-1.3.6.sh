#!/usr/bin/env bash
set -euo pipefail
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q releases/1.3.6/pkg_decaroforms_1.3.6.zip -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.6.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
echo '=== LAYOUT CSS / HTML ==='
grep -n -E 'df-layout-card|df-layout-row|df-layout-new-row|df-layout-empty|df-layout-handle|Impostazioni layout avanzate|Trascina qui un campo' "$B" | head -n 220 || true
echo '=== ADD FIELD / ACCORDION ==='
grep -n -E 'function add\(|openBuilderSection|data-accordion|df-selected-item|scrollIntoView' "$B" | head -n 220 || true
