#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
ZIP="$ROOT/releases/1.3.55/pkg_decaroforms_1.3.55.zip"
REPORT="$ROOT/tools/verify-1.3.55-package-report.txt"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

test -f "$ZIP"
unzip -t "$ZIP" >/dev/null
unzip -q "$ZIP" -d "$TMP/outer"

{
  echo "Forms 1.3.55 package verification"
  echo "================================="
  echo
  echo "OUTER FILES"
  find "$TMP/outer" -maxdepth 2 -type f -printf '%P\n' | sort
  echo
  echo "ZIP CHILDREN"
  find "$TMP/outer" -maxdepth 1 -type f -name '*.zip' -printf '%f\n' | sort
  echo
  echo "MANIFEST REFERENCES"
  grep -RInE 'com_decaroforms|plg_.*decaroforms|1\.3\.55' "$TMP/outer" --include='*.xml' || true
} > "$REPORT"

# Require canonical child names expected by the package.
test -f "$TMP/outer/com_decaroforms_1.3.55.zip"
test -f "$TMP/outer/plg_system_decaroforms_1.3.55.zip"

# Verify every child ZIP and versions.
for C in "$TMP/outer"/*.zip; do
  unzip -t "$C" >/dev/null
  D="$TMP/child-$(basename "$C" .zip)"
  mkdir -p "$D"
  unzip -q "$C" -d "$D"
  if grep -Rqs '1\.3\.54' "$D" --include='*.xml' --include='*.php' --include='*.ini' --include='*.js' --include='*.json' --include='*.css'; then
    echo "ERROR: old 1.3.54 reference in $(basename "$C")" >> "$REPORT"
    exit 1
  fi
done

# Validate package manifest references if present.
MANIFEST="$(find "$TMP/outer" -maxdepth 1 -type f -name '*.xml' -print -quit || true)"
if [ -n "$MANIFEST" ]; then
  python3 - "$MANIFEST" <<'PY'
import sys,xml.etree.ElementTree as ET
ET.parse(sys.argv[1])
PY
  grep -q '1.3.55' "$MANIFEST"
  grep -q 'com_decaroforms_1.3.55.zip' "$MANIFEST"
  grep -q 'plg_system_decaroforms_1.3.55.zip' "$MANIFEST"
fi

echo >> "$REPORT"
echo "RESULT: PASS" >> "$REPORT"
