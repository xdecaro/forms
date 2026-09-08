#!/usr/bin/env bash
set -Eeuo pipefail
trap 'status=$?; echo "Build failed at line ${LINENO}: ${BASH_COMMAND}" >&2; exit "$status"' ERR

BASE_VERSION="1.5.0"
NEW_VERSION="1.5.1"
RELEASE_DATE="2026-09-08"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_ZIP="$ROOT/releases/$BASE_VERSION/pkg_decaroforms_$BASE_VERSION.zip"
OUT="$ROOT/releases/$NEW_VERSION"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK" /tmp/forms-151-builder.js' EXIT

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

BUILDER="$WORK/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
[[ -f "$BUILDER" ]] || { echo "Builder template not found: $BUILDER" >&2; exit 1; }

# Fix only the authoritative 1.3.69 Field-active selectors. The browser evidence
# shows .df-layout-card.is-active is present but the scoped rule does not match;
# removing the unnecessary .df-builder ancestor makes the existing visual rule
# apply without changing colors, hierarchy, drag logic or data behavior.
python3 - "$BUILDER" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')
comment = '/* Forms 1.3.69: authoritative hierarchical selection state. */'
start = s.find(comment)
if start < 0:
    raise SystemExit('Authoritative 1.3.69 selection block not found')

head, tail = s[:start], s[start:]
replacements = [
    ('.df-builder .df-layout-card.is-active{', '.df-layout-card.is-active{'),
    ('.df-builder .df-layout-card.is-active [data-canvas-edit]{', '.df-layout-card.is-active [data-canvas-edit]{'),
]
for old, new in replacements:
    if tail.count(old) != 1:
        raise SystemExit(f'Expected exactly one selector in authoritative block: {old}')
    tail = tail.replace(old, new, 1)

s = head + tail
p.write_text(s, encoding='utf-8')
PY

# Guard the exact visual contract: same purple background/border/left bar,
# only the selector scope changes.
grep -Fq '.df-layout-card.is-active{' "$BUILDER"
grep -Fq '.df-layout-card.is-active [data-canvas-edit]{' "$BUILDER"
grep -Fq 'background:color-mix(in srgb,#7c3aed 9%,var(--bs-body-bg,#fff))!important;' "$BUILDER"
grep -Fq 'border-color:color-mix(in srgb,#7c3aed 48%,var(--bs-border-color,#d9dee5))!important;' "$BUILDER"
grep -Fq 'box-shadow:inset 4px 0 0 #7c3aed,0 0 0 1px color-mix(in srgb,#7c3aed 14%,transparent),0 1px 2px rgba(15,23,42,.05)!important;' "$BUILDER"

# Bump embedded package versions/cache-busters without altering behavior.
python3 - "$WORK/component" "$WORK/system" "$WORK/editor" "$BASE_VERSION" "$NEW_VERSION" <<'PY'
from pathlib import Path
import sys

roots = [Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3])]
old, new = sys.argv[4], sys.argv[5]
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
            p.write_text(s.replace(old, new), encoding='utf-8')
PY

# Regression guard: after normalizing version strings, component differences are
# limited to the Builder template; both plugins are behavior-identical.
python3 - "$WORK/component-old" "$WORK/component" "$WORK/system-old" "$WORK/system" "$WORK/editor-old" "$WORK/editor" "$BASE_VERSION" "$NEW_VERSION" <<'PY'
from pathlib import Path
import sys

old_v, new_v = sys.argv[7], sys.argv[8]
text_suffixes = {'.php', '.xml', '.ini', '.json', '.md', '.css', '.js', '.txt'}

def files(root):
    root = Path(root)
    return {str(p.relative_to(root)): p for p in root.rglob('*') if p.is_file()}

def normalized_bytes(path, is_new):
    data = path.read_bytes()
    if path.suffix.lower() in text_suffixes:
        try:
            text = data.decode('utf-8')
        except UnicodeDecodeError:
            return data
        if is_new:
            text = text.replace(new_v, old_v)
        return text.encode('utf-8')
    return data

old_comp, new_comp = files(sys.argv[1]), files(sys.argv[2])
allowed = {'administrator/components/com_decaroforms/tmpl/builder/default.php'}
for path in sorted(set(old_comp) | set(new_comp)):
    if path not in old_comp or path not in new_comp:
        raise SystemExit('Unexpected component file add/remove: ' + path)
    if normalized_bytes(old_comp[path], False) != normalized_bytes(new_comp[path], True) and path not in allowed:
        raise SystemExit('Unexpected component regression: ' + path)

for old_root, new_root, label in ((sys.argv[3], sys.argv[4], 'system'), (sys.argv[5], sys.argv[6], 'editors-xtd')):
    old_files, new_files = files(old_root), files(new_root)
    if set(old_files) != set(new_files):
        raise SystemExit(f'Unexpected {label} plugin file add/remove')
    for path in sorted(old_files):
        if normalized_bytes(old_files[path], False) != normalized_bytes(new_files[path], True):
            raise SystemExit(f'Unexpected {label} plugin regression: {path}')
PY

# Syntax validation before packaging.
while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$WORK/component" "$WORK/system" "$WORK/editor" -type f -name '*.php' -print0)
python3 - "$WORK/component" "$WORK/system" "$WORK/editor" <<'PY'
from pathlib import Path
import sys, xml.etree.ElementTree as ET
for root in map(Path, sys.argv[1:]):
    for p in root.rglob('*.xml'):
        ET.parse(p)
print('PHP/XML validation: OK')
PY

