#!/usr/bin/env bash
set -euo pipefail

ROOT=/tmp/forms1214
OUTER="$ROOT/outer"
COMP="$ROOT/component"
PLUGIN="$ROOT/plugin"
rm -rf "$ROOT"
mkdir -p "$OUTER" "$COMP" "$PLUGIN" releases/1.2.14

unzip -q releases/1.2.13/pkg_decaroforms_1.2.13.zip -d "$OUTER"
COM_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'com_decaroforms_*.zip' | head -n1)"
PLG_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'plg_*decaroforms*.zip' | head -n1)"
unzip -q "$COM_ZIP" -d "$COMP"
unzip -q "$PLG_ZIP" -d "$PLUGIN"

FORM_VIEW="$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"

python3 - <<'PY'
from pathlib import Path
import re
p=Path('/tmp/forms1214/component/administrator/components/com_decaroforms/tmpl/forms/default.php')
s=p.read_text()

# 1) Clean the card-title rules: no own background in any theme.
old=r'''\.df-card-main>div\{background:transparent!important;background-color:transparent!important\}\.df-card h3\{margin:0 0 4px;font-size:19px;overflow-wrap:anywhere;background:transparent!important;background-color:transparent!important;padding:0!important;border:0!important;box-shadow:none!important\}\.df-card h3::before,\.df-card h3::after\{content:none!important;display:none!important;background:none!important\}'''
new='.df-card-main>div{min-width:0;background:none!important}.df-card h3{margin:0 0 4px;font-size:19px;overflow-wrap:anywhere;background:none!important;padding:0!important;border:0!important;box-shadow:none!important}.df-card h3::before,.df-card h3::after{content:none!important;display:none!important}'
s,n=re.subn(old,new,s,count=1)
if n!=1:
    raise SystemExit('Card title CSS block not found')

# 2) Remove duplicated status-color rules shipped across base/dark/final sections.
patterns=[
    r'\.df-on\{background:#e8f7ee;color:#176b3a\}\.df-off\{background:#fdebec;color:#9f2430\}',
    r'html\[data-bs-theme="dark"\] \.df-wrap \.df-on,html\[data-color-scheme="dark"\] \.df-wrap \.df-on\{background:#163b29;color:#a8e5bd\}html\[data-bs-theme="dark"\] \.df-wrap \.df-off,html\[data-color-scheme="dark"\] \.df-wrap \.df-off\{background:#4a1f28;color:#ffb5c0\}',
    r'\.df-wrap\.df-dark-theme \.df-on\{background:#163b29;color:#a8e5bd\}\.df-wrap\.df-dark-theme \.df-off\{background:#4a1f28;color:#ffb5c0\}',
    r'/\* Forms 1\.2\.13 final forms-list visual rules \*/\s*\.df-wrap \.df-on\{background:#e8f7ee!important;color:#176b3a!important\}\s*\.df-wrap \.df-off\{background:#fdebec!important;color:#9f2430!important\}\s*'
]
for pat in patterns:
    s=re.sub(pat,'',s,count=1,flags=re.S)

# 3) Add one canonical semantic status block at the end of the component style.
#    High specificity intentionally beats generic Joomla dark badge rules.
semantic='''\n/* Forms 1.2.14: canonical card title + semantic status colors */\n.df-wrap .df-card-main>div,\n.df-wrap .df-card h3,\nhtml[data-bs-theme="dark"] .df-wrap .df-card-main>div,\nhtml[data-bs-theme="dark"] .df-wrap .df-card h3,\nhtml[data-color-scheme="dark"] .df-wrap .df-card-main>div,\nhtml[data-color-scheme="dark"] .df-wrap .df-card h3,\n.df-wrap.df-dark-theme .df-card-main>div,\n.df-wrap.df-dark-theme .df-card h3{background:none!important;background-color:transparent!important}\n\n.df-wrap .df-badge.df-on,\nhtml[data-bs-theme="dark"] .df-wrap .df-badge.df-on,\nhtml[data-color-scheme="dark"] .df-wrap .df-badge.df-on,\n.df-wrap.df-dark-theme .df-badge.df-on{background:#e8f7ee!important;color:#176b3a!important;border-color:#b7e3c8!important}\n\n.df-wrap .df-badge.df-off,\nhtml[data-bs-theme="dark"] .df-wrap .df-badge.df-off,\nhtml[data-color-scheme="dark"] .df-wrap .df-badge.df-off,\n.df-wrap.df-dark-theme .df-badge.df-off{background:#fdebec!important;color:#9f2430!important;border-color:#f2c5ca!important}\n'''
if '</style>' not in s:
    raise SystemExit('Style end not found')
