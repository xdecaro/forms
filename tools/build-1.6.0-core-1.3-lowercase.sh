#!/usr/bin/env bash
set -Eeuo pipefail
trap 'status=$?; echo "Build failed at line ${LINENO}: ${BASH_COMMAND}" >&2; exit "$status"' ERR

BASE_VERSION="1.5.1"
NEW_VERSION="1.6.0"
RELEASE_DATE="2026-09-09"
MINIMUM_CORE="1.3.0"
MINIMUM_CORE_UI="1.3.0"
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
VIEW="$WORK/component/administrator/components/com_decaroforms/src/View/Information/HtmlView.php"
HELPER="$WORK/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
CORE_TPL="$WORK/component/administrator/components/com_decaroforms/tmpl/information/core.php"
DEFAULT_TPL="$WORK/component/administrator/components/com_decaroforms/tmpl/information/default.php"
BRIDGE="$WORK/component/media/css/core-bridge.css"

for file in "$MODEL" "$VIEW" "$HELPER" "$CORE_TPL" "$DEFAULT_TPL" "$BRIDGE"; do
  [[ -f "$file" ]] || { echo "Required Forms source missing: $file" >&2; exit 1; }
done

# Migrate only Forms' consumption of Core. Forms identities and business logic stay untouched.
python3 - "$MODEL" "$VIEW" "$MINIMUM_CORE" "$MINIMUM_CORE_UI" <<'PY'
from pathlib import Path
import sys

model = Path(sys.argv[1])
view = Path(sys.argv[2])
minimum_core = sys.argv[3]
minimum_ui = sys.argv[4]

s = model.read_text(encoding='utf-8')
replacements = [
    ("public const MINIMUM_CORE = '1.0.0';", f"public const MINIMUM_CORE = '{minimum_core}';"),
    ("class_exists('\\\\Xdecaro\\\\Core\\\\Version')", "class_exists('\\\\xdecaro\\\\Core\\\\Version')"),
    ("\\Xdecaro\\Core\\Version::VERSION", "\\xdecaro\\Core\\Version::VERSION"),
]
for old, new in replacements:
    if s.count(old) != 1:
        raise SystemExit(f'InformationModel marker not found exactly once: {old}')
    s = s.replace(old, new, 1)
model.write_text(s, encoding='utf-8')

s = view.read_text(encoding='utf-8')
replacements = [
    ("private const MINIMUM_CORE_UI_VERSION = '1.1.0';", f"private const MINIMUM_CORE_UI_VERSION = '{minimum_ui}';"),
    ("\\Xdecaro\\Core\\Version::class", "\\xdecaro\\Core\\Version::class"),
    ("\\Xdecaro\\Core\\Version::VERSION", "\\xdecaro\\Core\\Version::VERSION"),
    ("\\Xdecaro\\Core\\Asset\\AssetService::class", "\\xdecaro\\Core\\Asset\\AssetService::class"),
    ("new \\Xdecaro\\Core\\Asset\\AssetService()", "new \\xdecaro\\Core\\Asset\\AssetService()"),
]
for old, new in replacements:
    if s.count(old) != 1:
        raise SystemExit(f'Information HtmlView marker not found exactly once: {old}')
    s = s.replace(old, new, 1)
view.write_text(s, encoding='utf-8')
PY

# Fail if a legacy Core PHP namespace reference survives in the component payload.
python3 - "$WORK/component" <<'PY'
from pathlib import Path
import re, sys
root = Path(sys.argv[1])
pattern = re.compile(r'Xdecaro\\+Core')
text_suffixes = {'.php', '.xml', '.ini', '.json', '.md', '.css', '.js', '.txt'}
found = []
for p in root.rglob('*'):
    if not p.is_file() or p.suffix.lower() not in text_suffixes:
        continue
    try:
        text = p.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        continue
    if pattern.search(text):
        found.append(str(p.relative_to(root)))
if found:
    raise SystemExit('Legacy Xdecaro\\Core namespace remains in: ' + ', '.join(found))
PY

# Version/cache bump only across the three already-published package children.
python3 - "$WORK/component" "$WORK/system" "$WORK/editor" "$BASE_VERSION" "$NEW_VERSION" "$RELEASE_DATE" <<'PY'
from pathlib import Path
import re, sys
roots = [Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])]
old, new, release_date = sys.argv[4], sys.argv[5], sys.argv[6]
text_suffixes = {'.php', '.xml', '.ini', '.json', '.md', '.css', '.js', '.txt'}
for root in roots:
    for p in root.rglob('*'):
        if not p.is_file() or p.suffix.lower() not in text_suffixes:
            continue
        try:
            s = p.read_text(encoding='utf-8')
        except UnicodeDecodeError:
            continue
        if old in s:
            s = s.replace(old, new)
        if p.name in {'com_decaroforms.xml', 'decaroforms.xml'}:
            s = re.sub(r'<creationDate>[^<]+</creationDate>', f'<creationDate>{release_date}</creationDate>', s, count=1)
        p.write_text(s, encoding='utf-8')
