#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TOOL="$ROOT/tools/release-1.3.15"
BASE="$ROOT/releases/1.3.14/pkg_decaroforms_1.3.14.zip"
OUTDIR="$ROOT/releases/1.3.15"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -f "$BASE" ] || { echo "Missing base package: $BASE" >&2; exit 1; }
mkdir -p "$TMP/outer" "$TMP/component" "$TMP/plugin" "$OUTDIR"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.14.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.14.zip" -d "$TMP/plugin"
python3 "$TOOL/patch.py" "$TMP/component" "$TMP/plugin"

while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.php' -print0)
while IFS= read -r -d '' f; do php -r '$x=parse_ini_file($argv[1],false,INI_SCANNER_RAW); if($x===false){fwrite(STDERR,"Invalid INI: {$argv[1]}\n"); exit(1);}' "$f"; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.ini' -print0)
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/component/com_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/plugin/decaroforms.xml"

BUILDER="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
HELPER="$TMP/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
grep -q "public const VERSION = '1.3.15'" "$HELPER"
grep -q '<version>1.3.15</version>' "$TMP/component/com_decaroforms.xml"
grep -q '<version>1.3.15</version>' "$TMP/plugin/decaroforms.xml"
grep -q 'df-layout-settings' "$BUILDER"
grep -q 'Layout e larghezza' "$BUILDER"
grep -q 'Forms 1.3.15' "$BUILDER"

COMPZIP="$TMP/com_decaroforms_1.3.15.zip"
PLUGZIP="$TMP/plg_system_decaroforms_1.3.15.zip"
(cd "$TMP/component" && zip -qr "$COMPZIP" .)
(cd "$TMP/plugin" && zip -qr "$PLUGZIP" .)
rm -f "$TMP/outer/com_decaroforms_1.3.14.zip" "$TMP/outer/plg_system_decaroforms_1.3.14.zip"
cp "$COMPZIP" "$TMP/outer/com_decaroforms_1.3.15.zip"
cp "$PLUGZIP" "$TMP/outer/plg_system_decaroforms_1.3.15.zip"
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); t=p.read_text()
t=t.replace('<version>1.3.14</version>','<version>1.3.15</version>')
t=t.replace('plg_system_decaroforms_1.3.14.zip','plg_system_decaroforms_1.3.15.zip')
t=t.replace('com_decaroforms_1.3.14.zip','com_decaroforms_1.3.15.zip')
p.write_text(t)
PY
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/outer/pkg_decaroforms.xml"

TARGET="$OUTDIR/pkg_decaroforms_1.3.15.zip"
rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
SIZE="$(stat -c%s "$TARGET")"

cat > "$OUTDIR/README.md" <<EOF
# Forms 1.3.15

Correzioni light mode e proprietà campo del Form Builder.

- Eliminati gli sfondi scuri errati in light mode da Stati e visualizzazione, Impostazioni email e Validazione e conferma.
- Corretto il contrasto di testi, input, select, textarea, note e pulsanti nelle sezioni interessate.
- Codice personalizzato torna chiaro in light mode, mantenendo il dark mode separato.
- Le righe/carte del canvas dei campi non diventano più nere quando il sistema operativo preferisce il tema scuro ma Joomla è in light mode.
- Campo obbligatorio e larghezza sono ora raccolti nell'accordion Layout e larghezza.
- Il salvataggio del campo come personalizzato resta disponibile dall'icona dischetto e vale per tutti i campi.

SHA-256: $SHA
Dimensione: $SIZE byte
EOF
printf '%s  %s\n' "$SHA" "releases/1.3.15/pkg_decaroforms_1.3.15.zip" > "$OUTDIR/SHA256SUMS.txt"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.3.15</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.3.15/pkg_decaroforms_1.3.15.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF
cat > "$ROOT/updates/changelog.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>1.3.15</version>
<fix>Corretti gli sfondi scuri e i contrasti errati in light mode nelle sezioni Stati, Email, Validazione e Codice personalizzato.</fix>
<fix>Il canvas dei campi segue ora esplicitamente il tema Joomla invece della preferenza scura del sistema operativo.</fix>
<change>Campo obbligatorio e larghezza spostati nell'accordion Layout e larghezza.</change>
<language>it-IT</language>
</changelog></changelogs>
EOF
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/pkg_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/changelog.xml"
python3 - "$ROOT/README.md" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); t=p.read_text()
t=re.sub(r'(## Current development version\n\n)\*\*[^*]+\*\*',r'\1**1.3.15**',t,1)
p.write_text(t)
PY

echo "Built Forms 1.3.15: $SHA ($SIZE bytes)"
