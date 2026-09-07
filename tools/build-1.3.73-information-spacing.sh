#!/usr/bin/env bash
set -euo pipefail

BASE_VERSION="1.3.72"
NEW_VERSION="1.3.73"
RELEASE_DATE="2026-09-07"
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

CSS="$WORK/component/media/css/information.css"
[[ -f "$CSS" ]] || { echo "Information CSS not found: $CSS" >&2; exit 1; }

# Align Forms Information with the approved Courses 1.0.44 spacing.
# Only the Information stylesheet is changed; Builder, drag/drop and application logic stay untouched.
python3 - "$CSS" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')

replacements = [
    (
        '''.dfi-actions .btn {\n  min-height: 38px;\n''',
        '''.dfi-actions .btn {\n  min-height: 39px;\n'''
    ),
    (
        '''.dfi-integration {\n  display: grid;\n  grid-template-columns: minmax(220px, 1fr) minmax(320px, 1fr);\n  align-items: center;\n  gap: 20px;\n  padding: 14px 0;\n''',
        '''.dfi-integration {\n  display: grid;\n  grid-template-columns: minmax(220px, 1fr) minmax(320px, 1fr);\n  align-items: center;\n  gap: 20px;\n  padding: 14px 0 2px;\n'''
    ),
    (
        '''.dfi-technical {\n  margin-top: 17px;\n  padding-top: 14px;\n  border-top: 1px solid var(--dfi-border);\n}\n\n.dfi-technical summary {\n  width: fit-content;\n  cursor: pointer;\n  color: var(--dfi-text);\n  font-size: 12px;\n  font-weight: 700;\n}\n''',
        '''.dfi-technical {\n  margin-top: 17px;\n  padding: 11px 16px;\n  border: 1px solid var(--dfi-border);\n  border-radius: 7px;\n  background: var(--dfi-surface-soft);\n}\n\n.dfi-technical summary {\n  width: auto;\n  padding: 0;\n  cursor: pointer;\n  color: var(--dfi-text);\n  font-size: 12px;\n  font-weight: 700;\n}\n'''
    ),
    (
        '''.dfi-feedback {\n  min-height: 18px;\n  margin-top: 7px;\n''',
        '''.dfi-feedback {\n  margin-top: 7px;\n'''
    ),
]

for old, new in replacements:
    if s.count(old) != 1:
        raise SystemExit('Expected Information CSS block not found exactly once:\n' + old)
    s = s.replace(old, new, 1)

anchor = '''.dfi-card-intro {\n  margin: -2px 0 12px;\n}\n'''
addition = '''.dfi-card-intro {\n  margin: -2px 0 12px;\n}\n\n/* Keep the diagnostics privacy text on the same measured width as Courses. */\n.dfi-diagnostic-top .dfi-card-intro {\n  max-width: 760px;\n}\n'''
if s.count(anchor) != 1:
    raise SystemExit('dfi-card-intro anchor not found exactly once')
s = s.replace(anchor, addition, 1)

# Guard the exact fixes requested from the browser comparison.
if 'padding: 14px 0 2px;' not in s:
    raise SystemExit('Integration bottom spacing fix missing')
if 'padding: 11px 16px;' not in s:
    raise SystemExit('Technical details balanced padding missing')
feedback = s.split('.dfi-feedback {', 1)[1].split('}', 1)[0]
if 'min-height' in feedback:
    raise SystemExit('Feedback still reserves empty height')
if 'max-width: 760px;' not in s:
    raise SystemExit('Diagnostic intro width guard missing')

p.write_text(s, encoding='utf-8')
PY

# Keep helper and Information WebAssetManager cache marker coherent.
python3 - "$WORK/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php" "$WORK/component/administrator/components/com_decaroforms/src/View/Information/HtmlView.php" "$NEW_VERSION" <<'PY'
from pathlib import Path
import re, sys
helper = Path(sys.argv[1]); view = Path(sys.argv[2]); version = sys.argv[3]

s = helper.read_text(encoding='utf-8')
s, n = re.subn(r"public const VERSION\s*=\s*'[^']+';", f"public const VERSION = '{version}';", s, count=1)
if n != 1:
    raise SystemExit('Unable to update FormHelper::VERSION')
helper.write_text(s, encoding='utf-8')

s = view.read_text(encoding='utf-8')
s, n = re.subn(r"'version'\s*=>\s*'[^']+'", f"'version' => '{version}'", s)
if n < 2:
    raise SystemExit(f'Expected both Information asset versions, found {n}')
view.write_text(s, encoding='utf-8')
PY

# Version component and bundled plugin manifests.
python3 - "$WORK/component/com_decaroforms.xml" "$WORK/system/decaroforms.xml" "$WORK/editor/decaroforms.xml" "$NEW_VERSION" "$RELEASE_DATE" <<'PY'
from pathlib import Path
import re, sys
version, release_date = sys.argv[4], sys.argv[5]
for filename in sys.argv[1:4]:
    p = Path(filename)
    s = p.read_text(encoding='utf-8')
    s, n = re.subn(r'<version>[^<]+</version>', f'<version>{version}</version>', s, count=1)
    if n != 1:
        raise SystemExit(f'Version not found in {filename}')
    s = re.sub(r'<creationDate>[^<]+</creationDate>', f'<creationDate>{release_date}</creationDate>', s, count=1)
    p.write_text(s, encoding='utf-8')