PY

# Exact regression guard: after normalizing only version/date and the approved Core namespace/minimum changes,
# every other Forms file must remain equivalent to 1.5.1.
python3 - "$WORK/component-old" "$WORK/component" "$WORK/system-old" "$WORK/system" "$WORK/editor-old" "$WORK/editor" "$BASE_VERSION" "$NEW_VERSION" "$RELEASE_DATE" <<'PY'
from pathlib import Path
import re, sys
old_v, new_v, release_date = sys.argv[7], sys.argv[8], sys.argv[9]
text_suffixes = {'.php', '.xml', '.ini', '.json', '.md', '.css', '.js', '.txt'}
allowed_core = {
    'administrator/components/com_decaroforms/src/Model/InformationModel.php',
    'administrator/components/com_decaroforms/src/View/Information/HtmlView.php',
}

def file_map(root):
    root = Path(root)
    return {str(p.relative_to(root)): p for p in root.rglob('*') if p.is_file()}

def normalized(path, is_new):
    data = path.read_bytes()
    if path.suffix.lower() not in text_suffixes:
        return data
    try:
        s = data.decode('utf-8')
    except UnicodeDecodeError:
        return data
    if is_new:
        s = s.replace(new_v, old_v)
        s = re.sub(r'<creationDate>2026-09-09</creationDate>', '<creationDate>2026-09-08</creationDate>', s)
    return s.encode('utf-8')

oldc, newc = file_map(sys.argv[1]), file_map(sys.argv[2])
if set(oldc) != set(newc):
    raise SystemExit('Unexpected component file add/remove')
for path in sorted(oldc):
    old_data = normalized(oldc[path], False)
    new_data = normalized(newc[path], True)
    if path in allowed_core:
        old_text = old_data.decode('utf-8')
        expected = old_text
        if path.endswith('InformationModel.php'):
            expected = expected.replace("public const MINIMUM_CORE = '1.0.0';", "public const MINIMUM_CORE = '1.3.0';")
            expected = expected.replace("class_exists('\\\\Xdecaro\\\\Core\\\\Version')", "class_exists('\\\\xdecaro\\\\Core\\\\Version')")
            expected = expected.replace('\\Xdecaro\\Core\\Version::VERSION', '\\xdecaro\\Core\\Version::VERSION')
        else:
            expected = expected.replace("private const MINIMUM_CORE_UI_VERSION = '1.1.0';", "private const MINIMUM_CORE_UI_VERSION = '1.3.0';")
            expected = expected.replace('\\Xdecaro\\Core\\Version::class', '\\xdecaro\\Core\\Version::class')
            expected = expected.replace('\\Xdecaro\\Core\\Version::VERSION', '\\xdecaro\\Core\\Version::VERSION')
            expected = expected.replace('\\Xdecaro\\Core\\Asset\\AssetService::class', '\\xdecaro\\Core\\Asset\\AssetService::class')
            expected = expected.replace('new \\Xdecaro\\Core\\Asset\\AssetService()', 'new \\xdecaro\\Core\\Asset\\AssetService()')
        if expected.encode('utf-8') != new_data:
            raise SystemExit('Unexpected Core migration change: ' + path)
    elif old_data != new_data:
        raise SystemExit('Unexpected component regression: ' + path)

for old_root, new_root, label in ((sys.argv[3], sys.argv[4], 'system'), (sys.argv[5], sys.argv[6], 'editors-xtd')):
    oldf, newf = file_map(old_root), file_map(new_root)
    if set(oldf) != set(newf):
        raise SystemExit(f'Unexpected {label} file add/remove')
    for path in sorted(oldf):
        if normalized(oldf[path], False) != normalized(newf[path], True):
            raise SystemExit(f'Unexpected {label} regression: {path}')
PY

while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$WORK/component" "$WORK/system" "$WORK/editor" -type f -name '*.php' -print0)
python3 - "$WORK/component" "$WORK/system" "$WORK/editor" <<'PY'
from pathlib import Path
import sys, xml.etree.ElementTree as ET
for root in map(Path, sys.argv[1:]):
    for p in root.rglob('*.xml'):
        ET.parse(p)
