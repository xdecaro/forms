#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"; VER="1.3.40"; BASE="$ROOT/releases/$VER/pkg_decaroforms_$VER.zip"; TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_$VER.zip" -d "$TMP/component"
OUT="$ROOT/tools/inspect-1.3.40-site-renderer.txt"
{
  echo '=== SITE TEMPLATE ==='
  cat "$TMP/component/site/components/com_decaroforms/tmpl/forms/default.php"
  echo '\n=== SITE VIEW ==='
  cat "$TMP/component/site/components/com_decaroforms/src/View/Forms/HtmlView.php"
  echo '\n=== DISPLAY CONTROLLER ==='
  cat "$TMP/component/site/components/com_decaroforms/src/Controller/DisplayController.php"
  echo '\n=== ADMIN HELPER REFERENCES ==='
  grep -RInE "renderForm|layout|field.*width|row_meta|fields_json|config_json" "$TMP/component/administrator/components/com_decaroforms/src" || true
} > "$OUT"
rm -rf "$ROOT/releases/_upload"
echo "Wrote $OUT"
