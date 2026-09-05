#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.20/pkg_decaroforms_1.3.20.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.20.zip" -d "$TMP/c"
C="$TMP/c/administrator/components/com_decaroforms/src/Controller/BuilderController.php"
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"
echo '=== CONTROLLER ==='
nl -ba "$C" | sed -n '1,120p'
echo '=== FORM / TOKEN / SAVE ==='
grep -n -E 'df-builder-form|form.token|task=builder.save|builder.save|addEventListener\(.submit|fetch\(form.action|df-save-top|type="submit"' "$B" | head -n 120 || true
