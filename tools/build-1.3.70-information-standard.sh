#!/usr/bin/env bash
set -euo pipefail

BASE_VERSION="1.3.69"
NEW_VERSION="1.3.70"
RELEASE_DATE="2026-09-07"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_ZIP="$ROOT/releases/$BASE_VERSION/pkg_decaroforms_$BASE_VERSION.zip"
SRC="$ROOT/tools/release-$NEW_VERSION"
OUT="$ROOT/releases/$NEW_VERSION"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

if [[ ! -f "$BASE_ZIP" ]]; then
  echo "Base package not found: $BASE_ZIP" >&2
  exit 1
fi

for required in InformationModel.php InformationHtmlView.php GuideHtmlView.php information-default.php information.css information.js strings-it.ini strings-en.ini strings-fr.ini common-it.ini common-en.ini common-fr.ini; do
  [[ -f "$SRC/$required" ]] || { echo "Missing source: $SRC/$required" >&2; exit 1; }
done

rm -rf "$OUT"
mkdir -p "$OUT" "$WORK/outer" "$WORK/component-old" "$WORK/component" "$WORK/system-old" "$WORK/system" "$WORK/editor-old" "$WORK/editor"
unzip -q "$BASE_ZIP" -d "$WORK/outer"
unzip -q "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" -d "$WORK/component-old"
unzip -q "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" -d "$WORK/component"
unzip -q "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" -d "$WORK/system-old"
unzip -q "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" -d "$WORK/system"
unzip -q "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip" -d "$WORK/editor-old"
unzip -q "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip" -d "$WORK/editor"

# Preserve the current help/documentation content as a dedicated Guide view.
mkdir -p "$WORK/component/administrator/components/com_decaroforms/src/View/Guide"
mkdir -p "$WORK/component/administrator/components/com_decaroforms/tmpl/guide"
cp "$WORK/component/administrator/components/com_decaroforms/tmpl/information/default.php" "$WORK/component/administrator/components/com_decaroforms/tmpl/guide/default.php"
python3 - "$WORK/component/administrator/components/com_decaroforms/tmpl/guide/default.php" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')
s = s.replace("COM_DECAROFORMS_INFO_TITLE", "COM_DECAROFORMS_GUIDE_TITLE")
s = s.replace("COM_DECAROFORMS_INFO_DESC", "COM_DECAROFORMS_GUIDE_DESC")
p.write_text(s, encoding='utf-8')
PY

# Install the new Information implementation and dedicated assets.
cp "$SRC/InformationModel.php" "$WORK/component/administrator/components/com_decaroforms/src/Model/InformationModel.php"
cp "$SRC/InformationHtmlView.php" "$WORK/component/administrator/components/com_decaroforms/src/View/Information/HtmlView.php"
cp "$SRC/GuideHtmlView.php" "$WORK/component/administrator/components/com_decaroforms/src/View/Guide/HtmlView.php"
cp "$SRC/information-default.php" "$WORK/component/administrator/components/com_decaroforms/tmpl/information/default.php"
mkdir -p "$WORK/component/media/css" "$WORK/component/media/js"
cp "$SRC/information.css" "$WORK/component/media/css/information.css"
cp "$SRC/information.js" "$WORK/component/media/js/information.js"

# Correct the stale helper version present in 1.3.69 (it incorrectly reports 1.3.67).
python3 - "$WORK/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php" "$NEW_VERSION" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1]); version = sys.argv[2]
s = p.read_text(encoding='utf-8')
s2, count = re.subn(r"public const VERSION\s*=\s*'[^']+';", f"public const VERSION = '{version}';", s, count=1)
if count != 1:
    raise SystemExit('Unable to update FormHelper::VERSION')
p.write_text(s2, encoding='utf-8')
PY

# Merge translations without leaving duplicate keys.
python3 - "$WORK/component" "$SRC" <<'PY'
from pathlib import Path
import re, sys
component = Path(sys.argv[1])
src = Path(sys.argv[2])

def parse_overlay(path):
    items = []
    for raw in path.read_text(encoding='utf-8').splitlines():
        line = raw.strip()
        if not line or line.startswith(';') or '=' not in line:
            continue
        key, value = line.split('=', 1)
        items.append((key.strip(), value.strip()))
    return items

