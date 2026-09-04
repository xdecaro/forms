#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TOOL="$ROOT/tools/release-1.3.18"
BASE="$ROOT/releases/1.3.17/pkg_decaroforms_1.3.17.zip"
OUTDIR="$ROOT/releases/1.3.18"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -f "$BASE" ] || { echo "Missing base package: $BASE" >&2; exit 1; }
mkdir -p "$TMP/outer" "$TMP/component" "$TMP/plugin" "$OUTDIR"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.17.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.17.zip" -d "$TMP/plugin"
python3 "$TOOL/patch.py" "$TMP/component" "$TMP/plugin"

while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.php' -print0)
while IFS= read -r -d '' f; do php -r '$x=parse_ini_file($argv[1],false,INI_SCANNER_RAW); if($x===false){fwrite(STDERR,"Invalid INI: {$argv[1]}\n"); exit(1);}' "$f"; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.ini' -print0)
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/component/com_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/plugin/decaroforms.xml"

BUILDER="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
CONTROLLER="$TMP/component/administrator/components/com_decaroforms/src/Controller/BuilderController.php"
HELPER="$TMP/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
PLUGIN="$TMP/plugin/src/Extension/FormsPlugin.php"
grep -q "public const VERSION = '1.3.18'" "$HELPER"
grep -q '<version>1.3.18</version>' "$TMP/component/com_decaroforms.xml"
grep -q '<version>1.3.18</version>' "$TMP/plugin/decaroforms.xml"
grep -q 'draftStorageKey' "$BUILDER"
grep -q 'df-success-format' "$BUILDER"
grep -q 'emailPickersRendered' "$BUILDER"
grep -q 'La sessione è scaduta' "$CONTROLLER"
grep -q "'format' =>" "$PLUGIN"
grep -q 'showConfirmModal' "$PLUGIN"

COMPZIP="$TMP/com_decaroforms_1.3.18.zip"
PLUGZIP="$TMP/plg_system_decaroforms_1.3.18.zip"
(cd "$TMP/component" && zip -qr "$COMPZIP" .)
(cd "$TMP/plugin" && zip -qr "$PLUGZIP" .)
rm -f "$TMP/outer/com_decaroforms_1.3.17.zip" "$TMP/outer/plg_system_decaroforms_1.3.17.zip"
cp "$COMPZIP" "$TMP/outer/com_decaroforms_1.3.18.zip"
cp "$PLUGZIP" "$TMP/outer/plg_system_decaroforms_1.3.18.zip"
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); t=p.read_text()
t=t.replace('<version>1.3.17</version>','<version>1.3.18</version>')
t=t.replace('plg_system_decaroforms_1.3.17.zip','plg_system_decaroforms_1.3.18.zip')
t=t.replace('com_decaroforms_1.3.17.zip','com_decaroforms_1.3.18.zip')
p.write_text(t)
PY
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/outer/pkg_decaroforms.xml"

TARGET="$OUTDIR/pkg_decaroforms_1.3.18.zip"
rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
SIZE="$(stat -c%s "$TARGET")"

cat > "$OUTDIR/README.md" <<EOF
# Forms 1.3.18

Salvataggio Builder più sicuro, recupero automatico delle bozze e miglioramenti prestazioni/UX.

- Corretto il salvataggio che poteva terminare con errore 403 senza creare il modulo: token scaduto e autorizzazioni sono ora distinti.
- Il Builder salva automaticamente una bozza locale mentre lavori; in caso di sessione scaduta la bozza resta disponibile dopo il reload.
- Il salvataggio usa una risposta AJAX esplicita e la bozza viene cancellata solo dopo conferma positiva dal server.
- Per i moduli esistenti viene usato il permesso core.edit; per i nuovi moduli core.create.
- “Quando disattivato” e “Messaggio di chiusura” sono nascosti quando il modulo è Attivo e compaiono solo quando viene disattivato.
- Il messaggio di conferma può essere Testo semplice o HTML; il toggle Modal è sincronizzato con “Validazione e conferma”.
- Il frontend usa una vera modal di conferma invece di alert(), con sanitizzazione HTML lato browser.
- “Modifica campo” è più veloce perché il pannello proprietà renderizza soltanto il campo attivo.
- Le miniature iframe dei template email vengono caricate solo quando si apre “Impostazioni email”.
- Pannello Impostazioni campo più compatto e pulsante “Salva struttura” uniformato al rosso Forms.

SHA-256: $SHA
Dimensione: $SIZE byte
EOF
printf '%s  %s\n' "$SHA" "releases/1.3.18/pkg_decaroforms_1.3.18.zip" > "$OUTDIR/SHA256SUMS.txt"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.3.18</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.3.18/pkg_decaroforms_1.3.18.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF
cat > "$ROOT/updates/changelog.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>1.3.18</version>
<fix>Corretto il salvataggio Builder con gestione distinta di token scaduto e autorizzazioni.</fix>
<feature>Aggiunto recupero automatico della bozza locale dopo errori o sessione scaduta.</feature>
<change>Il salvataggio Builder usa risposta AJAX e cancella la bozza solo dopo conferma positiva.</change>
<change>Il pannello del campo renderizza solo il campo attivo e le anteprime email vengono caricate in modo lazy.</change>
<feature>Aggiunto formato Testo/HTML per il messaggio di conferma e vera modal frontend.</feature>
<change>Le impostazioni di chiusura sono visibili solo quando il modulo è disattivato.</change>
<language>it-IT</language>
</changelog></changelogs>
EOF
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/pkg_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/changelog.xml"
python3 - "$ROOT/README.md" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); t=p.read_text()
t=re.sub(r'(## Current development version\n\n)\*\*[^*]+\*\*',r'\1**1.3.18**',t,1)
p.write_text(t)
PY

echo "Built Forms 1.3.18: $SHA ($SIZE bytes)"
