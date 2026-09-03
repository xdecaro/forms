#!/usr/bin/env bash
set -euo pipefail

ROOT=/tmp/forms126
rm -rf "$ROOT"
mkdir -p "$ROOT/outer" "$ROOT/component" "$ROOT/plugin"

unzip -q releases/1.2.5/pkg_decaroforms_1.2.5.zip -d "$ROOT/outer"
unzip -q "$ROOT/outer/com_decaroforms_1.2.5.zip" -d "$ROOT/component"
unzip -q "$ROOT/outer/plg_system_decaroforms_1.2.5.zip" -d "$ROOT/plugin"

python3 tools/release-1.2.6/apply_patch.py "$ROOT/component" "$ROOT/plugin" "$ROOT/outer"

echo '=== PHP syntax check ==='
while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$ROOT/component" "$ROOT/plugin" -type f -name '*.php' -print0)

echo '=== XML syntax check ==='
python3 - <<'PY'
import xml.etree.ElementTree as ET
from pathlib import Path
for f in [
    Path('/tmp/forms126/component/com_decaroforms.xml'),
    Path('/tmp/forms126/plugin/decaroforms.xml'),
    Path('/tmp/forms126/outer/pkg_decaroforms.xml'),
]:
    ET.parse(f)
    print('OK', f)
PY

echo '=== Live-filter feature checks ==='
RECENT="$ROOT/component/administrator/components/com_decaroforms/tmpl/recent/default.php"
SUBS="$ROOT/component/administrator/components/com_decaroforms/tmpl/submissions/default.php"
FORMS="$ROOT/component/administrator/components/com_decaroforms/tmpl/forms/default.php"
grep -q "search.addEventListener('input',scheduleApply)" "$RECENT"
grep -q "form.addEventListener('change',apply)" "$RECENT"
grep -q "status.addEventListener('change',apply)" "$RECENT"
grep -q "search.addEventListener('input',scheduleApply)" "$SUBS"
grep -q "filter.addEventListener('change',apply)" "$SUBS"
grep -q "q?.addEventListener('input',scheduleApply)" "$FORMS"
grep -q "setTimeout(apply,180)" "$RECENT"
grep -q "setTimeout(apply,180)" "$SUBS"
grep -q "setTimeout(apply,180)" "$FORMS"
grep -q "VERSION = '1.2.6'" "$ROOT/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"

rm -f "$ROOT/outer/com_decaroforms_1.2.5.zip" "$ROOT/outer/plg_system_decaroforms_1.2.5.zip"
(cd "$ROOT/component" && zip -qr "$ROOT/outer/com_decaroforms_1.2.6.zip" .)
(cd "$ROOT/plugin" && zip -qr "$ROOT/outer/plg_system_decaroforms_1.2.6.zip" .)

grep -q 'com_decaroforms_1.2.6.zip' "$ROOT/outer/pkg_decaroforms.xml"
grep -q 'plg_system_decaroforms_1.2.6.zip' "$ROOT/outer/pkg_decaroforms.xml"
grep -q '<version>1.2.6</version>' "$ROOT/component/com_decaroforms.xml"
grep -q '<version>1.2.6</version>' "$ROOT/plugin/decaroforms.xml"
grep -q '<version>1.2.6</version>' "$ROOT/outer/pkg_decaroforms.xml"

mkdir -p releases/1.2.6
rm -f releases/1.2.6/pkg_decaroforms_1.2.6.zip
(cd "$ROOT/outer" && zip -qr "$GITHUB_WORKSPACE/releases/1.2.6/pkg_decaroforms_1.2.6.zip" .)
unzip -t releases/1.2.6/pkg_decaroforms_1.2.6.zip >/dev/null
unzip -t "$ROOT/outer/com_decaroforms_1.2.6.zip" >/dev/null
unzip -t "$ROOT/outer/plg_system_decaroforms_1.2.6.zip" >/dev/null

SHA=$(sha256sum releases/1.2.6/pkg_decaroforms_1.2.6.zip | awk '{print $1}')

cat > releases/1.2.6/README.md <<EOF
# Forms 1.2.6

Live filtering usability release.

## Changed

- **Invii recenti** now filters automatically while typing, without pressing Filtra;
- the **Modulo**, **Stato** and **Mostra** selectors update the list immediately;
- **Invii del modulo** now has the same live search and immediate status/rows filtering;
- **Elenco moduli**, which was already live, now uses the same lightweight 180 ms debounce behaviour;
- the native clear **X** in search fields restores results automatically;
- the existing **Filtra** and **Pulisci** buttons remain available as explicit controls.

## Compatibility

- includes all fixes and UI changes from 1.2.5;
- Joomla 6.0+;
- PHP 8.3+;
- no database schema changes;
- existing forms and submissions are preserved.

Official package SHA-256:

\`${SHA}\`
EOF

python3 - "$SHA" <<'PY'
from pathlib import Path
import sys
import xml.etree.ElementTree as ET
sha = sys.argv[1]
Path('updates/pkg_decaroforms.xml').write_text(f'''<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.2.6</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.2.6/pkg_decaroforms_1.2.6.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>{sha}</sha256>
</update></updates>
''', encoding='utf-8')

path = Path('updates/changelog.xml')
text = path.read_text(encoding='utf-8')
if '<version>1.2.6</version>' not in text:
    entry = '''  <changelog>
    <element>pkg_decaroforms</element>
    <type>package</type>
    <version>1.2.6</version>
    <addition>
      <item>Live search while typing in Recent submissions and form submissions.</item>
      <item>Immediate filtering when form, status or row-limit selectors change.</item>
    </addition>
    <change>
      <item>Standardised list filtering with a lightweight 180 ms debounce across administrator list views.</item>
    </change>
  </changelog>
'''
    text = text.replace('<changelogs>\n', '<changelogs>\n' + entry, 1)
    path.write_text(text, encoding='utf-8')

ET.parse('updates/pkg_decaroforms.xml')
ET.parse('updates/changelog.xml')
print('Update XML valid')
PY

# Restore the normal release workflow after this one-time operation.
cat > .github/workflows/rebuild-release.yml <<'YAML'
name: Rebuild release package

on:
  push:
    paths:
      - 'releases/_upload/READY'

permissions:
  contents: write

jobs:
  rebuild:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Rebuild ZIP from compressed Base64 chunks
        shell: bash
        run: |
          set -euo pipefail
          VERSION="$(cat releases/_upload/VERSION.txt)"
          EXPECTED="$(cat releases/_upload/SHA256.txt)"
          TARGET="releases/${VERSION}/pkg_decaroforms_${VERSION}.zip"
          mkdir -p "releases/${VERSION}"
          cat releases/_upload/part-000.b64 releases/_upload/part-001.b64 releases/_upload/part-002.b64 releases/_upload/part-003.b64 releases/_upload/part-004.b64 releases/_upload/part-005.b64 releases/_upload/part-006.b64 releases/_upload/part-007.b64 releases/_upload/part-008.b64 | base64 -d | xz -d > "$TARGET"
          ACTUAL="$(sha256sum "$TARGET" | awk '{print $1}')"
          test "$ACTUAL" = "$EXPECTED"
          rm -rf releases/_upload
      - name: Commit rebuilt package
        shell: bash
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git add releases
          git commit -m "Publish Forms release package" || exit 0
          git push
YAML

rm -rf releases/_upload tools/release-1.2.6 tools/inspect-1.2.5-live
rm -f .github/workflows/inspect-1.2.5-live.yml

echo "Forms 1.2.6 built successfully: $SHA"
