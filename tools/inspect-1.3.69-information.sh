#!/usr/bin/env bash
set -euo pipefail

# Trigger inspection 2026-09-07
BASE="releases/1.3.69/pkg_decaroforms_1.3.69.zip"
REPORT="releases/_inspect-1.3.69-information.txt"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ ! -f "$BASE" ]; then
  echo "Missing base package: $BASE" >&2
  exit 1
fi

mkdir -p "$WORK/outer" "$WORK/nested"
unzip -q "$BASE" -d "$WORK/outer"

{
  echo "# Forms 1.3.69 — Information view inspection"
  echo
  echo "## Outer package"
  find "$WORK/outer" -maxdepth 3 -type f -printf '%P\n' | sort
  echo
} > "$REPORT"

while IFS= read -r -d '' zipfile; do
  name="$(basename "$zipfile" .zip)"
  dest="$WORK/nested/$name"
  mkdir -p "$dest"
  unzip -q "$zipfile" -d "$dest"
  {
    echo
    echo "## Nested package: $name"
    find "$dest" -type f -printf '%P\n' | sort
  } >> "$REPORT"
done < <(find "$WORK/outer" -type f -name '*.zip' -print0)

{
  echo
  echo "## Files matching current Information content"
} >> "$REPORT"

mapfile -t matches < <(
  grep -RIlE --include='*.php' --include='*.xml' --include='*.ini' --include='*.css' --include='*.js' \
    'Shortcode|Funzioni principali|Tabelle database|Informazioni|Information|COM_DECAROFORMS_INFO' \
    "$WORK/nested" 2>/dev/null | sort -u || true
)

for file in "${matches[@]}"; do
  rel="${file#$WORK/nested/}"
  size="$(wc -c < "$file")"
  {
    echo
    echo "===== FILE: $rel (${size} bytes) ====="
    if [ "$size" -le 180000 ]; then
      sed -n '1,1800p' "$file"
    else
      echo "[File too large; matching lines only]"
      grep -nE 'Shortcode|Funzioni principali|Tabelle database|Informazioni|Information|COM_DECAROFORMS_INFO' "$file" | head -n 250 || true
    fi
    echo "===== END FILE: $rel ====="
  } >> "$REPORT"
done

{
  echo
  echo "## Candidate administrator templates / assets"
  find "$WORK/nested" -type f \( -path '*/tmpl/*' -o -path '*/media/*' -o -name '*.css' \) \
    | sed "s#^$WORK/nested/##" | grep -Ei 'info|about|forms|admin|default' | sort | head -n 400
  echo
  echo "## Manifest/version references"
  grep -RInE --include='*.xml' '<version>|<namespace>|<administration>|<media' "$WORK/nested" | head -n 500 || true
} >> "$REPORT"

rm -rf releases/_upload

echo "Inspection report written to $REPORT"
