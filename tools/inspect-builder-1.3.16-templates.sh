#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.16/pkg_decaroforms_1.3.16.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.16.zip" -d "$TMP/c"
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"
echo '=== TEMPLATE / QUICK MODEL LOGIC ==='
grep -n -E 'data-form-template|templateSet|templates=|template|quick|Modelli rapidi|df-template-row|render.*template|apply.*template|contact|registration|membership|reservation|blank' "$B" | head -n 320 || true
