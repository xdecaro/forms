#!/usr/bin/env bash
set -Eeuo pipefail

BASE_VERSION="1.4.1"
NEW_VERSION="1.4.2"
RELEASE_DATE="2026-09-08"
VISIBLE_NAME="Forms by xdecaro"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_ZIP="$ROOT/releases/$BASE_VERSION/pkg_decaroforms_$BASE_VERSION.zip"
OUT="$ROOT/releases/$NEW_VERSION"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

[[ -f "$BASE_ZIP" ]] || { echo "Base package not found: $BASE_ZIP" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT" "$WORK/outer-old" "$WORK/outer" "$WORK/component-old" "$WORK/component" "$WORK/system-old" "$WORK/system" "$WORK/editor-old" "$WORK/editor"
unzip -q "$BASE_ZIP" -d "$WORK/outer-old"
cp -a "$WORK/outer-old/." "$WORK/outer/"
unzip -q "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" -d "$WORK/component-old"
unzip -q "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" -d "$WORK/component"
unzip -q "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" -d "$WORK/system-old"
unzip -q "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" -d "$WORK/system"
unzip -q "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip" -d "$WORK/editor-old"
unzip -q "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip" -d "$WORK/editor"

HELPER="$WORK/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
VIEW="$WORK/component/administrator/components/com_decaroforms/src/View/Information/HtmlView.php"

# Correct only the public extension labels. Technical identifiers remain unchanged.
python3 - "$WORK/component" "$WORK/outer" "$VISIBLE_NAME" <<'PY'
from pathlib import Path
import re, sys
component = Path(sys.argv[1])
outer = Path(sys.argv[2])
visible = sys.argv[3]

# Joomla may resolve the component name from either the administrator main
# language file or the sys language file. Normalize the exact extension-name
# key wherever it exists, without changing view/menu labels such as "Moduli".
component_matches = 0
for p in sorted(component.rglob('com_decaroforms*.ini')):
    text = p.read_text(encoding='utf-8')
    pattern = re.compile(r'(?m)^COM_DECAROFORMS\s*=\s*"[^"]*"\s*$')
    text2, count = pattern.subn(f'COM_DECAROFORMS="{visible}"', text)
    if count:
        component_matches += count
        p.write_text(text2, encoding='utf-8')

if component_matches < 1:
    raise SystemExit('No exact COM_DECAROFORMS extension-name key found in component languages')

package_files = [
    outer / 'language/it-IT/it-IT.pkg_decaroforms.sys.ini',
    outer / 'language/en-GB/en-GB.pkg_decaroforms.sys.ini',
    outer / 'language/fr-FR/fr-FR.pkg_decaroforms.sys.ini',
]
for p in package_files:
    if not p.is_file():
        raise SystemExit(f'Package language file missing: {p}')
    text = p.read_text(encoding='utf-8')
    pattern = re.compile(r'(?m)^PKG_DECAROFORMS\s*=\s*"[^"]*"\s*$')
    text2, count = pattern.subn(f'PKG_DECAROFORMS="{visible}"', text)
    if count != 1:
        raise SystemExit(f'Expected exactly one PKG_DECAROFORMS key in {p}, got {count}')
    p.write_text(text2, encoding='utf-8')
PY

# Version metadata: same established Forms release mechanism as 1.4.1.
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

python3 - "$WORK/outer/pkg_decaroforms.xml" "$BASE_VERSION" "$NEW_VERSION" "$RELEASE_DATE" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1]); base, new, release_date = sys.argv[2:5]
s = p.read_text(encoding='utf-8')
s, n = re.subn(r'<version>[^<]+</version>', f'<version>{new}</version>', s, count=1)
if n != 1: raise SystemExit('Package version not found')
s = re.sub(r'<creationDate>[^<]+</creationDate>', f'<creationDate>{release_date}</creationDate>', s, count=1)
for stem in ('com_decaroforms', 'plg_system_decaroforms', 'plg_editors-xtd_decaroforms'):
    old = f'{stem}_{base}.zip'
    new_name = f'{stem}_{new}.zip'
    if s.count(old) != 1:
        raise SystemExit(f'Nested package filename marker not found exactly once: {old}')
    s = s.replace(old, new_name, 1)
p.write_text(s, encoding='utf-8')
PY

# Regression guard: component changes are restricted to version metadata and
# exact extension-name language files. Plugins change only their manifests.
python3 - "$WORK/component-old" "$WORK/component" "$WORK/system-old" "$WORK/system" "$WORK/editor-old" "$WORK/editor" <<'PY'
from pathlib import Path
import hashlib, sys

def hashes(root):
    root = Path(root)
    return {
        str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
        for p in root.rglob('*') if p.is_file()
    }

old, new = hashes(sys.argv[1]), hashes(sys.argv[2])
changed = {p for p in set(old) | set(new) if old.get(p) != new.get(p)}
fixed_allowed = {
    'com_decaroforms.xml',
    'administrator/components/com_decaroforms/src/Helper/FormHelper.php',
    'administrator/components/com_decaroforms/src/View/Information/HtmlView.php',
}
for path in sorted(changed):
    if path in fixed_allowed:
        continue
    if path.startswith('administrator/components/com_decaroforms/language/') and path.endswith('.ini'):
        continue
    raise SystemExit('Unexpected component regression: ' + path)

