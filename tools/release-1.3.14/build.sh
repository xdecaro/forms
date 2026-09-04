#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TOOL="$ROOT/tools/release-1.3.14"
BASE="$ROOT/releases/1.3.13/pkg_decaroforms_1.3.13.zip"
OUTDIR="$ROOT/releases/1.3.14"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -f "$BASE" ] || { echo "Missing base package: $BASE" >&2; exit 1; }
mkdir -p "$TMP/outer" "$TMP/component" "$TMP/plugin" "$OUTDIR"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.13.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.13.zip" -d "$TMP/plugin"
python3 "$TOOL/patch.py" "$TMP/component" "$TMP/plugin"

if command -v php >/dev/null 2>&1; then
  while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.php' -print0)
else
  python3 - "$TMP/component/com_decaroforms.xml" "$TMP/plugin/decaroforms.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET
for name in sys.argv[1:]: ET.parse(name)
PY
fi

BUILDER="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
HELPER="$TMP/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
grep -q "public const VERSION = '1.3.14'" "$HELPER"
grep -q '<version>1.3.14</version>' "$TMP/component/com_decaroforms.xml"
grep -q '<version>1.3.14</version>' "$TMP/plugin/decaroforms.xml"
for token in 'setFieldWidth(index,width)' 'df-required-badge' 'Stati e visualizzazione' 'statusConflicts()' 'df-email-thumb-frame' 'Bloccato' 'function restoreHistory' 'type'"'"'=>'"'"'tax_code' 'key'"'"'=>'"'"'province'; do grep -q "$token" "$BUILDER" "$HELPER"; done
! grep -q 'Layout manuale avanzato' "$BUILDER"

# Check the generated JavaScript syntax after replacing PHP expressions with harmless literals.
python3 - "$BUILDER" "$TMP/builder.js" <<'PY'
from pathlib import Path
import re,sys
t=Path(sys.argv[1]).read_text()
scripts=re.findall(r'<script>(.*?)</script>',t,re.S)
js='\n'.join(scripts)
js=re.sub(r"'<\?php.*?\?>'", "'PHP'", js, flags=re.S)
js=re.sub(r'<\?php.*?\?>', 'null', js, flags=re.S)
Path(sys.argv[2]).write_text(js)
PY
node --check "$TMP/builder.js"

COMPZIP="$TMP/com_decaroforms_1.3.14.zip"
PLUGZIP="$TMP/plg_system_decaroforms_1.3.14.zip"
(cd "$TMP/component" && zip -qr "$COMPZIP" .)
(cd "$TMP/plugin" && zip -qr "$PLUGZIP" .)
rm -f "$TMP/outer/com_decaroforms_1.3.13.zip" "$TMP/outer/plg_system_decaroforms_1.3.13.zip"
cp "$COMPZIP" "$TMP/outer/com_decaroforms_1.3.14.zip"
cp "$PLUGZIP" "$TMP/outer/plg_system_decaroforms_1.3.14.zip"
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); t=p.read_text()
t=t.replace('<version>1.3.13</version>','<version>1.3.14</version>')
t=t.replace('plg_system_decaroforms_1.3.13.zip','plg_system_decaroforms_1.3.14.zip')
t=t.replace('com_decaroforms_1.3.13.zip','com_decaroforms_1.3.14.zip')
p.write_text(t)
PY
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET
ET.parse(sys.argv[1])
PY

TARGET="$OUTDIR/pkg_decaroforms_1.3.14.zip"
rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
SIZE="$(stat -c%s "$TARGET")"

python3 - "$OUTDIR/README.md" "$SHA" "$SIZE" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).write_text(f'''# Forms 1.3.14

Form Builder più sicuro, automatico e leggibile.

- Le larghezze della stessa riga vengono bilanciate automaticamente al 100%.
- Badge rosso Obbligatorio nel canvas e nelle proprietà.
- Proprietà principali e condizioni avanzate riorganizzate.
- Aggiunti Provincia e Codice fiscale con controlli dedicati.
- Stati semplificati, chiavi tecniche nascoste e conflitti bloccati.
- Dodici anteprime email reali in griglia 6+6.
- Modalità Bloccato/Modifica e storico Annulla/Ripristina (50 passaggi).

SHA-256: {sys.argv[2]}
Dimensione: {sys.argv[3]} byte
''')
PY
printf '%s  %s\n' "$SHA" "releases/1.3.14/pkg_decaroforms_1.3.14.zip" > "$OUTDIR/SHA256SUMS.txt"

python3 - "$ROOT/updates/pkg_decaroforms.xml" "$SHA" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); t=p.read_text()
t=re.sub(r'<version>[^<]+</version>','<version>1.3.14</version>',t,1)
t=re.sub(r'releases/[0-9.]+/pkg_decaroforms_[0-9.]+\.zip','releases/1.3.14/pkg_decaroforms_1.3.14.zip',t)
t=re.sub(r'<sha256>[^<]+</sha256>',f'<sha256>{sys.argv[2]}</sha256>',t,1)
p.write_text(t)
PY
python3 - "$ROOT/updates/changelog.xml" <<'PY'
from pathlib import Path
import sys
Path(sys.argv[1]).write_text('''<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>1.3.14</version>
<change>Larghezze dei campi bilanciate automaticamente al 100% per ogni riga.</change>
<change>Modalità Bloccato/Modifica e storico Annulla/Ripristina fino a 50 modifiche.</change>
<change>Proprietà campo, condizioni, stati e anteprime email resi più chiari.</change>
<change>Aggiunti Provincia e controllo dedicato del Codice fiscale.</change>
<language>it-IT</language>
</changelog></changelogs>
''')
PY
python3 - "$ROOT/README.md" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); t=p.read_text()
t=re.sub(r'(## Current development version\n\n)\*\*[^*]+\*\*',r'\1**1.3.14**',t,1)
p.write_text(t)
PY
python3 - "$ROOT/updates/pkg_decaroforms.xml" "$ROOT/updates/changelog.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET
for name in sys.argv[1:]: ET.parse(name)
PY
unzip -t "$TARGET" >/dev/null
echo "Built Forms 1.3.14: $SHA ($SIZE bytes)"
