#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"; V="1.3.49"; TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$ROOT/releases/$V/pkg_decaroforms_$V.zip" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_$V.zip" -d "$TMP/c"
BASE="$TMP/c/administrator/components/com_decaroforms"
OUT="$ROOT/tools/audit-1.3.49-builder-server-report.txt"
{
 echo "BUILDER SERVER AUDIT $V"
 echo "========================"
 echo
 echo "[CONTROLLER FILES]"
 find "$BASE/src" -type f -name '*.php' | sort
 echo
 echo "[SECURITY / SAVE SIGNALS]"
 grep -RniE 'checkToken|authorise|authoriz|core\.edit|core\.create|core\.manage|InputFilter|filter|raw|builder_config_json|fields_json|fields_payload|normaliseJsonObject|DatabaseInterface|bind|quoteName|insertObject|updateObject|transaction' "$BASE/src" || true
 echo
 echo "[BUILDER CONTROLLER]"
 cat "$BASE/src/Controller/BuilderController.php"
 echo
 echo "[BUILDER VIEW]"
 cat "$BASE/src/View/Builder/HtmlView.php"
 echo
 echo "[PHP LINT]"
 find "$BASE/src" -type f -name '*.php' -print0 | xargs -0 -n1 php -l
} > "$OUT" 2>&1

echo "written $OUT"
