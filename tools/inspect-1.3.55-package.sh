#!/usr/bin/env bash
set -u
ROOT="$(pwd)"
ZIP="$ROOT/releases/1.3.55/pkg_decaroforms_1.3.55.zip"
REPORT="$ROOT/tools/inspect-1.3.55-package-report.txt"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
{
  echo "ZIP exists: $(test -f "$ZIP" && echo yes || echo no)"
  if [ -f "$ZIP" ]; then
    echo "ZIP test:"
    unzip -t "$ZIP" 2>&1 | tail -n 5
    mkdir -p "$TMP/outer"
    unzip -q "$ZIP" -d "$TMP/outer" 2>&1 || true
    echo
    echo "Outer files:"
    find "$TMP/outer" -maxdepth 2 -printf '%y %P\n' | sort
    echo
    echo "Outer XML contents:"
    for X in "$TMP/outer"/*.xml; do
      [ -f "$X" ] || continue
      echo "--- $(basename "$X") ---"
      cat "$X"
      echo
    done
    echo
    echo "Child ZIP tests and manifests:"
    for C in "$TMP/outer"/*.zip; do
      [ -f "$C" ] || continue
      echo "=== $(basename "$C") ==="
      unzip -t "$C" 2>&1 | tail -n 3
      D="$TMP/$(basename "$C" .zip)"
      mkdir -p "$D"
      unzip -q "$C" -d "$D" 2>&1 || true
      find "$D" -maxdepth 2 -type f -name '*.xml' -print | while read -r M; do
        echo "--- ${M#$D/} ---"
        grep -nE '<name>|<version>|<element>|<filename|<file ' "$M" || true
      done
    done
  fi
} > "$REPORT"
exit 0
