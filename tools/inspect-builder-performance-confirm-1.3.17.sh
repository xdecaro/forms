#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.17/pkg_decaroforms_1.3.17.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c" "$TMP/p"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.17.zip" -d "$TMP/c"
unzip -q "$TMP/o/plg_content_decaroforms_1.3.17.zip" -d "$TMP/p" 2>/dev/null || true
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"
echo '=== RENDER SELECTED / EDIT ==='
grep -n -E 'function renderSelected|data-edit|activeFieldKey|renderEmailPickers\(|renderLayout\(|df-field-main|Modifica campo' "$B" | head -n 220 || true
echo '=== SUCCESS / CONFIRM FRONTEND COMPONENT ==='
grep -R -n -E 'success_message|confirmation|confirm_position|confirm.*modal|SUCCESS_DEFAULT|closed_message' "$TMP/c" | head -n 240 || true
echo '=== SUCCESS / CONFIRM PLUGIN ==='
grep -R -n -E 'success_message|confirmation|confirm_position|confirm.*modal|SUCCESS_DEFAULT|closed_message' "$TMP/p" | head -n 240 || true
