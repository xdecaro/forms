#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TOOL="$ROOT/tools/release-1.3.1"
BASE="$ROOT/releases/1.3.0/pkg_decaroforms_1.3.0.zip"
OUTDIR="$ROOT/releases/1.3.1"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -f "$BASE" ] || { echo "Missing base package: $BASE" >&2; exit 1; }
mkdir -p "$TMP/outer" "$TMP/component" "$TMP/plugin" "$OUTDIR"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.0.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.0.zip" -d "$TMP/plugin"

python3 "$TOOL/patch.py" "$TMP/component" "$TMP/plugin"

# Static PHP / manifest / language checks.
while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.php' -print0)
while IFS= read -r -d '' f; do php -r '$x=parse_ini_file($argv[1],false,INI_SCANNER_RAW); if($x===false){fwrite(STDERR,"Invalid INI: {$argv[1]}\n"); exit(1);}' "$f"; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.ini' -print0)
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/component/com_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/plugin/decaroforms.xml"

BUILDER="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
HELPER="$TMP/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
grep -q "public const VERSION = '1.3.1'" "$HELPER"
grep -q '<version>1.3.1</version>' "$TMP/component/com_decaroforms.xml"
grep -q '<version>1.3.1</version>' "$TMP/plugin/decaroforms.xml"
grep -q 'json_encode(FormHelper::fieldLibrary()' "$BUILDER"
grep -q "renderLibrary();" "$BUILDER"
grep -q "Applicato a" "$BUILDER"
grep -q "statuses.push({key:'',label:''" "$BUILDER"
grep -q "background:var(--df);color:#fff" "$BUILDER"

# Builder sanity checks: required DOM ids exist and expanded field library is present.
python3 - "$BUILDER" "$HELPER" <<'PY'
from pathlib import Path
import re,sys
builder=Path(sys.argv[1]).read_text()
helper=Path(sys.argv[2]).read_text()
ids=set(re.findall(r'id="([A-Za-z0-9_-]+)"',builder))
refs=set(re.findall(r"getElementById\('([A-Za-z0-9_-]+)'\)",builder))
missing=sorted(refs-ids)
if missing:
    raise SystemExit('Missing static DOM ids used by builder JS: '+', '.join(missing))
keys=len(re.findall(r"\['key'=>'",helper))
if keys < 40:
    raise SystemExit(f'Field library unexpectedly small: {keys} entries')
for token in ['df-library','df-layout-apply','df-status-editor','df-selected','df-add-status']:
    if token not in builder:
        raise SystemExit(f'Missing builder core token: {token}')
print(f'Builder sanity OK: {keys} library entries, {len(refs)} static DOM references')
PY

# Rebuild inner extension archives.
COMPZIP="$TMP/com_decaroforms_1.3.1.zip"
PLUGZIP="$TMP/plg_system_decaroforms_1.3.1.zip"
(cd "$TMP/component" && zip -qr "$COMPZIP" .)
(cd "$TMP/plugin" && zip -qr "$PLUGZIP" .)
rm -f "$TMP/outer/com_decaroforms_1.3.0.zip" "$TMP/outer/plg_system_decaroforms_1.3.0.zip"
cp "$COMPZIP" "$TMP/outer/com_decaroforms_1.3.1.zip"
cp "$PLUGZIP" "$TMP/outer/plg_system_decaroforms_1.3.1.zip"
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); t=p.read_text()
t=t.replace('<version>1.3.0</version>','<version>1.3.1</version>')
t=t.replace('plg_system_decaroforms_1.3.0.zip','plg_system_decaroforms_1.3.1.zip')
t=t.replace('com_decaroforms_1.3.0.zip','com_decaroforms_1.3.1.zip')
p.write_text(t)
PY
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/outer/pkg_decaroforms.xml"

TARGET="$OUTDIR/pkg_decaroforms_1.3.1.zip"
rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
SIZE="$(stat -c%s "$TARGET")"

cat > "$OUTDIR/README.md" <<EOF
# Forms 1.3.1

Correzione mirata del Builder di Forms 1.3.0.

## Correzioni
- Libreria campi caricata direttamente dal catalogo FormHelper e renderizzata subito.
- Modelli rapidi funzionanti: al click compilano i campi e aprono automaticamente Campi selezionati.
- Applica ai campi ora dà conferma visiva e apre Campi selezionati per verificare Riga / Colonna / Larghezza.
- Stati del modulo renderizzati subito; + Aggiungi stato crea una riga vuota e non duplica "Nuovo" con "Nuovo stato".
- Colonne tabella renderizzate subito.
- Intestazioni accordion rosse secondo lo stile approvato.
- Controllo build sui riferimenti DOM e sulla dimensione della Libreria campi.

SHA-256: $SHA
Dimensione: $SIZE byte
EOF
printf '%s  %s\n' "$SHA" "releases/1.3.1/pkg_decaroforms_1.3.1.zip" > "$OUTDIR/SHA256SUMS.txt"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.3.1</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.3.1/pkg_decaroforms_1.3.1.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF

cat > "$ROOT/updates/changelog.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<changelogs>
  <changelog>
    <element>pkg_decaroforms</element>
    <type>package</type>
    <version>1.3.1</version>
    <fix>Libreria campi, modelli rapidi e Applica ai campi resi immediatamente operativi e verificabili nel Builder.</fix>
    <fix>Nuovo stato non viene più creato con etichetta duplicata; stati e colonne sono renderizzati subito.</fix>
    <addition>Accordion rossi e conferma visiva dell'applicazione del layout.</addition>
    <language>it-IT</language>
  </changelog>
</changelogs>
EOF

php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/pkg_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/changelog.xml"
echo "Built Forms 1.3.1: $SHA ($SIZE bytes)"
