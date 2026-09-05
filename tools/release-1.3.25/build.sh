#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.24/pkg_decaroforms_1.3.24.zip"
OUTDIR="$ROOT/releases/1.3.25"
OUT="$OUTDIR/pkg_decaroforms_1.3.25.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component" "$TMP/system" "$TMP/editor" "$OUTDIR"

unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.24.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.24.zip" -d "$TMP/system"
unzip -q "$TMP/outer/plg_editors-xtd_decaroforms_1.3.24.zip" -d "$TMP/editor"

python3 "$ROOT/tools/release-1.3.25/patch.py" "$TMP/component" "$TMP/system" "$TMP/editor"

# Upgrade outer package manifest and bundled filenames.
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8')
s=s.replace('<version>1.3.24</version>','<version>1.3.25</version>')
s=s.replace('com_decaroforms_1.3.24.zip','com_decaroforms_1.3.25.zip')
s=s.replace('plg_system_decaroforms_1.3.24.zip','plg_system_decaroforms_1.3.25.zip')
s=s.replace('plg_editors-xtd_decaroforms_1.3.24.zip','plg_editors-xtd_decaroforms_1.3.25.zip')
s=s.replace('<creationDate>2026-09-04</creationDate>','<creationDate>2026-09-05</creationDate>')
p.write_text(s,encoding='utf-8')
PY

# Refresh creation dates where present.
python3 - "$TMP/component" "$TMP/system" "$TMP/editor" <<'PY'
from pathlib import Path
import sys
for root in map(Path,sys.argv[1:]):
    for p in root.rglob('*'):
        if p.is_file() and p.suffix.lower() in {'.php','.xml','.ini','.txt','.md','.js','.css'}:
            try:s=p.read_text(encoding='utf-8')
            except UnicodeDecodeError:continue
            s=s.replace('<creationDate>2026-09-04</creationDate>','<creationDate>2026-09-05</creationDate>')
            p.write_text(s,encoding='utf-8')
PY

rm -f "$TMP/outer/com_decaroforms_1.3.24.zip" "$TMP/outer/plg_system_decaroforms_1.3.24.zip" "$TMP/outer/plg_editors-xtd_decaroforms_1.3.24.zip"
(
  cd "$TMP/component"
  zip -qr "$TMP/outer/com_decaroforms_1.3.25.zip" .
)
(
  cd "$TMP/system"
  zip -qr "$TMP/outer/plg_system_decaroforms_1.3.25.zip" .
)
(
  cd "$TMP/editor"
  zip -qr "$TMP/outer/plg_editors-xtd_decaroforms_1.3.25.zip" .
)
(
  cd "$TMP/outer"
  zip -qr "$OUT" .
)

# Syntax / structural validation before feed publication.
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
C="$TMP/component/administrator/components/com_decaroforms/src/Controller/BuilderController.php"
php -l "$B" >/dev/null
php -l "$C" >/dev/null
php -l "$TMP/component/script.php" >/dev/null
php -l "$TMP/editor/services/provider.php" >/dev/null
php -l "$TMP/editor/src/Extension/Forms.php" >/dev/null
python3 - "$TMP/outer/pkg_decaroforms.xml" "$TMP/component/com_decaroforms.xml" "$TMP/system/decaroforms.xml" "$TMP/editor/decaroforms.xml" <<'PY'
import sys,xml.etree.ElementTree as ET
for f in sys.argv[1:]:ET.parse(f)
PY

grep -q "window.dfBuilderRuntime={version:'1.3.25'" "$B"
grep -q 'ensureInitialFieldWorkspace' "$B"
grep -q 'df-custom-js' "$B"
grep -q 'name="custom_js"' "$B"
grep -q 'if(sheetsEnabled&&sheetsWebhook&&sheetsSecret&&sheetsFiles)' "$B"
grep -q "window.dfBuilderSaveDraft=saveDraftNow" "$B"
grep -q "window.dfBuilderClearDraft=clearDraft" "$B"
grep -q "HTMLHelper::_('form.token')" "$B"
grep -q 'opcache_invalidate' "$TMP/component/script.php"
unzip -l "$OUT" | grep -q 'plg_editors-xtd_decaroforms_1.3.25.zip'

SHA="$(sha256sum "$OUT" | awk '{print $1}')"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.3.25</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.3.25/pkg_decaroforms_1.3.25.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>${SHA}</sha256>
</update></updates>
EOF

cat > "$ROOT/updates/changelog.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>1.3.25</version>
<fix>Corretto il render iniziale di Campi del modulo: i campi già salvati vengono disegnati immediatamente nel canvas e nell’ispettore senza dover premere Aggiungi campo.</fix>
<fix>Aggiunto un secondo controllo automatico del canvas che forza il render se esistono campi caricati ma nessuna card è presente nel DOM.</fix>
<fix>Resa tollerante l’inizializzazione delle integrazioni opzionali, evitando che elementi mancanti interrompano tutto il JavaScript del Builder.</fix>
<fix>Le API di bozza automatica restano disponibili al gestore di salvataggio robusto.</fix>
<fix>Ripristinati ed esplicitati CSS personalizzato e JavaScript personalizzato a larghezza 100%.</fix>
<fix>Invalidata la cache opcode PHP dei file principali del Builder dopo l’aggiornamento per evitare combinazioni di file vecchi e nuovi.</fix>
<language>it-IT</language>
</changelog></changelogs>
EOF

python3 - "$ROOT/README.md" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8')
s=s.replace('**1.3.24**','**1.3.25**',1)
p.write_text(s,encoding='utf-8')
PY
python3 - "$ROOT/updates/pkg_decaroforms.xml" "$ROOT/updates/changelog.xml" <<'PY'
import sys,xml.etree.ElementTree as ET
for f in sys.argv[1:]:ET.parse(f)
PY

echo "FORMS_RELEASE_VERSION=1.3.25"
echo "FORMS_RELEASE_SHA256=$SHA"
echo "FORMS_RELEASE_PATH=releases/1.3.25/pkg_decaroforms_1.3.25.zip"