def merge_ini(target, items):
    text = target.read_text(encoding='utf-8') if target.exists() else ''
    for key, value in items:
        pattern = re.compile(rf'(?m)^{re.escape(key)}=.*$')
        replacement = f'{key}={value}'
        if pattern.search(text):
            text = pattern.sub(replacement, text)
        else:
            if text and not text.endswith('\n'):
                text += '\n'
            text += replacement + '\n'
    target.write_text(text, encoding='utf-8')

sys_keys = {
    'COM_DECAROFORMS_MENU_INFORMATION', 'COM_DECAROFORMS_MENU_GUIDE',
    'COM_DECAROFORMS_INFORMATION', 'COM_DECAROFORMS_GUIDE',
    'COM_DECAROFORMS_GUIDE_TITLE', 'COM_DECAROFORMS_INFO_TITLE',
}

for tag, suffix in [('it-IT','it'), ('en-GB','en'), ('fr-FR','fr')]:
    items = parse_overlay(src / f'strings-{suffix}.ini') + parse_overlay(src / f'common-{suffix}.ini')
    langdir = component / 'administrator/components/com_decaroforms/language' / tag
    merge_ini(langdir / 'com_decaroforms.ini', items)
    merge_ini(langdir / 'com_decaroforms.sys.ini', [item for item in items if item[0] in sys_keys])
PY

# Component manifest: version, media installation and separate Guide/Information menu entries.
python3 - "$WORK/component/com_decaroforms.xml" "$NEW_VERSION" "$RELEASE_DATE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]); version = sys.argv[2]; release_date = sys.argv[3]
s = p.read_text(encoding='utf-8')
s = s.replace('<version>1.3.69</version>', f'<version>{version}</version>', 1)
s = s.replace('<creationDate>2026-09-05</creationDate>', f'<creationDate>{release_date}</creationDate>', 1)
if '<media destination="com_decaroforms"' not in s:
    marker = '    <administration>\n'
    media = ('    <media destination="com_decaroforms" folder="media">\n'
             '        <folder>css</folder>\n'
             '        <folder>js</folder>\n'
             '    </media>\n')
    if marker not in s:
        raise SystemExit('Component manifest administration marker not found')
    s = s.replace(marker, media + marker, 1)
old_menu = '            <menu link="option=com_decaroforms&amp;view=information" img="class:info-circle">COM_DECAROFORMS_MENU_INFORMATION</menu>'
new_menu = ('            <menu link="option=com_decaroforms&amp;view=guide" img="class:question-circle">COM_DECAROFORMS_MENU_GUIDE</menu>\n'
            '            <menu link="option=com_decaroforms&amp;view=information" img="class:info-circle">COM_DECAROFORMS_MENU_INFORMATION</menu>')
if old_menu not in s:
    raise SystemExit('Information submenu marker not found')
s = s.replace(old_menu, new_menu, 1)
p.write_text(s, encoding='utf-8')
PY

# Plugin manifest versions/dates.
python3 - "$WORK/system/decaroforms.xml" "$WORK/editor/decaroforms.xml" "$NEW_VERSION" "$RELEASE_DATE" <<'PY'
from pathlib import Path
import sys
version, release_date = sys.argv[3], sys.argv[4]
for filename in sys.argv[1:3]:
    p = Path(filename)
    s = p.read_text(encoding='utf-8')
    s = s.replace('<version>1.3.69</version>', f'<version>{version}</version>', 1)
    s = s.replace('<creationDate>2026-09-05</creationDate>', f'<creationDate>{release_date}</creationDate>', 1)
    p.write_text(s, encoding='utf-8')
PY

# Regression guard: no pre-existing component/plugin source may change except the explicit files above.
python3 - "$WORK/component-old" "$WORK/component" "$WORK/system-old" "$WORK/system" "$WORK/editor-old" "$WORK/editor" <<'PY'
from pathlib import Path
import hashlib, sys

def hashes(root):
    out = {}
    for p in Path(root).rglob('*'):
        if p.is_file():
            out[str(p.relative_to(root))] = hashlib.sha256(p.read_bytes()).hexdigest()
    return out

