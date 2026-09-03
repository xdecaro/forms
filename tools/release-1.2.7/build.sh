#!/usr/bin/env bash
set -euo pipefail

ROOT=/tmp/forms127
rm -rf "$ROOT"
mkdir -p "$ROOT/outer" "$ROOT/component" "$ROOT/plugin"

unzip -q releases/1.2.6/pkg_decaroforms_1.2.6.zip -d "$ROOT/outer"
unzip -q "$ROOT/outer/com_decaroforms_1.2.6.zip" -d "$ROOT/component"
unzip -q "$ROOT/outer/plg_system_decaroforms_1.2.6.zip" -d "$ROOT/plugin"

python3 tools/release-1.2.7/apply_patch.py "$ROOT/component" "$ROOT/plugin" "$ROOT/outer"

echo '=== PHP syntax check ==='
while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$ROOT/component" "$ROOT/plugin" -type f -name '*.php' -print0)

echo '=== XML syntax check ==='
python3 - <<'PY'
import xml.etree.ElementTree as ET
from pathlib import Path
for f in [Path('/tmp/forms127/component/com_decaroforms.xml'),Path('/tmp/forms127/plugin/decaroforms.xml'),Path('/tmp/forms127/outer/pkg_decaroforms.xml')]:
    ET.parse(f)
    print('OK', f)
PY

echo '=== Copy-paste feature checks ==='
CTRL="$ROOT/component/administrator/components/com_decaroforms/src/Controller/BuilderController.php"
FORMS="$ROOT/component/administrator/components/com_decaroforms/tmpl/forms/default.php"
SUBS="$ROOT/component/administrator/components/com_decaroforms/tmpl/submissions/default.php"
grep -q 'public function copy(): void' "$CTRL"
grep -q 'public function paste(): void' "$CTRL"
grep -q 'com_decaroforms.copied_form_id' "$CTRL"
grep -q '#__decaroforms_fields' "$CTRL"
grep -q 'builder.paste' "$FORMS"
grep -q 'builder.copy' "$FORMS"
grep -q 'builder.copy' "$SUBS"
grep -q "VERSION = '1.2.7'" "$ROOT/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"

rm -f "$ROOT/outer/com_decaroforms_1.2.6.zip" "$ROOT/outer/plg_system_decaroforms_1.2.6.zip"
(cd "$ROOT/component" && zip -qr "$ROOT/outer/com_decaroforms_1.2.7.zip" .)
(cd "$ROOT/plugin" && zip -qr "$ROOT/outer/plg_system_decaroforms_1.2.7.zip" .)

grep -q 'com_decaroforms_1.2.7.zip' "$ROOT/outer/pkg_decaroforms.xml"
grep -q 'plg_system_decaroforms_1.2.7.zip' "$ROOT/outer/pkg_decaroforms.xml"
grep -q '<version>1.2.7</version>' "$ROOT/component/com_decaroforms.xml"
grep -q '<version>1.2.7</version>' "$ROOT/plugin/decaroforms.xml"
grep -q '<version>1.2.7</version>' "$ROOT/outer/pkg_decaroforms.xml"

mkdir -p releases/1.2.7
rm -f releases/1.2.7/pkg_decaroforms_1.2.7.zip
(cd "$ROOT/outer" && zip -qr "$GITHUB_WORKSPACE/releases/1.2.7/pkg_decaroforms_1.2.7.zip" .)
unzip -t releases/1.2.7/pkg_decaroforms_1.2.7.zip >/dev/null
unzip -t "$ROOT/outer/com_decaroforms_1.2.7.zip" >/dev/null
unzip -t "$ROOT/outer/plg_system_decaroforms_1.2.7.zip" >/dev/null

SHA=$(sha256sum releases/1.2.7/pkg_decaroforms_1.2.7.zip | awk '{print $1}')

cat > releases/1.2.7/README.md <<EOF
# Forms 1.2.7

Copy and paste form release.

## Added

- **Copia modulo** in every form card in Elenco moduli;
- **Incolla modulo** next to + Nuovo modulo;
- **Copia modulo** also in the submissions page header;
- pasted forms receive a new ID, slug and shortcode;
- all form settings and all form fields are copied;
- submissions and uploaded files are never copied;
- the pasted form opens directly in Modifica modulo;
- repeated paste creates further independent copies.

## Compatibility

- includes all changes from 1.2.6;
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
sha=sys.argv[1]
Path('updates/pkg_decaroforms.xml').write_text(f'''<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.2.7</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.2.7/pkg_decaroforms_1.2.7.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>{sha}</sha256>
</update></updates>
''',encoding='utf-8')
path=Path('updates/changelog.xml')
text=path.read_text(encoding='utf-8')
if '<version>1.2.7</version>' not in text:
    entry='''  <changelog>
    <element>pkg_decaroforms</element>
    <type>package</type>
    <version>1.2.7</version>
    <addition>
      <item>Copy form and paste form workflow in administrator.</item>
      <item>Copy form action is also available from the form submissions page.</item>
    </addition>
    <change>
      <item>Pasted forms receive a new ID, slug and shortcode while preserving configuration and fields.</item>
      <item>Submissions and uploaded files are deliberately excluded from copies.</item>
    </change>
  </changelog>
'''
    text=text.replace('<changelogs>\n','<changelogs>\n'+entry,1)
    path.write_text(text,encoding='utf-8')
ET.parse('updates/pkg_decaroforms.xml'); ET.parse('updates/changelog.xml')
print('Update XML valid')
PY

rm -rf releases/_upload tools/release-1.2.7

echo "Forms 1.2.7 built successfully: $SHA"