if not any(p.startswith('administrator/components/com_decaroforms/language/') for p in changed):
    raise SystemExit('Component display-name language files were not changed')

for old_root, new_root in ((sys.argv[3], sys.argv[4]), (sys.argv[5], sys.argv[6])):
    oh, nh = hashes(old_root), hashes(new_root)
    changed_plugin = {p for p in set(oh) | set(nh) if oh.get(p) != nh.get(p)}
    if changed_plugin != {'decaroforms.xml'}:
        raise SystemExit('Unexpected plugin changes: ' + ', '.join(sorted(changed_plugin)))
PY

# Validate exact naming after transformation.
python3 - "$WORK/component" "$WORK/outer" "$VISIBLE_NAME" <<'PY'
from pathlib import Path
import re, sys
component = Path(sys.argv[1]); outer = Path(sys.argv[2]); visible = sys.argv[3]
component_values = []
for p in component.rglob('com_decaroforms*.ini'):
    for line in p.read_text(encoding='utf-8').splitlines():
        if re.match(r'^COM_DECAROFORMS\s*=', line):
            component_values.append((p, line))
if not component_values:
    raise SystemExit('No component name keys found after transformation')
for p, line in component_values:
    if line.strip() != f'COM_DECAROFORMS="{visible}"':
        raise SystemExit(f'Unexpected component visible name in {p}: {line}')

for rel in (
    'language/it-IT/it-IT.pkg_decaroforms.sys.ini',
    'language/en-GB/en-GB.pkg_decaroforms.sys.ini',
    'language/fr-FR/fr-FR.pkg_decaroforms.sys.ini',
):
    p = outer / rel
    lines = [line.strip() for line in p.read_text(encoding='utf-8').splitlines() if re.match(r'^PKG_DECAROFORMS\s*=', line)]
    if lines != [f'PKG_DECAROFORMS="{visible}"']:
        raise SystemExit(f'Unexpected package visible name in {p}: {lines}')
PY

php -l "$HELPER" >/dev/null
php -l "$VIEW" >/dev/null
python3 - "$WORK/component/com_decaroforms.xml" "$WORK/system/decaroforms.xml" "$WORK/editor/decaroforms.xml" "$WORK/outer/pkg_decaroforms.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
for p in sys.argv[1:]: ET.parse(p)
PY

rm -f "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip"
(cd "$WORK/component" && zip -qr "$WORK/outer/com_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')
(cd "$WORK/system" && zip -qr "$WORK/outer/plg_system_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')
(cd "$WORK/editor" && zip -qr "$WORK/outer/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')

(cd "$WORK/outer" && zip -qr "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store' '*.log' '*.tmp')
cp "$WORK/outer/com_decaroforms_${NEW_VERSION}.zip" "$OUT/com_decaroforms_${NEW_VERSION}.zip"
cp "$WORK/outer/plg_system_decaroforms_${NEW_VERSION}.zip" "$OUT/plg_system_decaroforms_${NEW_VERSION}.zip"
cp "$WORK/outer/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip" "$OUT/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip"
cp "$WORK/outer/pkg_decaroforms.xml" "$OUT/pkg_decaroforms.xml"

SHA256="$(sha256sum "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | awk '{print $1}')"
printf '%s  %s\n' "$SHA256" "pkg_decaroforms_${NEW_VERSION}.zip" > "$OUT/SHA256SUMS.txt"
cat > "$OUT/README.md" <<EOF
# Forms $NEW_VERSION

Correzione del nome pubblico mostrato da Joomla Extension Manager.

- package e componente: **Forms by xdecaro**;
- identificatori tecnici invariati: \`pkg_decaroforms\`, \`com_decaroforms\`;
- nomi delle funzioni/menu interni (ad esempio Moduli) invariati;
- nessuna modifica a Builder, invii, database o logica applicativa.

SHA-256 pacchetto: \`$SHA256\`
EOF

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update><name>Forms by xdecaro</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description><element>pkg_decaroforms</element><type>package</type><client>site</client><version>$NEW_VERSION</version><downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/$NEW_VERSION/pkg_decaroforms_$NEW_VERSION.zip</downloadurl></downloads><changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags><maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl><targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA256</sha256></update></updates>
EOF

python3 - "$ROOT/updates/changelog.xml" "$NEW_VERSION" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]); version = sys.argv[2]
s = p.read_text(encoding='utf-8')
if f'<version>{version}</version>' not in s:
    entry = ("\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n"
             f"\t\t<version>{version}</version>\n"
             "\t\t<note>Corretto il nome pubblico di package e componente in Forms by xdecaro. Identificatori tecnici e logica applicativa invariati.</note>\n\t</changelog>\n")
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
p.write_text(s, encoding='utf-8')
PY

unzip -t "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" >/dev/null
unzip -p "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" language/it-IT/it-IT.pkg_decaroforms.sys.ini | grep -Fq 'PKG_DECAROFORMS="Forms by xdecaro"'
unzip -p "$OUT/com_decaroforms_${NEW_VERSION}.zip" administrator/components/com_decaroforms/language/it-IT/com_decaroforms.ini | grep -Fq 'COM_DECAROFORMS="Forms by xdecaro"'
python3 - "$ROOT/updates/pkg_decaroforms.xml" "$ROOT/updates/changelog.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
for p in sys.argv[1:]: ET.parse(p)
PY

echo "Built Forms $NEW_VERSION"
echo "SHA256: $SHA256"
