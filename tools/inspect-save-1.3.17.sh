#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.17/pkg_decaroforms_1.3.17.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.17.zip" -d "$TMP/c"
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"
C="$TMP/c/administrator/components/com_decaroforms/src/Controller/BuilderController.php"
echo '=== FORM / TOKEN / SAVE BUTTONS ==='
grep -n -E '<form|</form>|form.token|builder.save|df-builder-form|df-save-top|SAVE_FORM|name="task"|name="option"' "$B" | head -n 200 || true
echo '=== CONTROLLER TOKEN CHECK ==='
grep -n -E 'checkToken|save\(|task|author|permission|403|token' "$C" | head -n 200 || true
