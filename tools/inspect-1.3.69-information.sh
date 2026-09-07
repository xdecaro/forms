#!/usr/bin/env bash
set -euo pipefail

# Extract the current Forms 1.3.69 Information implementation for review.
BASE="releases/1.3.69/pkg_decaroforms_1.3.69.zip"
REPORT="releases/_inspect-1.3.69-information.txt"
OUT="tools/_inspect-1.3.69-information"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [ ! -f "$BASE" ]; then
  echo "Missing base package: $BASE" >&2
  exit 1
fi

rm -rf "$OUT"
mkdir -p "$WORK/outer" "$WORK/nested" "$OUT"
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

COMP="$WORK/nested/com_decaroforms_1.3.69"
SYSTEM="$WORK/nested/plg_system_decaroforms_1.3.69"
EDITOR="$WORK/nested/plg_editors-xtd_decaroforms_1.3.69"

cp "$COMP/administrator/components/com_decaroforms/tmpl/information/default.php" "$OUT/information-default.php"
cp "$COMP/administrator/components/com_decaroforms/src/View/Information/HtmlView.php" "$OUT/information-HtmlView.php"
cp "$COMP/administrator/components/com_decaroforms/src/Helper/FormHelper.php" "$OUT/FormHelper.php"
cp "$COMP/com_decaroforms.xml" "$OUT/com_decaroforms.xml"
cp "$COMP/script.php" "$OUT/component-script.php"
cp "$COMP/administrator/components/com_decaroforms/access.xml" "$OUT/access.xml"
cp "$COMP/administrator/components/com_decaroforms/config.xml" "$OUT/config.xml"
cp "$COMP/administrator/components/com_decaroforms/language/it-IT/com_decaroforms.ini" "$OUT/com_decaroforms-it-IT.ini"
cp "$COMP/administrator/components/com_decaroforms/language/en-GB/com_decaroforms.ini" "$OUT/com_decaroforms-en-GB.ini"
cp "$COMP/administrator/components/com_decaroforms/language/fr-FR/com_decaroforms.ini" "$OUT/com_decaroforms-fr-FR.ini"
cp "$COMP/administrator/components/com_decaroforms/language/it-IT/com_decaroforms.sys.ini" "$OUT/com_decaroforms-it-IT.sys.ini"
cp "$COMP/administrator/components/com_decaroforms/language/en-GB/com_decaroforms.sys.ini" "$OUT/com_decaroforms-en-GB.sys.ini"
cp "$COMP/administrator/components/com_decaroforms/language/fr-FR/com_decaroforms.sys.ini" "$OUT/com_decaroforms-fr-FR.sys.ini"
cp "$WORK/outer/pkg_decaroforms.xml" "$OUT/pkg_decaroforms.xml"
cp "$SYSTEM/decaroforms.xml" "$OUT/plg-system-decaroforms.xml"
cp "$EDITOR/decaroforms.xml" "$OUT/plg-editors-xtd-decaroforms.xml"

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

echo "Inspection report written to $REPORT"
echo "Extracted source files written to $OUT"
