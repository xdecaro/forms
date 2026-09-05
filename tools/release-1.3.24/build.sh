#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.23/pkg_decaroforms_1.3.23.zip"
OUTDIR="$ROOT/releases/1.3.24"
OUT="$OUTDIR/pkg_decaroforms_1.3.24.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component" "$TMP/system" "$TMP/editor" "$OUTDIR"

unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.23.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.23.zip" -d "$TMP/system"

python3 "$ROOT/tools/release-1.3.24/patch.py" "$TMP/component" "$TMP/system"
python3 "$ROOT/tools/release-1.3.24/editor_plugin.py" "$TMP/component" "$TMP/outer" "$TMP/editor"

# Refresh creation date/version everywhere relevant.
python3 - "$TMP/component" "$TMP/system" <<'PY'
from pathlib import Path
import sys
for root in map(Path,sys.argv[1:]):
    for p in root.rglob('*'):
        if p.is_file() and p.suffix.lower() in {'.php','.xml','.ini','.txt','.md','.js','.css'}:
            try:s=p.read_text(encoding='utf-8')
            except UnicodeDecodeError:continue
            s=s.replace('1.3.23','1.3.24').replace('<creationDate>2026-09-04</creationDate>','<creationDate>2026-09-05</creationDate>')
            p.write_text(s,encoding='utf-8')
PY

rm -f "$TMP/outer/com_decaroforms_1.3.23.zip" "$TMP/outer/plg_system_decaroforms_1.3.23.zip"
(
  cd "$TMP/component"
  zip -qr "$TMP/outer/com_decaroforms_1.3.24.zip" .
)
(
  cd "$TMP/system"
  zip -qr "$TMP/outer/plg_system_decaroforms_1.3.24.zip" .
)
(
  cd "$TMP/editor"
  zip -qr "$TMP/outer/plg_editors-xtd_decaroforms_1.3.24.zip" .
)
(
  cd "$TMP/outer"
  zip -qr "$OUT" .
)

SHA="$(sha256sum "$OUT" | awk '{print $1}')"

# Validate PHP and XML before publishing feed metadata.
php -l "$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php" >/dev/null
php -l "$TMP/component/administrator/components/com_decaroforms/tmpl/forms/modal.php" >/dev/null
php -l "$TMP/component/administrator/components/com_decaroforms/src/Controller/BuilderController.php" >/dev/null
php -l "$TMP/component/script.php" >/dev/null
php -l "$TMP/editor/services/provider.php" >/dev/null
php -l "$TMP/editor/src/Extension/Forms.php" >/dev/null
python3 - "$TMP/outer/pkg_decaroforms.xml" "$TMP/component/com_decaroforms.xml" "$TMP/system/decaroforms.xml" "$TMP/editor/decaroforms.xml" <<'PY'
import sys,xml.etree.ElementTree as ET
for f in sys.argv[1:]:ET.parse(f)
PY

grep -q 'group="editors-xtd"' "$TMP/outer/pkg_decaroforms.xml"
grep -q 'fields_count' "$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
grep -q 'fields_saved' "$TMP/component/administrator/components/com_decaroforms/src/Controller/BuilderController.php"
grep -q 'layout=modal' "$TMP/editor/src/Extension/Forms.php"
if grep -Eq '💾|🗑|🔒|✏️' "$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"; then
  echo 'Legacy emoji UI icons remain in builder' >&2
  exit 1
fi

# Update Joomla update feed.
cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.3.24</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.3.24/pkg_decaroforms_1.3.24.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>${SHA}</sha256>
</update></updates>
EOF

cat > "$ROOT/updates/changelog.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>1.3.24</version>
<addition>Aggiunto nel pacchetto il plugin Editor Button di Joomla: il pulsante Forms apre una finestra con ricerca ed elenco moduli e inserisce automaticamente lo shortcode nel punto del cursore.</addition>
<fix>Il Builder sincronizza e verifica il numero dei campi prima del salvataggio e blocca richieste incoerenti per evitare la perdita dei campi del modulo.</fix>
<fix>Il server rifiuta payload campi non validi invece di interpretarli come elenco vuoto.</fix>
<change>Sostituite le emoji di salvataggio, modifica, duplica ed eliminazione con icone UI SVG coerenti.</change>
<change>Il messaggio di salvataggio riuscito viene mostrato tramite il sistema messaggi nativo di Joomla dopo il redirect.</change>
<language>it-IT</language>
</changelog></changelogs>
EOF

python3 - "$ROOT/README.md" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8')
s=s.replace('**1.3.23**','**1.3.24**',1)
section='''\n## Joomla editor button\n\nThe Forms package includes an **Editors-XTD** plugin for Joomla. In article and other supported editor screens, the **Forms** button opens a searchable form picker and inserts the selected shortcode (for example `{form id="1"}`) at the current cursor position.\n\nThe editor button is installed with the package and is enabled automatically during the Forms component update.\n'''
if '## Joomla editor button' not in s:
    marker='\n## Submissions manager\n'
    if marker in s:s=s.replace(marker,section+marker,1)
    else:s+=section
p.write_text(s,encoding='utf-8')
PY

python3 - "$ROOT/updates/pkg_decaroforms.xml" "$ROOT/updates/changelog.xml" <<'PY'
import sys,xml.etree.ElementTree as ET
for f in sys.argv[1:]:ET.parse(f)
PY

# Final package sanity checks.
unzip -l "$OUT" | grep -q 'plg_editors-xtd_decaroforms_1.3.24.zip'
unzip -l "$OUT" | grep -q 'com_decaroforms_1.3.24.zip'
unzip -l "$OUT" | grep -q 'plg_system_decaroforms_1.3.24.zip'

echo "FORMS_RELEASE_VERSION=1.3.24"
echo "FORMS_RELEASE_SHA256=$SHA"
echo "FORMS_RELEASE_PATH=releases/1.3.24/pkg_decaroforms_1.3.24.zip"
