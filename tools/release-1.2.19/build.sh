#!/usr/bin/env bash
set -euo pipefail

ROOT=/tmp/forms1219
OUTER="$ROOT/outer"
COMP="$ROOT/component"
PLUGIN="$ROOT/plugin"
rm -rf "$ROOT"
mkdir -p "$OUTER" "$COMP" "$PLUGIN" releases/1.2.19

unzip -q releases/1.2.18/pkg_decaroforms_1.2.18.zip -d "$OUTER"
COM_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'com_decaroforms_*.zip' | head -n1)"
PLG_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'plg_*decaroforms*.zip' | head -n1)"
unzip -q "$COM_ZIP" -d "$COMP"
unzip -q "$PLG_ZIP" -d "$PLUGIN"

FORM_VIEW="$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
python3 - <<'PY'
from pathlib import Path
p=Path('/tmp/forms1219/component/administrator/components/com_decaroforms/tmpl/forms/default.php')
s=p.read_text()
old='.df-wrap .df-badge.df-reason{font-size:11px!important;line-height:1.2;font-weight:800}'
new='.df-wrap .df-badge.df-reason{font-size:13px!important;line-height:1.2;font-weight:800}'
if old not in s:
    raise SystemExit('Previous 11px badge rule not found')
s=s.replace(old,new,1)
if new not in s:
    raise SystemExit('13px badge rule missing')
p.write_text(s)
PY

while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.18/1.2.19/g' "$file"
done < <(find "$COMP" "$PLUGIN" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)
while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.18/1.2.19/g' "$file"
done < <(find "$OUTER" -maxdepth 1 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)

COM_NEW="$OUTER/com_decaroforms_1.2.19.zip"
PLG_BASENAME="$(basename "$PLG_ZIP")"
PLG_NEW="$OUTER/${PLG_BASENAME/1.2.18/1.2.19}"
rm -f "$COM_ZIP" "$PLG_ZIP"
(cd "$COMP" && zip -qr "$COM_NEW" .)
(cd "$PLUGIN" && zip -qr "$PLG_NEW" .)

TARGET="$GITHUB_WORKSPACE/releases/1.2.19/pkg_decaroforms_1.2.19.zip"
rm -f "$TARGET"
(cd "$OUTER" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

find "$COMP" -type f -name '*.php' -print0 | xargs -0 -n1 php -l >/tmp/forms1219-php.log
unzip -tq "$TARGET" >/dev/null
grep -q 'df-badge.df-reason{font-size:13px!important' "$FORM_VIEW"

cat > releases/1.2.19/README.md <<EOF
# Forms 1.2.19

Rifinitura dimensione badge nell'Elenco moduli.

- I badge dei motivi di chiusura usano un font più grande (13 px).
- La misura è identica su desktop, tablet e smartphone.
- Colori, sfondi e logica restano invariati.
- Nessuna modifica al database.

SHA-256: $SHA
EOF

cat > updates/pkg_decaroforms.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.2.19</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.2.19/pkg_decaroforms_1.2.19.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF

cat > updates/changelog.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<changelogs>
  <changelog>
    <element>pkg_decaroforms</element>
    <type>package</type>
    <version>1.2.19</version>
    <security></security>
    <fix>Elenco moduli: badge motivi di chiusura più grandi e uniformi su tutti i dispositivi.</fix>
    <language>it-IT</language>
  </changelog>
</changelogs>
EOF

rm -rf releases/_upload
printf 'Built Forms 1.2.19 %s\n' "$SHA"