# Inline Builder JavaScript syntax check after neutralizing PHP blocks.
python3 - "$BUILDER" > /tmp/forms-151-builder.js <<'PY'
from pathlib import Path
import re, sys
s = Path(sys.argv[1]).read_text(encoding='utf-8')
s = re.sub(r'<\?(?:php|=).*?\?>', 'null', s, flags=re.S)
parts = re.findall(r'<script(?:\s[^>]*)?>(.*?)</script>', s, flags=re.S | re.I)
print('\n'.join(parts))
PY
node --check /tmp/forms-151-builder.js >/dev/null

# Rebuild child ZIPs with the new versioned filenames.
rm -f "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip"
(cd "$WORK/component" && zip -qr "$WORK/outer/com_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')
(cd "$WORK/system" && zip -qr "$WORK/outer/plg_system_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')
(cd "$WORK/editor" && zip -qr "$WORK/outer/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')

# Update package-level manifest and any text metadata copied from 1.5.0.
python3 - "$WORK/outer" "$BASE_VERSION" "$NEW_VERSION" "$RELEASE_DATE" <<'PY'
from pathlib import Path
import sys
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
        import re
        s = re.sub(r'<creationDate>[^<]+</creationDate>', f'<creationDate>{release_date}</creationDate>', s, count=1)
    p.write_text(s, encoding='utf-8')
PY
python3 - "$WORK/outer/pkg_decaroforms.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
ET.parse(sys.argv[1])
PY

# Build the installable package and release artifacts.
(cd "$WORK/outer" && zip -qr "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store' '*.log' '*.tmp')
cp "$WORK/outer/com_decaroforms_${NEW_VERSION}.zip" "$OUT/com_decaroforms_${NEW_VERSION}.zip"
cp "$WORK/outer/plg_system_decaroforms_${NEW_VERSION}.zip" "$OUT/plg_system_decaroforms_${NEW_VERSION}.zip"
cp "$WORK/outer/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip" "$OUT/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip"
cp "$WORK/outer/pkg_decaroforms.xml" "$OUT/pkg_decaroforms.xml"

SHA256="$(sha256sum "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | awk '{print $1}')"
printf '%s  %s\n' "$SHA256" "pkg_decaroforms_${NEW_VERSION}.zip" > "$OUT/SHA256SUMS.txt"
cat > "$OUT/README.md" <<EOF
# Forms $NEW_VERSION

Builder active-field selector hotfix.

- the authoritative Field active rule now targets \`.df-layout-card.is-active\` directly;
- the existing purple 9% background, 4px left bar, purple border and edit-control treatment are unchanged;
- JavaScript selection state, Section/Row context, drag engines, Row IDs, widths, Undo/Redo and stored data are unchanged;
- Core integration and the Information/Diagnostics Core UI remain unchanged;
- system and editors-xtd plugins contain version-only changes.

SHA-256 package: \`$SHA256\`
EOF

# Update Joomla feed, changelog and repository version marker.
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
             "\t\t<note>Builder: corretto il selettore CSS autorevole del Campo attivo. La classe .is-active era presente nel DOM ma la regola dipendeva da un antenato .df-builder che non corrispondeva alla struttura effettiva, lasciando background bianco, bordo standard e ombra base. Il Campo attivo ora usa direttamente .df-layout-card.is-active mantenendo invariati colori, gerarchia, drag, JavaScript, dati e integrazione Core.</note>\n\t</changelog>\n")
    s = s.replace('<changelogs>\n', '<changelogs>\n' + entry, 1)
    p.write_text(s, encoding='utf-8')
PY

python3 - "$ROOT/README.md" "$BASE_VERSION" "$NEW_VERSION" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]); old, new = sys.argv[2:4]
s = p.read_text(encoding='utf-8')
marker = f'**{old}**'
if s.count(marker) != 1:
    raise SystemExit('README current-version marker not found exactly once')
s = s.replace(marker, f'**{new}**', 1)
p.write_text(s, encoding='utf-8')
PY

# Final package/feed checks.
unzip -t "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" >/dev/null
unzip -l "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | grep -Fq "com_decaroforms_${NEW_VERSION}.zip"
unzip -l "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | grep -Fq "plg_system_decaroforms_${NEW_VERSION}.zip"
unzip -l "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | grep -Fq "plg_editors-xtd_decaroforms_${NEW_VERSION}.zip"
unzip -p "$OUT/com_decaroforms_${NEW_VERSION}.zip" administrator/components/com_decaroforms/tmpl/builder/default.php | grep -Fq '.df-layout-card.is-active{'
if unzip -p "$OUT/com_decaroforms_${NEW_VERSION}.zip" administrator/components/com_decaroforms/tmpl/builder/default.php | grep -Fq '.df-builder .df-layout-card.is-active{'; then
    echo 'Old scoped active-field selector still present' >&2
    exit 1
fi
python3 - "$ROOT/updates/pkg_decaroforms.xml" "$ROOT/updates/changelog.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
for p in sys.argv[1:]: ET.parse(p)
PY
grep -Fq "<version>$NEW_VERSION</version>" "$ROOT/updates/pkg_decaroforms.xml"
grep -Fq "releases/$NEW_VERSION/pkg_decaroforms_$NEW_VERSION.zip" "$ROOT/updates/pkg_decaroforms.xml"
grep -Fq "$SHA256" "$ROOT/updates/pkg_decaroforms.xml"

echo "Built Forms $NEW_VERSION"
echo "SHA256: $SHA256"
