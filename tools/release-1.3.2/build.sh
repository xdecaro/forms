#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TOOL="$ROOT/tools/release-1.3.2"
BASE="$ROOT/releases/1.3.1/pkg_decaroforms_1.3.1.zip"
OUTDIR="$ROOT/releases/1.3.2"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -f "$BASE" ] || { echo "Missing base package: $BASE" >&2; exit 1; }
mkdir -p "$TMP/outer" "$TMP/component" "$TMP/plugin" "$OUTDIR"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.1.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.1.zip" -d "$TMP/plugin"
python3 "$TOOL/patch.py" "$TMP/component" "$TMP/plugin"

while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.php' -print0)
while IFS= read -r -d '' f; do php -r '$x=parse_ini_file($argv[1],false,INI_SCANNER_RAW); if($x===false){fwrite(STDERR,"Invalid INI: {$argv[1]}\n"); exit(1);}' "$f"; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.ini' -print0)
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/component/com_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/plugin/decaroforms.xml"

BUILDER="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
HELPER="$TMP/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
grep -q "public const VERSION = '1.3.2'" "$HELPER"
grep -q '<version>1.3.2</version>' "$TMP/component/com_decaroforms.xml"
grep -q '<version>1.3.2</version>' "$TMP/plugin/decaroforms.xml"
grep -q 'df-layout-canvas' "$BUILDER"
grep -q 'df-library-tabs' "$BUILDER"
grep -q 'df-field-toggle' "$BUILDER"
grep -q 'df-condition-details' "$BUILDER"
grep -q 'df-closed-box' "$BUILDER"
grep -q 'df-switch-ui' "$BUILDER"
grep -q "['\"']iban['\"']" "$HELPER"
grep -q "['\"']payment_reference['\"']" "$HELPER"

python3 - "$BUILDER" "$HELPER" <<'PY'
from pathlib import Path
import re,sys
builder=Path(sys.argv[1]).read_text(); helper=Path(sys.argv[2]).read_text()
ids=set(re.findall(r'id="([A-Za-z0-9_-]+)"',builder))
refs=set(re.findall(r"getElementById\('([A-Za-z0-9_-]+)'\)",builder))
missing=sorted(refs-ids)
if missing: raise SystemExit('Missing static DOM ids: '+', '.join(missing))
if "['receipt'" in re.search(r'const templateDefs=.*?;',builder,re.S).group(0): raise SystemExit('Receipt template still in selectable defaults')
tpl=re.search(r'const templateDefs=(.*?);',builder,re.S).group(1)
for token in ["['standard'","['minimal'","['institutional'","['card'","['compact'","['modern'","['elegant'","['custom'","['html'","['chatgpt'"]:
    if token not in tpl: raise SystemExit('Missing email template '+token)
if len(re.findall(r"\['key'=>'",helper)) < 60: raise SystemExit('Field library unexpectedly small')
for token in ['payment_method','iban','account_holder','payment_amount','payment_cause','payment_reference']:
    if f"'key'=>'{token}'" not in helper: raise SystemExit('Missing payment field '+token)
print('Forms 1.3.2 builder sanity OK')
PY

COMPZIP="$TMP/com_decaroforms_1.3.2.zip"
PLUGZIP="$TMP/plg_system_decaroforms_1.3.2.zip"
(cd "$TMP/component" && zip -qr "$COMPZIP" .)
(cd "$TMP/plugin" && zip -qr "$PLUGZIP" .)
rm -f "$TMP/outer/com_decaroforms_1.3.1.zip" "$TMP/outer/plg_system_decaroforms_1.3.1.zip"
cp "$COMPZIP" "$TMP/outer/com_decaroforms_1.3.2.zip"
cp "$PLUGZIP" "$TMP/outer/plg_system_decaroforms_1.3.2.zip"
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); t=p.read_text()
t=t.replace('<version>1.3.1</version>','<version>1.3.2</version>')
t=t.replace('plg_system_decaroforms_1.3.1.zip','plg_system_decaroforms_1.3.2.zip')
t=t.replace('com_decaroforms_1.3.1.zip','com_decaroforms_1.3.2.zip')
p.write_text(t)
PY
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/outer/pkg_decaroforms.xml"

TARGET="$OUTDIR/pkg_decaroforms_1.3.2.zip"
rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
SIZE="$(stat -c%s "$TARGET")"

cat > "$OUTDIR/README.md" <<EOF
# Forms 1.3.2

Aggiornamento UX del Builder.

- Ripristinate intestazioni accordion chiare; rosso riservato al blocco di chiusura modulo.
- Switch blu per Attivo e Mostra titolo del modulo.
- Campi selezionati compatti ad accordion; Condizioni avanzate come sotto-accordion.
- Layout visuale drag & drop con righe e larghezze rapide; valori manuali restano nelle impostazioni avanzate.
- Libreria campi con categorie compatte in alto e ricerca globale.
- Aggiunti campi Pagamento separati: metodo, IBAN, intestatario, importo, causale e riferimento.
- Validazione riscritta con termini più chiari e spiegazioni ⓘ cliccabili.
- Email: 7 template grafici predefiniti + Personalizzato + HTML libero + AI.
- Modelli rapidi resi più robusti e apertura automatica di Campi selezionati.

SHA-256: $SHA
Dimensione: $SIZE byte
EOF
printf '%s  %s\n' "$SHA" "releases/1.3.2/pkg_decaroforms_1.3.2.zip" > "$OUTDIR/SHA256SUMS.txt"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.3.2</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.3.2/pkg_decaroforms_1.3.2.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF
cat > "$ROOT/updates/changelog.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>1.3.2</version>
<addition>Layout visuale drag & drop, campi selezionati ad accordion e libreria categorie compatte.</addition>
<addition>Campi pagamento separati, incluso IBAN e riferimento pagamento.</addition>
<change>Validazione semplificata con spiegazioni informative cliccabili.</change>
<change>Email: sette template predefiniti più Personalizzato, HTML libero e AI.</change>
<fix>Ripristinato stile chiaro degli accordion e rafforzata la logica dei modelli rapidi.</fix>
<language>it-IT</language>
</changelog></changelogs>
EOF
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/pkg_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/changelog.xml"
echo "Built Forms 1.3.2: $SHA ($SIZE bytes)"
