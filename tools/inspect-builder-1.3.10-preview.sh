#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.10/pkg_decaroforms_1.3.10.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.10.zip" -d "$TMP/c"
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"
echo '=== PREVIEW ROWS / EMAIL FUNCTIONS ==='
grep -n -E 'function previewRows|function emailPreviewHtml|function showEmailPreview|previewModal|df-email-preview-modal|df-email-thumb|df-email-choice' "$B" || true
echo '=== SCRIPT TAIL AROUND EMAIL ==='
awk 'NR>=720 && NR<=790 {printf "%4d:%s\n",NR,$0}' "$B"
echo '=== MODAL CONTEXT ==='
awk 'NR>=550 && NR<=590 {printf "%4d:%s\n",NR,$0}' "$B"