component_old, component_new = hashes(sys.argv[1]), hashes(sys.argv[2])
allowed_component = {
    'com_decaroforms.xml',
    'administrator/components/com_decaroforms/src/Helper/FormHelper.php',
    'administrator/components/com_decaroforms/src/View/Information/HtmlView.php',
    'administrator/components/com_decaroforms/tmpl/information/default.php',
    'administrator/components/com_decaroforms/language/it-IT/com_decaroforms.ini',
    'administrator/components/com_decaroforms/language/it-IT/com_decaroforms.sys.ini',
    'administrator/components/com_decaroforms/language/en-GB/com_decaroforms.ini',
    'administrator/components/com_decaroforms/language/en-GB/com_decaroforms.sys.ini',
    'administrator/components/com_decaroforms/language/fr-FR/com_decaroforms.ini',
    'administrator/components/com_decaroforms/language/fr-FR/com_decaroforms.sys.ini',
}
unexpected = [p for p, h in component_old.items() if component_new.get(p) != h and p not in allowed_component]
if unexpected:
    raise SystemExit('Unexpected component regressions: ' + ', '.join(unexpected))

for old_root, new_root, allowed in [
    (sys.argv[3], sys.argv[4], {'decaroforms.xml'}),
    (sys.argv[5], sys.argv[6], {'decaroforms.xml'}),
]:
    old, new = hashes(old_root), hashes(new_root)
    unexpected = [p for p, h in old.items() if new.get(p) != h and p not in allowed]
    if unexpected:
        raise SystemExit('Unexpected plugin regressions: ' + ', '.join(unexpected))
PY

# Syntax and manifest validation before packaging.
php -l "$WORK/component/administrator/components/com_decaroforms/src/Model/InformationModel.php" >/dev/null
php -l "$WORK/component/administrator/components/com_decaroforms/src/View/Information/HtmlView.php" >/dev/null
php -l "$WORK/component/administrator/components/com_decaroforms/src/View/Guide/HtmlView.php" >/dev/null
php -l "$WORK/component/administrator/components/com_decaroforms/tmpl/information/default.php" >/dev/null
php -l "$WORK/component/administrator/components/com_decaroforms/tmpl/guide/default.php" >/dev/null
php -l "$WORK/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php" >/dev/null
python3 - "$WORK/component/com_decaroforms.xml" "$WORK/system/decaroforms.xml" "$WORK/editor/decaroforms.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
for path in sys.argv[1:]: ET.parse(path)
PY

# Rebuild nested ZIPs.
rm -f "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip"
(
  cd "$WORK/component"
  zip -qr "$WORK/outer/com_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store'
)
(
  cd "$WORK/system"
  zip -qr "$WORK/outer/plg_system_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store'
)
(
  cd "$WORK/editor"
  zip -qr "$WORK/outer/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store'
)

# Package manifest references the new nested packages.
python3 - "$WORK/outer/pkg_decaroforms.xml" "$NEW_VERSION" "$RELEASE_DATE" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]); version = sys.argv[2]; release_date = sys.argv[3]
s = p.read_text(encoding='utf-8')
s = s.replace('1.3.69', version)
s = s.replace('<creationDate>2026-09-05</creationDate>', f'<creationDate>{release_date}</creationDate>', 1)
p.write_text(s, encoding='utf-8')
PY
python3 - "$WORK/outer/pkg_decaroforms.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
ET.parse(sys.argv[1])
PY

# Build the installable package.
(
  cd "$WORK/outer"
  zip -qr "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store' '*.log' '*.tmp'
)
cp "$WORK/outer/com_decaroforms_${NEW_VERSION}.zip" "$OUT/com_decaroforms_${NEW_VERSION}.zip"
cp "$WORK/outer/plg_system_decaroforms_${NEW_VERSION}.zip" "$OUT/plg_system_decaroforms_${NEW_VERSION}.zip"
cp "$WORK/outer/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip" "$OUT/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip"
cp "$WORK/outer/pkg_decaroforms.xml" "$OUT/pkg_decaroforms.xml"

SHA256="$(sha256sum "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | awk '{print $1}')"
printf '%s  %s\n' "$SHA256" "pkg_decaroforms_${NEW_VERSION}.zip" > "$OUT/SHA256SUMS.txt"

cat > "$OUT/README.md" <<EOF
# Forms $NEW_VERSION

