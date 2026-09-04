#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TOOL="$ROOT/tools/release-1.3.13"
BASE="$ROOT/releases/1.3.12/pkg_decaroforms_1.3.12.zip"
OUTDIR="$ROOT/releases/1.3.13"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -f "$BASE" ] || { echo "Missing base package: $BASE" >&2; exit 1; }
mkdir -p "$TMP/outer" "$TMP/component" "$TMP/plugin" "$OUTDIR"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.12.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.12.zip" -d "$TMP/plugin"
python3 "$TOOL/patch.py" "$TMP/component" "$TMP/plugin"

if command -v php >/dev/null 2>&1; then
  while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.php' -print0)
  while IFS= read -r -d '' f; do php -r '$x=parse_ini_file($argv[1],false,INI_SCANNER_RAW); if($x===false){fwrite(STDERR,"Invalid INI: {$argv[1]}\n"); exit(1);}' "$f"; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.ini' -print0)
  php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/component/com_decaroforms.xml"
  php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/plugin/decaroforms.xml"
else
  python3 - "$TMP/component/com_decaroforms.xml" "$TMP/plugin/decaroforms.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET
for name in sys.argv[1:]:
    ET.parse(name)
PY
fi

BUILDER="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
HELPER="$TMP/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
grep -q "public const VERSION = '1.3.13'" "$HELPER"
grep -q '<version>1.3.13</version>' "$TMP/component/com_decaroforms.xml"
grep -q '<version>1.3.13</version>' "$TMP/plugin/decaroforms.xml"
grep -q 'df-builder-workspace' "$BUILDER"
grep -q 'Campi del modulo' "$BUILDER"
grep -q 'duplicateField(index)' "$BUILDER"
grep -q 'df-field-width-pills' "$BUILDER"

COMPZIP="$TMP/com_decaroforms_1.3.13.zip"
PLUGZIP="$TMP/plg_system_decaroforms_1.3.13.zip"
(cd "$TMP/component" && zip -qr "$COMPZIP" .)
(cd "$TMP/plugin" && zip -qr "$PLUGZIP" .)
rm -f "$TMP/outer/com_decaroforms_1.3.12.zip" "$TMP/outer/plg_system_decaroforms_1.3.12.zip"
cp "$COMPZIP" "$TMP/outer/com_decaroforms_1.3.13.zip"
cp "$PLUGZIP" "$TMP/outer/plg_system_decaroforms_1.3.13.zip"
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); t=p.read_text()
t=t.replace('<version>1.3.12</version>','<version>1.3.13</version>')
t=t.replace('plg_system_decaroforms_1.3.12.zip','plg_system_decaroforms_1.3.13.zip')
t=t.replace('com_decaroforms_1.3.12.zip','com_decaroforms_1.3.13.zip')
p.write_text(t)
PY
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET
ET.parse(sys.argv[1])
PY

TARGET="$OUTDIR/pkg_decaroforms_1.3.13.zip"
rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
SIZE="$(stat -c%s "$TARGET")"

cat > "$OUTDIR/README.md" <<EOF
# Forms 1.3.13

Form Builder visuale più semplice e compatto.

- Unificate le sezioni Campi selezionati e Layout campi.
- Campi compatti con trascinamento, tipo, larghezza e azioni rapide.
- Pannello laterale per modificare soltanto il campo selezionato.
- Larghezze rapide 100%, 75%, 66%, 50%, 33% e 25%.
- Aggiunta duplicazione del campo e zona nuova riga visibile solo durante il trascinamento.
- Layout responsive per desktop, tablet e smartphone.

SHA-256: $SHA
Dimensione: $SIZE byte
EOF
printf '%s  %s\n' "$SHA" "releases/1.3.13/pkg_decaroforms_1.3.13.zip" > "$OUTDIR/SHA256SUMS.txt"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.3.13</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.3.13/pkg_decaroforms_1.3.13.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF
cat > "$ROOT/updates/changelog.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>1.3.13</version>
<change>Campi selezionati e layout riuniti in un unico Form Builder visuale compatto.</change>
<change>Trascinamento, larghezza, modifica, duplicazione ed eliminazione disponibili direttamente sui campi.</change>
<change>Pannello proprietà dedicato al solo campo selezionato e interfaccia responsive.</change>
<language>it-IT</language>
</changelog></changelogs>
EOF
python3 - "$ROOT/updates/pkg_decaroforms.xml" "$ROOT/updates/changelog.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET
for name in sys.argv[1:]:
    ET.parse(name)
PY
python3 - "$ROOT/README.md" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); t=p.read_text()
t=re.sub(r'(## Current development version\n\n)\*\*[^*]+\*\*',r'\1**1.3.13**',t,1)
p.write_text(t)
PY

echo "Built Forms 1.3.13: $SHA ($SIZE bytes)"