print('PHP/XML validation: OK')
PY

grep -Fq "public const MINIMUM_CORE = '$MINIMUM_CORE';" "$MODEL"
grep -Fq 'xdecaro\Core\Version::VERSION' "$MODEL"
grep -Fq "MINIMUM_CORE_UI_VERSION = '$MINIMUM_CORE_UI'" "$VIEW"
grep -Fq 'xdecaro\Core\Asset\AssetService' "$VIEW"
grep -Fq 'useComponents($wa)' "$VIEW"
grep -Fq "setLayout('core')" "$VIEW"
grep -Fq 'dfi-page xdecaro-scope forms-core-scope' "$CORE_TPL"
grep -Fq -- '--xdecaro-color-text' "$BRIDGE"
if grep -Fq '!important' "$BRIDGE"; then
  echo 'Core bridge must not use !important' >&2
  exit 1
fi

rm -f "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip"
(cd "$WORK/component" && zip -qr "$WORK/outer/com_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')
(cd "$WORK/system" && zip -qr "$WORK/outer/plg_system_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')
(cd "$WORK/editor" && zip -qr "$WORK/outer/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')

python3 - "$WORK/outer" "$BASE_VERSION" "$NEW_VERSION" "$RELEASE_DATE" <<'PY'
from pathlib import Path
import re, sys
root = Path(sys.argv[1]); old, new, release_date = sys.argv[2:5]
for p in root.iterdir():
    if not p.is_file() or p.suffix.lower() == '.zip':
        continue
    try:
        s = p.read_text(encoding='utf-8')
    except UnicodeDecodeError:
        continue
    s = s.replace(old, new)
    if p.name == 'pkg_decaroforms.xml':
        s = re.sub(r'<creationDate>[^<]+</creationDate>', f'<creationDate>{release_date}</creationDate>', s, count=1)
    p.write_text(s, encoding='utf-8')
PY
python3 - "$WORK/outer/pkg_decaroforms.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
ET.parse(sys.argv[1])
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

Canonical Core 1.3 namespace migration.

- Forms now consumes Core through the canonical \`xdecaro\\Core\` PHP namespace;
- optional Core diagnostics and Core UI require Core by xdecaro 1.3.0 or newer;
- Core remains optional and the local Information UI fallback is preserved;
- \`com_decaroforms\`, \`pkg_decaroforms\`, plugin identities, Forms data and product behavior are unchanged.

SHA-256 package: \`$SHA256\`
EOF

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update><name>Forms by xdecaro</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description><element>pkg_decaroforms</element><type>package</type><client>site</client><version>$NEW_VERSION</version><downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/$NEW_VERSION/pkg_decaroforms_$NEW_VERSION.zip</downloadurl></downloads><changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags><maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl><targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA256</sha256></update></updates>
EOF

python3 - "$ROOT/updates/changelog.xml" "$NEW_VERSION" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]); v = sys.argv[2]; s = p.read_text(encoding='utf-8')
if f'<version>{v}</version>' not in s:
    note = 'Core: migrato il consumo delle API pubbliche al namespace canonico xdecaro\\Core introdotto da Core 1.3.0. Diagnostica e Core UI richiedono Core 1.3.0+ quando usate; Core resta opzionale e il fallback locale resta invariato. Nessuna modifica a dati, Builder, invii, plugin, ACL o identità Joomla.'
    entry = f'\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>{v}</version>\n\t\t<note>{note}</note>\n\t</changelog>\n'
    s = s.replace('<changelogs>\n', '<changelogs>\n' + entry, 1)
    p.write_text(s, encoding='utf-8')
PY

python3 - "$ROOT/README.md" "$BASE_VERSION" "$NEW_VERSION" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]); old, new = sys.argv[2:4]; s = p.read_text(encoding='utf-8')
marker = f'**{old}**'
if s.count(marker) != 1:
    raise SystemExit('README current-version marker not found exactly once')
p.write_text(s.replace(marker, f'**{new}**', 1), encoding='utf-8')
PY

unzip -t "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" >/dev/null
unzip -t "$OUT/com_decaroforms_${NEW_VERSION}.zip" >/dev/null
python3 - "$ROOT/updates/pkg_decaroforms.xml" "$ROOT/updates/changelog.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
for p in sys.argv[1:]: ET.parse(p)
PY
grep -Fq "<version>$NEW_VERSION</version>" "$ROOT/updates/pkg_decaroforms.xml"
grep -Fq "$SHA256" "$ROOT/updates/pkg_decaroforms.xml"

echo "Built Forms $NEW_VERSION"
echo "SHA256: $SHA256"
