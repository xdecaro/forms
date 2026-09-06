#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
ZIP="$ROOT/releases/1.3.46/pkg_decaroforms_1.3.46.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/plugin"
unzip -q "$ZIP" -d "$TMP/outer"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.46.zip" -d "$TMP/plugin"
P="$TMP/plugin/src/Extension/FormsPlugin.php"
OUT="$ROOT/tools/inspect-1.3.46-plugin-render.txt"
sed -n '220,390p' "$P" > "$OUT"
