#!/usr/bin/env bash
set -euo pipefail
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q releases/1.3.4/pkg_decaroforms_1.3.4.zip -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.4.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
echo '=== SECTION MARKUP / RELEVANT TOKENS ==='
grep -n -E 'df-subbox|df-status|df-column|df-email|custom_css|custom_js|CUSTOM_CSS|CUSTOM_JS|TABLE_COLUMNS|STATUSES|VALIDATION|EMAIL' "$B" | head -n 260 || true
echo '=== CSS DEFINITIONS ==='
grep -n -E '\.df-(subbox|status|column|email|security|code|section-body|check|field)' "$B" | head -n 260 || true
