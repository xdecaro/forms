#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.17/pkg_decaroforms_1.3.17.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/p"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/plg_system_decaroforms_1.3.17.zip" -d "$TMP/p"
echo '=== PLUGIN FILES ==='
find "$TMP/p" -maxdepth 4 -type f | sort | head -n 120
echo '=== CONFIRMATION MATCHES ==='
grep -R -n -E 'success_message|confirmation|confirm|closed_message|submission|shortcode|form id' "$TMP/p" | head -n 320 || true
