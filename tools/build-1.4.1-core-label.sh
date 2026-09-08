#!/usr/bin/env bash
set -Eeuo pipefail

BASE_VERSION="1.4.0"
NEW_VERSION="1.4.1"
RELEASE_DATE="2026-09-08"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_ZIP="$ROOT/releases/$BASE_VERSION/pkg_decaroforms_$BASE_VERSION.zip"
OUT="$ROOT/releases/$NEW_VERSION"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

[[ -f "$BASE_ZIP" ]] || { echo "Base package not found: $BASE_ZIP" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT" "$WORK/outer" "$WORK/component-old" "$WORK/component" "$WORK/system-old" "$WORK/system" "$WORK/editor-old" "$WORK/editor"
unzip -q "$BASE_ZIP" -d "$WORK/outer"
unzip -q "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" -d "$WORK/component-old"
unzip -q "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" -d "$WORK/component"
unzip -q "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" -d "$WORK/system-old"
unzip -q "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" -d "$WORK/system"
unzip -q "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip" -d "$WORK/editor-old"
unzip -q "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip" -d "$WORK/editor"

MODEL="$WORK/component/administrator/components/com_decaroforms/src/Model/InformationModel.php"
TPL="$WORK/component/administrator/components/com_decaroforms/tmpl/information/default.php"
VIEW="$WORK/component/administrator/components/com_decaroforms/src/View/Information/HtmlView.php"
HELPER="$WORK/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"

python3 - "$MODEL" "$TPL" "$WORK/component" <<'PY'
from pathlib import Path
import re, sys
model = Path(sys.argv[1])
tpl = Path(sys.argv[2])
component = Path(sys.argv[3])

s = model.read_text(encoding='utf-8')
old = "'name' => 'Xdecaro Core',"
new = "'name' => 'Core by xdecaro',"
if s.count(old) != 1:
    raise SystemExit('Core integration display name marker not found exactly once')
s = s.replace(old, new, 1)
model.write_text(s, encoding='utf-8')

s = tpl.read_text(encoding='utf-8')
replacements = {
    "'Xdecaro Core: ' .": "'Core by xdecaro: ' .",
    '<div class="dfi-row"><dt>Xdecaro Core</dt>': '<div class="dfi-row"><dt>Core by xdecaro</dt>',
}
for old, new in replacements.items():
    if s.count(old) != 1:
        raise SystemExit(f'Template marker not found exactly once: {old}')
    s = s.replace(old, new, 1)
tpl.write_text(s, encoding='utf-8')

for tag in ('it-IT', 'en-GB', 'fr-FR'):
    p = component / 'administrator/components/com_decaroforms/language' / tag / 'com_decaroforms.ini'
    s = p.read_text(encoding='utf-8')
    pattern = re.compile(r'(?m)^COM_DECAROFORMS_INFO_CHECK_CORE=.*$')
    if not pattern.search(s):
        raise SystemExit(f'Core translation key missing in {tag}')
    s = pattern.sub('COM_DECAROFORMS_INFO_CHECK_CORE="Core by xdecaro"', s, count=1)
    p.write_text(s, encoding='utf-8')
PY

python3 - "$HELPER" "$VIEW" "$NEW_VERSION" <<'PY'
from pathlib import Path
import re, sys
helper = Path(sys.argv[1]); view = Path(sys.argv[2]); version = sys.argv[3]
s = helper.read_text(encoding='utf-8')
s, n = re.subn(r"public const VERSION\s*=\s*'[^']+';", f"public const VERSION = '{version}';", s, count=1)
if n != 1: raise SystemExit('Unable to update FormHelper::VERSION')
helper.write_text(s, encoding='utf-8')
s = view.read_text(encoding='utf-8')
s, n = re.subn(r"'version'\s*=>\s*'[^']+'", f"'version' => '{version}'", s)
if n < 2: raise SystemExit('Unable to update Information asset versions')
view.write_text(s, encoding='utf-8')
PY

python3 - "$WORK/component/com_decaroforms.xml" "$WORK/system/decaroforms.xml" "$WORK/editor/decaroforms.xml" "$NEW_VERSION" "$RELEASE_DATE" <<'PY'
from pathlib import Path
import re, sys
version, release_date = sys.argv[4], sys.argv[5]
for filename in sys.argv[1:4]:
    p = Path(filename)
    s = p.read_text(encoding='utf-8')
    s, n = re.subn(r'<version>[^<]+</version>', f'<version>{version}</version>', s, count=1)
    if n != 1: raise SystemExit(f'Version not found in {filename}')
    s = re.sub(r'<creationDate>[^<]+</creationDate>', f'<creationDate>{release_date}</creationDate>', s, count=1)
    p.write_text(s, encoding='utf-8')
PY

python3 - "$WORK/component-old" "$WORK/component" "$WORK/system-old" "$WORK/system" "$WORK/editor-old" "$WORK/editor" <<'PY'
from pathlib import Path
import hashlib, sys

def hashes(root):
    out = {}
    for p in Path(root).rglob('*'):
        if p.is_file(): out[str(p.relative_to(root))] = hashlib.sha256(p.read_bytes()).hexdigest()
    return out
old, new = hashes(sys.argv[1]), hashes(sys.argv[2])
allowed = {
    'com_decaroforms.xml',
    'administrator/components/com_decaroforms/src/Model/InformationModel.php',
    'administrator/components/com_decaroforms/tmpl/information/default.php',
    'administrator/components/com_decaroforms/src/Helper/FormHelper.php',
    'administrator/components/com_decaroforms/src/View/Information/HtmlView.php',
    'administrator/components/com_decaroforms/language/it-IT/com_decaroforms.ini',
    'administrator/components/com_decaroforms/language/en-GB/com_decaroforms.ini',
    'administrator/components/com_decaroforms/language/fr-FR/com_decaroforms.ini',
}
unexpected = sorted(p for p, h in old.items() if new.get(p) != h and p not in allowed)
if unexpected: raise SystemExit('Unexpected component regressions: ' + ', '.join(unexpected))
for old_root, new_root in ((sys.argv[3], sys.argv[4]), (sys.argv[5], sys.argv[6])):
    oh, nh = hashes(old_root), hashes(new_root)
    unexpected = sorted(p for p, h in oh.items() if nh.get(p) != h and p != 'decaroforms.xml')
    if unexpected: raise SystemExit('Unexpected plugin regressions: ' + ', '.join(unexpected))
PY

php -l "$MODEL" >/dev/null
php -l "$TPL" >/dev/null
php -l "$VIEW" >/dev/null
php -l "$HELPER" >/dev/null
python3 - "$WORK/component/com_decaroforms.xml" "$WORK/system/decaroforms.xml" "$WORK/editor/decaroforms.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
for p in sys.argv[1:]: ET.parse(p)
PY

grep -Fq "'name' => 'Core by xdecaro'" "$MODEL"
grep -Fq 'Core by xdecaro:' "$TPL"
grep -Fq '<dt>Core by xdecaro</dt>' "$TPL"
if grep -Fq "'name' => 'Xdecaro Core'" "$MODEL"; then echo 'Old Core display name remains' >&2; exit 1; fi

rm -f "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip"
(cd "$WORK/component" && zip -qr "$WORK/outer/com_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')
(cd "$WORK/system" && zip -qr "$WORK/outer/plg_system_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')
(cd "$WORK/editor" && zip -qr "$WORK/outer/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')

python3 - "$WORK/outer/pkg_decaroforms.xml" "$BASE_VERSION" "$NEW_VERSION" "$RELEASE_DATE" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1]); base, new, release_date = sys.argv[2:5]
s = p.read_text(encoding='utf-8').replace(base, new)
s = re.sub(r'<creationDate>[^<]+</creationDate>', f'<creationDate>{release_date}</creationDate>', s, count=1)
p.write_text(s, encoding='utf-8')
PY

(cd "$WORK/outer" && zip -qr "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store' '*.log' '*.tmp')
cp "$WORK/outer/com_decaroforms_${NEW_VERSION}.zip" "$OUT/com_decaroforms_${NEW_VERSION}.zip"
cp "$WORK/outer/plg_system_decaroforms_${NEW_VERSION}.zip" "$OUT/plg_system_decaroforms_${NEW_VERSION}.zip"
cp "$WORK/outer/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip" "$OUT/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip"
cp "$WORK/outer/pkg_decaroforms.xml" "$OUT/pkg_decaroforms.xml"

SHA256="$(sha256sum "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | awk '{print $1}')"
printf '%s  %s\n' "$SHA256" "pkg_decaroforms_${NEW_VERSION}.zip" > "$OUT/SHA256SUMS.txt"
cat > "$OUT/README.md" <<EOF
# Forms $NEW_VERSION

Correzione naming UI dell'integrazione Core.

- il nome visibile diventa **Core by xdecaro**;
- identificatori tecnici invariati: \`pkg_xdecarocore\`, namespace \`Xdecaro\\Core\`, repository \`xdecaro/core\`;
- nessuna modifica a Builder, invii, database o logica applicativa.

SHA-256 pacchetto: \`$SHA256\`
EOF

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update><name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description><element>pkg_decaroforms</element><type>package</type><client>site</client><version>$NEW_VERSION</version><downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/$NEW_VERSION/pkg_decaroforms_$NEW_VERSION.zip</downloadurl></downloads><changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags><maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl><targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA256</sha256></update></updates>
EOF

python3 - "$ROOT/updates/changelog.xml" "$NEW_VERSION" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]); version = sys.argv[2]
s = p.read_text(encoding='utf-8')
if f'<version>{version}</version>' not in s:
    entry = ("\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n"
             f"\t\t<version>{version}</version>\n"
             "\t\t<note>Corretto il nome visibile dell'integrazione da Xdecaro Core a Core by xdecaro. Identificatori tecnici invariati.</note>\n\t</changelog>\n")
    s = s.replace('<changelogs>\n', '<changelogs>\n' + entry, 1)
    p.write_text(s, encoding='utf-8')
PY

python3 - "$ROOT/README.md" "$BASE_VERSION" "$NEW_VERSION" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]); base, new = sys.argv[2:4]
s = p.read_text(encoding='utf-8')
marker = f'**{base}**'
if s.count(marker) != 1: raise SystemExit('README version marker not found exactly once')
s = s.replace(marker, f'**{new}**', 1)
s = s.replace('optional Xdecaro Core 1.0+ detection', 'optional Core by xdecaro 1.0+ detection')
p.write_text(s, encoding='utf-8')
PY

unzip -t "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" >/dev/null
unzip -p "$OUT/com_decaroforms_${NEW_VERSION}.zip" administrator/components/com_decaroforms/src/Model/InformationModel.php | grep -Fq "'name' => 'Core by xdecaro'"
unzip -p "$OUT/com_decaroforms_${NEW_VERSION}.zip" administrator/components/com_decaroforms/tmpl/information/default.php | grep -Fq 'Core by xdecaro:'
python3 - "$ROOT/updates/pkg_decaroforms.xml" "$ROOT/updates/changelog.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
for p in sys.argv[1:]: ET.parse(p)
PY

echo "Built Forms $NEW_VERSION"
echo "SHA256: $SHA256"
