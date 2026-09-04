#!/usr/bin/env bash
set -euo pipefail
ROOT=/tmp/forms-update-inspect
rm -rf "$ROOT"
mkdir -p "$ROOT/outer" "$ROOT/component" "$ROOT/plugin"
unzip -q releases/1.2.15/pkg_decaroforms_1.2.15.zip -d "$ROOT/outer"
{
  echo '=== OUTER FILES ==='
  find "$ROOT/outer" -maxdepth 2 -type f | sort
  echo
  echo '=== OUTER XML MANIFESTS ==='
  for f in "$ROOT/outer"/*.xml; do
    [ -f "$f" ] || continue
    echo "--- $f"
    cat "$f"
    echo
  done
  COM_ZIP="$(find "$ROOT/outer" -maxdepth 1 -type f -name 'com_decaroforms_*.zip' | head -n1)"
  PLG_ZIP="$(find "$ROOT/outer" -maxdepth 1 -type f -name 'plg_*decaroforms*.zip' | head -n1)"
  if [ -n "$COM_ZIP" ]; then unzip -q "$COM_ZIP" -d "$ROOT/component"; fi
  if [ -n "$PLG_ZIP" ]; then unzip -q "$PLG_ZIP" -d "$ROOT/plugin"; fi
  echo '=== COMPONENT MANIFEST ==='
  find "$ROOT/component" -maxdepth 2 -type f -name '*.xml' -print -exec sh -c 'echo --- "$1"; cat "$1"' _ {} \;
  echo
  echo '=== PLUGIN MANIFEST ==='
  find "$ROOT/plugin" -maxdepth 2 -type f -name '*.xml' -print -exec sh -c 'echo --- "$1"; cat "$1"' _ {} \;
  echo
  echo '=== UPDATE SERVER REFERENCES ==='
  grep -RniE 'updateserver|pkg_decaroforms.xml|raw.githubusercontent.com|github.com/xdecaro/forms' "$ROOT/outer" "$ROOT/component" "$ROOT/plugin" || true
  echo
  echo '=== CURRENT UPDATE FEED ==='
  cat updates/pkg_decaroforms.xml
} > releases/_inspect-update-link.txt
