#!/usr/bin/env bash
set -euo pipefail
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
unzip -q releases/1.3.5/pkg_decaroforms_1.3.5.zip -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.5.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
echo '=== QUICK TEMPLATE / ADD FIELD ==='
grep -n -E 'quick|template-row|renderSelected|openField|library|dataset\.quick|data-template|addField|selected\.push|scrollIntoView' "$B" | head -n 260 || true
echo '=== ACCORDION / STATUS / DARK ==='
grep -n -E 'accordionSections|df-status-row|df-library-tab|df-section-toggle|df-closed-box' "$B" | head -n 220 || true
