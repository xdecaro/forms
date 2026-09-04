#!/usr/bin/env bash
set -euo pipefail
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q releases/1.3.5/pkg_decaroforms_1.3.5.zip -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.5.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
H="$TMP/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
echo '=== QUICK TEMPLATE DEFINITIONS ==='
grep -n -E 'formTemplates|data-form-template|function add\(|openBuilderSection' "$B" | head -n 120 || true
echo '=== LIBRARY KEYS ==='
grep -n -E "\['key'=>" "$H" | head -n 180 || true
echo '=== ADD BUTTON BINDING ==='
grep -n -E 'df-add|add\(library|add\(item|onclick=.*add|addEventListener.*add' "$B" | head -n 160 || true
