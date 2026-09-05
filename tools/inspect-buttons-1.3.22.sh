#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.22/pkg_decaroforms_1.3.22.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.22.zip" -d "$TMP/c"
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"
echo '=== BUTTON CSS ==='
grep -n -E '\.df-btn|\.df-primary|\.df-danger|\.df-save-structure|\.df-small|button:not|background:var\(--df-dark|background:#|!important' "$B" | head -n 260 || true
echo '=== BUTTON MARKUP ==='
grep -n -E 'class="[^"]*(df-btn|df-primary|df-danger|df-save-structure)[^"]*"' "$B" | head -n 220 || true