s=s.replace('</style>',semantic+'\n</style>',1)

# Sanity: only the canonical status background values should remain as status rules.
if s.count('background:#e8f7ee') != 1 or s.count('background:#fdebec') != 1:
    raise SystemExit('Duplicate semantic status backgrounds remain after cleanup')

p.write_text(s)
PY

# Version bump in component/plugin/package metadata.
while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.13/1.2.14/g' "$file"
done < <(find "$COMP" "$PLUGIN" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)
while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.13/1.2.14/g' "$file"
done < <(find "$OUTER" -maxdepth 1 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)

COM_NEW="$OUTER/com_decaroforms_1.2.14.zip"
PLG_BASENAME="$(basename "$PLG_ZIP")"
PLG_NEW="$OUTER/${PLG_BASENAME/1.2.13/1.2.14}"
rm -f "$COM_ZIP" "$PLG_ZIP"
(cd "$COMP" && zip -qr "$COM_NEW" .)
(cd "$PLUGIN" && zip -qr "$PLG_NEW" .)

TARGET="$GITHUB_WORKSPACE/releases/1.2.14/pkg_decaroforms_1.2.14.zip"
rm -f "$TARGET"
(cd "$OUTER" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

# Automated validation.
find "$COMP" -type f -name '*.php' -print0 | xargs -0 -n1 php -l >/tmp/forms1214-php.log
python3 - <<'PY'
import xml.etree.ElementTree as ET
ET.parse('/tmp/forms1214/component/com_decaroforms.xml')
PY
unzip -tq "$TARGET" >/dev/null
grep -q 'Forms 1.2.14: canonical card title + semantic status colors' "$FORM_VIEW"
grep -q '.df-wrap .df-badge.df-on' "$FORM_VIEW"
grep -q '.df-wrap .df-badge.df-off' "$FORM_VIEW"
grep -q 'background:none!important;background-color:transparent!important' "$FORM_VIEW"
! grep -q 'background:#163b29;color:#a8e5bd' "$FORM_VIEW"
! grep -q 'background:#4a1f28;color:#ffb5c0' "$FORM_VIEW"

cat > releases/1.2.14/README.md <<EOF
# Forms 1.2.14

Pulizia CSS finale dell'Elenco moduli.

## Modifiche

- eliminato definitivamente lo sfondo dal titolo delle card modulo;
- consolidate le regole duplicate di Attivo e Disattivato;
- Attivo mantiene sempre il verde semantico anche in dark mode;
- Disattivato mantiene sempre il rosso semantico anche in dark mode;
- aggiunta specificità sufficiente per non essere sovrascritti dai badge generici del template Joomla;
- rimossi override dark duplicati e contrastanti per gli stati;
- nessuna modifica allo schema database e nessuna perdita di dati.

SHA-256: $SHA
EOF

cat > updates/pkg_decaroforms.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.2.14</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.2.14/pkg_decaroforms_1.2.14.zip</downloadurl></downloads>
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
entry='''  <changelog>\n    <element>pkg_decaroforms</element><type>package</type><version>1.2.14</version>\n    <change><item>Removed card-title background in all themes.</item><item>Consolidated duplicate enabled/disabled badge CSS into canonical semantic rules.</item><item>Prevented generic Joomla dark badge rules from overriding form status colors.</item></change>\n  </changelog>\n'''
s=s.replace('<changelogs>\n','<changelogs>\n'+entry,1)
p.write_text(s)
ET.parse('updates/pkg_decaroforms.xml')
ET.parse('updates/changelog.xml')
PY

rm -rf releases/_upload
