#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.9/pkg_decaroforms_1.3.9.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.9.zip" -d "$TMP/c"
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"
echo '=== EMAIL PREVIEW FUNCTIONS ==='
grep -n -E 'showEmailPreview|df-preview|emailPreviewHtml|data-email-picker|renderEmailPickers' "$B" || true
