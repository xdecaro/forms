#!/usr/bin/env bash
set -euo pipefail

BASE_VERSION="1.3.70"
NEW_VERSION="1.3.71"
RELEASE_DATE="2026-09-07"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_ZIP="$ROOT/releases/$BASE_VERSION/pkg_decaroforms_$BASE_VERSION.zip"
SRC="$ROOT/tools/release-$NEW_VERSION"
OUT="$ROOT/releases/$NEW_VERSION"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

[[ -f "$BASE_ZIP" ]] || { echo "Base package not found: $BASE_ZIP" >&2; exit 1; }
[[ -f "$SRC/InformationHtmlView.php" ]] || { echo "Missing source: $SRC/InformationHtmlView.php" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT" "$WORK/outer" "$WORK/component-old" "$WORK/component" "$WORK/system-old" "$WORK/system" "$WORK/editor-old" "$WORK/editor"
unzip -q "$BASE_ZIP" -d "$WORK/outer"
unzip -q "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" -d "$WORK/component-old"
unzip -q "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" -d "$WORK/component"
unzip -q "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" -d "$WORK/system-old"
unzip -q "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" -d "$WORK/system"
unzip -q "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip" -d "$WORK/editor-old"
unzip -q "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip" -d "$WORK/editor"

# Fix the WebAssetManager URI: Joomla adds /css and /js automatically.
cp "$SRC/InformationHtmlView.php" "$WORK/component/administrator/components/com_decaroforms/src/View/Information/HtmlView.php"

# Keep the internal version marker coherent with the release.
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

# Version manifests without changing install structure or existing functionality.
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

# Regression guard: only the intended component files and version manifests may change.
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
    'administrator/components/com_decaroforms/src/Helper/FormHelper.php',
    'administrator/components/com_decaroforms/src/View/Information/HtmlView.php',
}
unexpected = [p for p, h in old.items() if new.get(p) != h and p not in allowed]
if unexpected:
    raise SystemExit('Unexpected component regressions: ' + ', '.join(unexpected))

for old_root, new_root in [(sys.argv[3], sys.argv[4]), (sys.argv[5], sys.argv[6])]:
    old_h, new_h = hashes(old_root), hashes(new_root)
    unexpected = [p for p, h in old_h.items() if new_h.get(p) != h and p != 'decaroforms.xml']
    if unexpected:
        raise SystemExit('Unexpected plugin regressions: ' + ', '.join(unexpected))
PY

# Verify that the media assets are present exactly where the manifest installs them.
[[ -f "$WORK/component/media/css/information.css" ]] || { echo "Missing information.css" >&2; exit 1; }
[[ -f "$WORK/component/media/js/information.js" ]] || { echo "Missing information.js" >&2; exit 1; }
grep -q "com_decaroforms/information.css" "$WORK/component/administrator/components/com_decaroforms/src/View/Information/HtmlView.php"
grep -q "com_decaroforms/information.js" "$WORK/component/administrator/components/com_decaroforms/src/View/Information/HtmlView.php"
if grep -q "com_decaroforms/css/information.css\|com_decaroforms/js/information.js" "$WORK/component/administrator/components/com_decaroforms/src/View/Information/HtmlView.php"; then
    echo "Invalid WebAssetManager URI still present" >&2
    exit 1
fi

php -l "$WORK/component/administrator/components/com_decaroforms/src/View/Information/HtmlView.php" >/dev/null
php -l "$WORK/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php" >/dev/null
python3 - "$WORK/component/com_decaroforms.xml" "$WORK/system/decaroforms.xml" "$WORK/editor/decaroforms.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
for path in sys.argv[1:]: ET.parse(path)
PY

# Rebuild nested packages.
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

# Package manifest references the new nested versions.
python3 - "$WORK/outer/pkg_decaroforms.xml" "$BASE_VERSION" "$NEW_VERSION" "$RELEASE_DATE" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1]); base, new, release_date = sys.argv[2:5]
s = p.read_text(encoding='utf-8')
s = s.replace(base, new)
s = re.sub(r'<creationDate>[^<]+</creationDate>', f'<creationDate>{release_date}</creationDate>', s, count=1)
p.write_text(s, encoding='utf-8')
PY
python3 - "$WORK/outer/pkg_decaroforms.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
ET.parse(sys.argv[1])
PY

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

Hotfix della pagina **Informazioni**.

- corretto il percorso WebAssetManager di CSS e JavaScript;
- `information.css` continua a essere installato in `/media/com_decaroforms/css/` e `information.js` in `/media/com_decaroforms/js/`;
- Guida e Informazioni restano due viste separate e non entrano in conflitto;
- Builder, drag & drop, database, moduli, invii e integrazioni invariati.
EOF

# Update server.
cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update><name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description><element>pkg_decaroforms</element><type>package</type><client>site</client><version>$NEW_VERSION</version><downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/$NEW_VERSION/pkg_decaroforms_$NEW_VERSION.zip</downloadurl></downloads><changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags><maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl><targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA256</sha256></update></updates>
EOF

# Prepend changelog entry, preserving all history.
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
             "\t\t<note>Hotfix Informazioni: corretto il percorso WebAssetManager di information.css e information.js. Joomla aggiunge automaticamente le directory css/js agli URI degli asset dell'estensione; la 1.3.70 richiedeva quindi un percorso duplicato e la pagina risultava senza stile. Guida e Informazioni restano separate; Builder, drag, database e logica applicativa invariati.</note>\n"
             "\t</changelog>\n")
    s = s.replace('<changelogs>\n', '<changelogs>\n' + entry, 1)
    p.write_text(s, encoding='utf-8')
PY

# Final package sanity checks.
unzip -l "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | grep -q "com_decaroforms_${NEW_VERSION}.zip"
unzip -l "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | grep -q "plg_system_decaroforms_${NEW_VERSION}.zip"
unzip -l "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | grep -q "plg_editors-xtd_decaroforms_${NEW_VERSION}.zip"
python3 - "$ROOT/updates/pkg_decaroforms.xml" "$ROOT/updates/changelog.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
for path in sys.argv[1:]: ET.parse(path)
PY

echo "Built Forms $NEW_VERSION"
echo "SHA256: $SHA256"
