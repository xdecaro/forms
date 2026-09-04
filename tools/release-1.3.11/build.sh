#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TOOL="$ROOT/tools/release-1.3.11"
BASE="$ROOT/releases/1.3.10/pkg_decaroforms_1.3.10.zip"
OUTDIR="$ROOT/releases/1.3.11"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -f "$BASE" ] || { echo "Missing base package: $BASE" >&2; exit 1; }
mkdir -p "$TMP/outer" "$TMP/component" "$TMP/plugin" "$OUTDIR"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.10.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.10.zip" -d "$TMP/plugin"
python3 "$TOOL/patch.py" "$TMP/component" "$TMP/plugin"

while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.php' -print0)
while IFS= read -r -d '' f; do php -r '$x=parse_ini_file($argv[1],false,INI_SCANNER_RAW); if($x===false){fwrite(STDERR,"Invalid INI: {$argv[1]}\n"); exit(1);}' "$f"; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.ini' -print0)
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/component/com_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/plugin/decaroforms.xml"

BUILDER="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
HELPER="$TMP/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
grep -q "public const VERSION = '1.3.11'" "$HELPER"
grep -q '<version>1.3.11</version>' "$TMP/component/com_decaroforms.xml"
grep -q '<version>1.3.11</version>' "$TMP/plugin/decaroforms.xml"
grep -q 'data-email-preview-action' "$BUILDER"
grep -q 'df-email-preview-btn' "$BUILDER"
grep -q 'document.body.appendChild(previewModal)' "$BUILDER"
grep -q "previewModal.style.setProperty('display','grid','important')" "$BUILDER"
grep -q "const trigger=e.target.closest('\[data-email-preview-action\]')" "$BUILDER"

COMPZIP="$TMP/com_decaroforms_1.3.11.zip"
PLUGZIP="$TMP/plg_system_decaroforms_1.3.11.zip"
(cd "$TMP/component" && zip -qr "$COMPZIP" .)
(cd "$TMP/plugin" && zip -qr "$PLUGZIP" .)
rm -f "$TMP/outer/com_decaroforms_1.3.10.zip" "$TMP/outer/plg_system_decaroforms_1.3.10.zip"
cp "$COMPZIP" "$TMP/outer/com_decaroforms_1.3.11.zip"
cp "$PLUGZIP" "$TMP/outer/plg_system_decaroforms_1.3.11.zip"
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); t=p.read_text()
t=t.replace('<version>1.3.10</version>','<version>1.3.11</version>')
t=t.replace('plg_system_decaroforms_1.3.10.zip','plg_system_decaroforms_1.3.11.zip')
t=t.replace('com_decaroforms_1.3.10.zip','com_decaroforms_1.3.11.zip')
p.write_text(t)
PY
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/outer/pkg_decaroforms.xml"

TARGET="$OUTDIR/pkg_decaroforms_1.3.11.zip"
rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
SIZE="$(stat -c%s "$TARGET")"

cat > "$OUTDIR/README.md" <<EOF
# Forms 1.3.11

Correzione definitiva dell'apertura facsimile dei template email.

- Nuovo pulsante Anteprima sempre visibile su ogni template email.
- Apertura gestita con event delegation, quindi funziona anche dopo i re-render dinamici del Builder.
- La modal viene spostata direttamente sotto body per evitare problemi di stacking/overflow dell'amministrazione Joomla.
- Z-index e display vengono forzati in apertura per evitare che la modal resti nascosta dietro il Builder.
- Se la generazione dei dati di esempio fallisce, la modal si apre comunque con un contenuto di fallback.
- Il radio resta separato e serve solo a selezionare il template.

SHA-256: $SHA
Dimensione: $SIZE byte
EOF
printf '%s  %s\n' "$SHA" "releases/1.3.11/pkg_decaroforms_1.3.11.zip" > "$OUTDIR/SHA256SUMS.txt"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.3.11</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.3.11/pkg_decaroforms_1.3.11.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF
cat > "$ROOT/updates/changelog.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>1.3.11</version>
<fix>Correzione robusta dell'apertura modal facsimile per i template email.</fix>
<change>Aggiunto pulsante Anteprima sempre visibile e gestione eventi delegata.</change>
<language>it-IT</language>
</changelog></changelogs>
EOF
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/pkg_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/changelog.xml"
python3 - "$ROOT/README.md" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); t=p.read_text()
t=re.sub(r'(## Current development version\n\n)\*\*[^*]+\*\*',r'\1**1.3.11**',t,1)
p.write_text(t)
PY

echo "Built Forms 1.3.11: $SHA ($SIZE bytes)"
