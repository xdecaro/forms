#!/usr/bin/env bash
set -euo pipefail

ROOT=/tmp/forms1211
OUTER="$ROOT/outer"
COMP="$ROOT/component"
PLUGIN="$ROOT/plugin"
rm -rf "$ROOT"
mkdir -p "$OUTER" "$COMP" "$PLUGIN" releases/1.2.11

unzip -q releases/1.2.10/pkg_decaroforms_1.2.10.zip -d "$OUTER"
COM_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'com_decaroforms_*.zip' | head -n1)"
PLG_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'plg_*decaroforms*.zip' | head -n1)"
unzip -q "$COM_ZIP" -d "$COMP"
unzip -q "$PLG_ZIP" -d "$PLUGIN"

python3 - <<'PY'
from pathlib import Path
p=Path('/tmp/forms1211/component/administrator/components/com_decaroforms/tmpl/forms/default.php')
s=p.read_text()

# Restore Joomla/default font sizing for smartphone action controls.
s=s.replace('font-size:13px', 'font-size:inherit;line-height:normal')
s=s.replace('font-size:12.5px', 'font-size:inherit;line-height:normal')

# Keep semantic status badge colours identical in light and dark mode,
# and guarantee the dark accent colour is present in the normal state.
marker='</style>'
extra='''\n/* Forms 1.2.11 final forms-list visual rules */\n.df-wrap .df-on{background:#e8f7ee!important;color:#176b3a!important}\n.df-wrap .df-off{background:#fdebec!important;color:#9f2430!important}\nhtml[data-bs-theme="dark"] .df-wrap .df-btn-primary,\nhtml[data-color-scheme="dark"] .df-wrap .df-btn-primary,\nbody[data-bs-theme="dark"] .df-wrap .df-btn-primary,\nbody[data-color-scheme="dark"] .df-wrap .df-btn-primary,\n.df-wrap.df-dark-theme .df-btn-primary{background:#9f1239!important;border-color:#9f1239!important;color:#fff!important}\nhtml[data-bs-theme="dark"] .df-wrap .df-btn-primary:hover,\nhtml[data-color-scheme="dark"] .df-wrap .df-btn-primary:hover,\nbody[data-bs-theme="dark"] .df-wrap .df-btn-primary:hover,\nbody[data-color-scheme="dark"] .df-wrap .df-btn-primary:hover,\n.df-wrap.df-dark-theme .df-btn-primary:hover{background:#7f0d2e!important;border-color:#7f0d2e!important;color:#fff!important}\n'''
if marker not in s:
    raise SystemExit('style marker not found')
s=s.replace(marker,extra+marker,1)

p.write_text(s)
PY

# Bump component/plugin/package metadata.
while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.10/1.2.11/g' "$file"
done < <(find "$COMP" "$PLUGIN" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)
while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.10/1.2.11/g' "$file"
done < <(find "$OUTER" -maxdepth 1 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)

COM_NEW="$OUTER/com_decaroforms_1.2.11.zip"
PLG_BASENAME="$(basename "$PLG_ZIP")"
PLG_NEW="$OUTER/${PLG_BASENAME/1.2.10/1.2.11}"
rm -f "$COM_ZIP" "$PLG_ZIP"
(cd "$COMP" && zip -qr "$COM_NEW" .)
(cd "$PLUGIN" && zip -qr "$PLG_NEW" .)

TARGET="$GITHUB_WORKSPACE/releases/1.2.11/pkg_decaroforms_1.2.11.zip"
rm -f "$TARGET"
(cd "$OUTER" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

# Automated checks.
find "$COMP" -type f -name '*.php' -print0 | xargs -0 -n1 php -l >/tmp/forms1211-php.log
python3 - <<'PY'
import xml.etree.ElementTree as ET
ET.parse('/tmp/forms1211/component/com_decaroforms.xml')
PY
unzip -tq "$TARGET" >/dev/null
grep -q 'font-size:inherit;line-height:normal' "$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
grep -q '.df-wrap .df-on{background:#e8f7ee!important;color:#176b3a!important}' "$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
grep -q '.df-wrap .df-off{background:#fdebec!important;color:#9f2430!important}' "$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
grep -q '.df-wrap.df-dark-theme .df-btn-primary{background:#9f1239!important' "$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"

cat > releases/1.2.11/README.md <<EOF
# Forms 1.2.11

Chiusura UI dell'Elenco moduli.

## Modifiche

- pulsanti e controllo Cerca e filtra su smartphone tornano alla dimensione font normale di Joomla;
- Attivo e Disattivato mantengono gli stessi colori semantici in light e dark mode;
- Vedi invii e + Nuovo modulo mantengono il rosso scuro già nello stato normale in dark mode;
- hover dei pulsanti accent resta più scuro e visibile;
- nessuna modifica allo schema database e nessuna perdita di dati.

SHA-256: $SHA
EOF

cat > updates/pkg_decaroforms.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.2.11</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.2.11/pkg_decaroforms_1.2.11.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF

python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET
p=Path('updates/changelog.xml')
s=p.read_text()
entry='''  <changelog>\n    <element>pkg_decaroforms</element><type>package</type><version>1.2.11</version>\n    <fix><item>Smartphone form-list actions now use the normal Joomla font size.</item><item>Active and inactive badges retain their semantic colours in both light and dark modes.</item><item>Dark primary form-list actions keep their dark red colour in the normal state.</item></fix>\n  </changelog>\n'''
s=s.replace('<changelogs>\n','<changelogs>\n'+entry,1)
p.write_text(s)
ET.parse('updates/pkg_decaroforms.xml')
ET.parse('updates/changelog.xml')
PY

rm -rf releases/_upload
