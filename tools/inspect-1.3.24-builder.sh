#!/usr/bin/env bash
set -euo pipefail
BASE="releases/1.3.24/pkg_decaroforms_1.3.24.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.24.zip" -d "$TMP/c"
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"
echo '=== TOP LEVEL 1330-1450 ==='
sed -n '1330,1450p' "$B"
echo '=== IDS REFERENCED VS PRESENT ==='
for id in df-layout-apply df-token-insert df-user-email-field df-confirm-position df-success-format df-success-modal df-validation-ajax df-validation-scroll df-required-marker df-error-message df-confirm-enabled df-confirm-scroll df-confirm-continue df-confirm-continue-label df-confirm-continue-url df-min-seconds df-rate-seconds; do
  echo "--- $id ---"
  grep -n "$id" "$B" || true
done
echo '=== CUSTOM CODE HTML ==='
sed -n '1030,1075p' "$B"
echo '=== DRAFT EXPORT BLOCK ==='
sed -n '1405,1445p' "$B"
