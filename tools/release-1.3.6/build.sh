#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TOOL="$ROOT/tools/release-1.3.6"
BASE="$ROOT/releases/1.3.5/pkg_decaroforms_1.3.5.zip"
OUTDIR="$ROOT/releases/1.3.6"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -f "$BASE" ] || { echo "Missing base package: $BASE" >&2; exit 1; }
mkdir -p "$TMP/outer" "$TMP/component" "$TMP/plugin" "$OUTDIR"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.5.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.5.zip" -d "$TMP/plugin"
python3 "$TOOL/patch.py" "$TMP/component" "$TMP/plugin"

while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.php' -print0)
while IFS= read -r -d '' f; do php -r '$x=parse_ini_file($argv[1],false,INI_SCANNER_RAW); if($x===false){fwrite(STDERR,"Invalid INI: {$argv[1]}\n"); exit(1);}' "$f"; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.ini' -print0)
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/component/com_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/plugin/decaroforms.xml"

BUILDER="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
HELPER="$TMP/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
grep -q "public const VERSION = '1.3.6'" "$HELPER"
grep -q '<version>1.3.6</version>' "$TMP/component/com_decaroforms.xml"
grep -q '<version>1.3.6</version>' "$TMP/plugin/decaroforms.xml"
grep -q 'Forms 1.3.6: bind quick templates early' "$BUILDER"
grep -q 'selected.splice(0,selected.length,...next)' "$BUILDER"
grep -q "openBuilderSection(2,false)" "$BUILDER"
grep -q "scrollIntoView({behavior:'smooth',block:'center'})" "$BUILDER"
grep -q 'Forms 1.3.6 mobile library + status UX' "$BUILDER"
if grep -Fq 'const formTemplates={' "$BUILDER"; then echo 'Legacy formTemplates definition still present' >&2; exit 1; fi

# Sanity check: every field used by a quick template must exist in the field library.
python3 - "$BUILDER" "$HELPER" <<'PY'
from pathlib import Path
import re,sys
b=Path(sys.argv[1]).read_text(); h=Path(sys.argv[2]).read_text()
m=re.search(r"const quickFormTemplates=\{(.*?)\};",b,re.S)
if not m: raise SystemExit('quickFormTemplates missing')
used=set(re.findall(r"'([a-z0-9_]+)'",m.group(1))) - {'blank','contact','registration','event','membership','reservation'}
keys=set(re.findall(r"\['key'=>'([^']+)'",h))
missing=sorted(used-keys)
if missing: raise SystemExit('quick template keys missing from library: '+','.join(missing))
print('Quick templates validated:',len(used),'field keys')
PY

COMPZIP="$TMP/com_decaroforms_1.3.6.zip"
PLUGZIP="$TMP/plg_system_decaroforms_1.3.6.zip"
(cd "$TMP/component" && zip -qr "$COMPZIP" .)
(cd "$TMP/plugin" && zip -qr "$PLUGZIP" .)
rm -f "$TMP/outer/com_decaroforms_1.3.5.zip" "$TMP/outer/plg_system_decaroforms_1.3.5.zip"
cp "$COMPZIP" "$TMP/outer/com_decaroforms_1.3.6.zip"
cp "$PLUGZIP" "$TMP/outer/plg_system_decaroforms_1.3.6.zip"
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); t=p.read_text()
t=t.replace('<version>1.3.5</version>','<version>1.3.6</version>')
t=t.replace('plg_system_decaroforms_1.3.5.zip','plg_system_decaroforms_1.3.6.zip')
t=t.replace('com_decaroforms_1.3.5.zip','com_decaroforms_1.3.6.zip')
p.write_text(t)
PY
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/outer/pkg_decaroforms.xml"

TARGET="$OUTDIR/pkg_decaroforms_1.3.6.zip"
rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
SIZE="$(stat -c%s "$TARGET")"

cat > "$OUTDIR/README.md" <<EOF
# Forms 1.3.6

Correzioni Builder smartphone e Modelli rapidi.

- Modelli rapidi resi robusti e collegati prima delle inizializzazioni secondarie del Builder.
- I preset Contatto, Iscrizione, Evento, Tesseramento e Prenotazione popolano subito Campi selezionati e Layout.
- Aggiungendo un campo dalla Libreria si apre automaticamente Campi selezionati, si apre il nuovo campo e viene eseguito uno scroll morbido.
- Categorie della Libreria corrette in dark mode con contrasto coerente.
- Stati del modulo su smartphone organizzati in card 2×2 più leggibili.
- Pulsante elimina stato evidenziato in rosso per distinguerlo dalle azioni normali.

SHA-256: $SHA
Dimensione: $SIZE byte
EOF
printf '%s  %s\n' "$SHA" "releases/1.3.6/pkg_decaroforms_1.3.6.zip" > "$OUTDIR/SHA256SUMS.txt"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.3.6</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.3.6/pkg_decaroforms_1.3.6.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF
cat > "$ROOT/updates/changelog.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>1.3.6</version>
<fix>Modelli rapidi resi robusti e correttamente applicati ai campi selezionati.</fix>
<change>Apertura automatica del nuovo campo aggiunto dalla Libreria.</change>
<fix>Contrasto delle categorie Libreria corretto in dark mode.</fix>
<change>Stati del modulo smartphone ridisegnati in griglia 2×2 con eliminazione rossa.</change>
<language>it-IT</language>
</changelog></changelogs>
EOF
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/pkg_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/changelog.xml"
echo "Built Forms 1.3.6: $SHA ($SIZE bytes)"