PY

# Regression guard: no other component/plugin source may change.
python3 - "$WORK/component-old" "$WORK/component" "$WORK/system-old" "$WORK/system" "$WORK/editor-old" "$WORK/editor" <<'PY'
from pathlib import Path
import hashlib, sys

def hashes(root):
    out = {}
    for p in Path(root).rglob('*'):
        if p.is_file():
            out[str(p.relative_to(root))] = hashlib.sha256(p.read_bytes()).hexdigest()
    return out

old, new = hashes(sys.argv[1]), hashes(sys.argv[2])
allowed = {
    'com_decaroforms.xml',
    'media/css/information.css',
    'administrator/components/com_decaroforms/src/Helper/FormHelper.php',
    'administrator/components/com_decaroforms/src/View/Information/HtmlView.php',
}
unexpected = sorted(p for p, h in old.items() if new.get(p) != h and p not in allowed)
if unexpected:
    raise SystemExit('Unexpected component regressions: ' + ', '.join(unexpected))

for old_root, new_root in ((sys.argv[3], sys.argv[4]), (sys.argv[5], sys.argv[6])):
    oh, nh = hashes(old_root), hashes(new_root)
    unexpected = sorted(p for p, h in oh.items() if nh.get(p) != h and p != 'decaroforms.xml')
    if unexpected:
        raise SystemExit('Unexpected plugin regressions: ' + ', '.join(unexpected))
PY

# Validate intended files before packaging.
php -l "$WORK/component/administrator/components/com_decaroforms/src/View/Information/HtmlView.php" >/dev/null
php -l "$WORK/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php" >/dev/null
python3 - "$WORK/component/com_decaroforms.xml" "$WORK/system/decaroforms.xml" "$WORK/editor/decaroforms.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
for path in sys.argv[1:]: ET.parse(path)
PY

grep -q 'padding: 14px 0 2px;' "$CSS"
grep -A6 '^\.dfi-technical {' "$CSS" | grep -q 'padding: 11px 16px;'
grep -A8 '^\.dfi-technical {' "$CSS" | grep -q 'border-radius: 7px;'
grep -A5 '^\.dfi-feedback {' "$CSS" | grep -q 'margin-top: 7px'
if grep -A5 '^\.dfi-feedback {' "$CSS" | grep -q 'min-height'; then
  echo 'dfi-feedback still reserves min-height' >&2
  exit 1
fi
grep -A3 '^\.dfi-diagnostic-top \.dfi-card-intro {' "$CSS" | grep -q 'max-width: 760px;'

# Rebuild nested ZIPs.
rm -f "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip"
(cd "$WORK/component" && zip -qr "$WORK/outer/com_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')
(cd "$WORK/system" && zip -qr "$WORK/outer/plg_system_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')
(cd "$WORK/editor" && zip -qr "$WORK/outer/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')

# Package manifest references the new nested packages.
python3 - "$WORK/outer/pkg_decaroforms.xml" "$BASE_VERSION" "$NEW_VERSION" "$RELEASE_DATE" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1]); base, new, release_date = sys.argv[2:5]
s = p.read_text(encoding='utf-8').replace(base, new)
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

Rifinitura della pagina **Informazioni** basata sul confronto DevTools con Courses 1.0.44.

- Integrazioni: eliminato lo spazio inferiore eccessivo (`14px 0 2px`);
- Diagnostica: `Dettagli tecnici` centrato verticalmente con `11px 16px`, bordo/raggio coerenti;
- Diagnostica: il feedback vuoto non riserva più 18px sotto i pulsanti;
- Diagnostica: larghezza del testo privacy allineata a Courses (`max-width: 760px`), così il wrapping e l'altezza della card restano coerenti;
- pulsanti diagnostica resi deterministici a 39px;
- Builder, drag & drop, database e logica applicativa invariati.

SHA-256 pacchetto: `$SHA256`
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
    entry = ("\t<changelog>\n"
             "\t\t<element>pkg_decaroforms</element>\n"
             "\t\t<type>package</type>\n"
             f"\t\t<version>{version}</version>\n"
             "\t\t<note>Informazioni: allineate Integrazioni e Diagnostica allo standard Courses 1.0.44. Rimossi gli spazi vuoti residui, centrato Dettagli tecnici, feedback vuoto senza altezza riservata e wrapping privacy coerente. Builder, database e logica invariati.</note>\n"
             "\t</changelog>\n")
    s = s.replace('<changelogs>\n', '<changelogs>\n' + entry, 1)
    p.write_text(s, encoding='utf-8')
PY

# Final package guards.
unzip -t "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" >/dev/null
unzip -l "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | grep -q "com_decaroforms_${NEW_VERSION}.zip"
unzip -l "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | grep -q "plg_system_decaroforms_${NEW_VERSION}.zip"
unzip -l "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | grep -q "plg_editors-xtd_decaroforms_${NEW_VERSION}.zip"
python3 - "$ROOT/updates/pkg_decaroforms.xml" "$ROOT/updates/changelog.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
for path in sys.argv[1:]: ET.parse(path)
PY

echo "Built Forms $NEW_VERSION"
echo "SHA256: $SHA256"