Release dedicata alla nuova pagina **Informazioni**, uniformata allo standard xdecaro con **Competitions** come riferimento visivo.

## Novità

- nuova pagina Informazioni: Prodotto, Ambiente, Estensioni incluse e Aggiornamenti;
- nuova sezione full-width Componenti collegati;
- diagnostica tecnica con copia e download `.txt`, senza password, token, cookie o credenziali;
- controlli automatici su versioni, tabelle/schema, plugin, ambiente e update server;
- responsive desktop/tablet/smartphone e dark mode;
- la documentazione precedente è preservata nella nuova voce **Guida**;
- corretto `FormHelper::VERSION`, rimasto erroneamente a 1.3.67 nella release 1.3.69;
- Builder, drag & drop e logica dati della 1.3.69 non modificati.

SHA-256 pacchetto: `$SHA256`
EOF

# Update server metadata with the exact package hash.
python3 - "$ROOT/updates/pkg_decaroforms.xml" "$NEW_VERSION" "$SHA256" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1]); version = sys.argv[2]; sha = sys.argv[3]
s = p.read_text(encoding='utf-8')
s = re.sub(r'<version>[^<]+</version>', f'<version>{version}</version>', s, count=1)
s = re.sub(r'https://raw\.githubusercontent\.com/xdecaro/forms/main/releases/[^/]+/pkg_decaroforms_[^<]+\.zip',
           f'https://raw.githubusercontent.com/xdecaro/forms/main/releases/{version}/pkg_decaroforms_{version}.zip', s, count=1)
s = re.sub(r'<sha256>[^<]+</sha256>', f'<sha256>{sha}</sha256>', s, count=1)
p.write_text(s, encoding='utf-8')
PY

# Prepend changelog entry only once.
python3 - "$ROOT/updates/changelog.xml" "$NEW_VERSION" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]); version = sys.argv[2]
s = p.read_text(encoding='utf-8')
if f'<version>{version}</version>' not in s:
    entry = ("\n\t<changelog>\n"
             "\t\t<element>pkg_decaroforms</element>\n"
             "\t\t<type>package</type>\n"
             f"\t\t<version>{version}</version>\n"
             "\t\t<note>Informazioni uniformata allo standard xdecaro/Competitions: stato prodotto e ambiente, estensioni incluse, aggiornamenti Joomla, componenti collegati e diagnostica tecnica con copia/download. Aggiunta voce Guida separata preservando shortcode, funzioni e dettagli precedenti. Corretto FormHelper::VERSION. Builder e motori drag 1.3.69 invariati.</note>\n"
             "\t</changelog>")
    s = s.replace('<changelogs>', '<changelogs>' + entry, 1)
    p.write_text(s, encoding='utf-8')
PY

# Final package/update validation.
unzip -t "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" >/dev/null
unzip -t "$OUT/com_decaroforms_${NEW_VERSION}.zip" >/dev/null
unzip -t "$OUT/plg_system_decaroforms_${NEW_VERSION}.zip" >/dev/null
unzip -t "$OUT/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip" >/dev/null
python3 - "$ROOT/updates/pkg_decaroforms.xml" "$ROOT/updates/changelog.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
for path in sys.argv[1:]: ET.parse(path)
PY

grep -q "<version>${NEW_VERSION}</version>" "$ROOT/updates/pkg_decaroforms.xml"
grep -q "<sha256>${SHA256}</sha256>" "$ROOT/updates/pkg_decaroforms.xml"

# Check that the package contains all newly required runtime files.
for required in \
  'media/css/information.css' \
  'media/js/information.js' \
  'administrator/components/com_decaroforms/src/Model/InformationModel.php' \
  'administrator/components/com_decaroforms/src/View/Guide/HtmlView.php' \
  'administrator/components/com_decaroforms/tmpl/guide/default.php'; do
  unzip -Z1 "$OUT/com_decaroforms_${NEW_VERSION}.zip" | grep -Fxq "$required" || {
    echo "Missing packaged file: $required" >&2
    exit 1
  }
done

echo "Forms $NEW_VERSION built successfully"
echo "Package: $OUT/pkg_decaroforms_${NEW_VERSION}.zip"
echo "SHA256: $SHA256"
