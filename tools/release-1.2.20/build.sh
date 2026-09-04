#!/usr/bin/env bash
set -euo pipefail

ROOT=/tmp/forms1220
OUTER="$ROOT/outer"
COMP="$ROOT/component"
PLUGIN="$ROOT/plugin"
rm -rf "$ROOT"
mkdir -p "$OUTER" "$COMP" "$PLUGIN" releases/1.2.20

unzip -q releases/1.2.19/pkg_decaroforms_1.2.19.zip -d "$OUTER"
COM_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'com_decaroforms_*.zip' | head -n1)"
PLG_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'plg_*decaroforms*.zip' | head -n1)"
unzip -q "$COM_ZIP" -d "$COMP"
unzip -q "$PLG_ZIP" -d "$PLUGIN"

FORM_VIEW="$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
python3 - <<'PY'
from pathlib import Path
p=Path('/tmp/forms1220/component/administrator/components/com_decaroforms/tmpl/forms/default.php')
s=p.read_text()
css='''
/* Forms 1.2.20: mobile card header — status above, title full width */
@container formslist (max-width:560px){
  .df-wrap .df-card-main{grid-template-columns:1fr!important;align-items:start}
  .df-wrap .df-card-main>.df-card-badges{grid-column:1!important;grid-row:1!important;justify-self:end;width:auto;max-width:100%;margin:0 0 2px}
  .df-wrap .df-card-main>div:not(.df-card-badges){grid-column:1!important;grid-row:2!important;width:100%;min-width:0}
  .df-wrap .df-card-main h3{width:100%;max-width:none}
}
'''
if '</style>' not in s:
    raise SystemExit('Style close not found')
s=s.replace('</style>',css+'\n</style>',1)
for marker in ['grid-template-columns:1fr!important','>.df-card-badges','div:not(.df-card-badges)']:
    if marker not in s:
        raise SystemExit('Missing responsive marker '+marker)
p.write_text(s)
PY

while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.19/1.2.20/g' "$file"
done < <(find "$COMP" "$PLUGIN" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)
while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.19/1.2.20/g' "$file"
done < <(find "$OUTER" -maxdepth 1 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)

COM_NEW="$OUTER/com_decaroforms_1.2.20.zip"
PLG_BASENAME="$(basename "$PLG_ZIP")"
PLG_NEW="$OUTER/${PLG_BASENAME/1.2.19/1.2.20}"
rm -f "$COM_ZIP" "$PLG_ZIP"
(cd "$COMP" && zip -qr "$COM_NEW" .)
(cd "$PLUGIN" && zip -qr "$PLG_NEW" .)

TARGET="$GITHUB_WORKSPACE/releases/1.2.20/pkg_decaroforms_1.2.20.zip"
rm -f "$TARGET"
(cd "$OUTER" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

find "$COMP" -type f -name '*.php' -print0 | xargs -0 -n1 php -l >/tmp/forms1220-php.log
unzip -tq "$TARGET" >/dev/null
grep -q 'mobile card header' "$FORM_VIEW"

cat > releases/1.2.20/README.md <<EOF
# Forms 1.2.20

Rifinitura responsive dell'intestazione card nell'Elenco moduli.

- Su smartphone il badge di stato/motivo viene mostrato in alto a destra su una riga propria.
- Titolo e descrizione usano tutta la larghezza disponibile nella riga successiva.
- Desktop e tablet restano invariati.
- Nessuna modifica al database.

SHA-256: $SHA
EOF

cat > updates/pkg_decaroforms.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.2.20</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.2.20/pkg_decaroforms_1.2.20.zip</downloadurl></downloads>
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
    <version>1.2.20</version>
    <security></security>
    <fix>Smartphone: badge su riga propria e titolo card a larghezza piena.</fix>
    <language>it-IT</language>
  </changelog>
</changelogs>
EOF

rm -rf releases/_upload
printf 'Built Forms 1.2.20 %s\n' "$SHA"
