#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TOOL="$ROOT/tools/release-1.3.19"
BASE="$ROOT/releases/1.3.18/pkg_decaroforms_1.3.18.zip"
OUTDIR="$ROOT/releases/1.3.19"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -f "$BASE" ] || { echo "Missing base package: $BASE" >&2; exit 1; }
mkdir -p "$TMP/outer" "$TMP/component" "$TMP/plugin" "$OUTDIR"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.18.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.18.zip" -d "$TMP/plugin"
python3 "$TOOL/patch.py" "$TMP/component" "$TMP/plugin"

while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.php' -print0)
while IFS= read -r -d '' f; do php -r '$x=parse_ini_file($argv[1],false,INI_SCANNER_RAW); if($x===false){fwrite(STDERR,"Invalid INI: {$argv[1]}\n"); exit(1);}' "$f"; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.ini' -print0)
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/component/com_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/plugin/decaroforms.xml"

BUILDER="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
HELPER="$TMP/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
grep -q "public const VERSION = '1.3.19'" "$HELPER"
grep -q '<version>1.3.19</version>' "$TMP/component/com_decaroforms.xml"
grep -q '<version>1.3.19</version>' "$TMP/plugin/decaroforms.xml"
grep -q 'function openActionModal' "$BUILDER"
grep -q 'Conferma eliminazione' "$BUILDER"
grep -q 'Salva struttura del modulo' "$BUILDER"
grep -q 'moveFieldBeside' "$BUILDER"
grep -q 'df-layout-drop-guide' "$BUILDER"
grep -q 'renderEmailPickers(false)' "$BUILDER"
grep -q 'df-email-preview-btn' "$BUILDER"
grep -q 'card.dataset.fieldKey' "$BUILDER"

COMPZIP="$TMP/com_decaroforms_1.3.19.zip"
PLUGZIP="$TMP/plg_system_decaroforms_1.3.19.zip"
(cd "$TMP/component" && zip -qr "$COMPZIP" .)
(cd "$TMP/plugin" && zip -qr "$PLUGZIP" .)
rm -f "$TMP/outer/com_decaroforms_1.3.18.zip" "$TMP/outer/plg_system_decaroforms_1.3.18.zip"
cp "$COMPZIP" "$TMP/outer/com_decaroforms_1.3.19.zip"
cp "$PLUGZIP" "$TMP/outer/plg_system_decaroforms_1.3.19.zip"
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); t=p.read_text()
t=t.replace('<version>1.3.18</version>','<version>1.3.19</version>')
t=t.replace('plg_system_decaroforms_1.3.18.zip','plg_system_decaroforms_1.3.19.zip')
t=t.replace('com_decaroforms_1.3.18.zip','com_decaroforms_1.3.19.zip')
p.write_text(t)
PY
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/outer/pkg_decaroforms.xml"

TARGET="$OUTDIR/pkg_decaroforms_1.3.19.zip"
rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
SIZE="$(stat -c%s "$TARGET")"

cat > "$OUTDIR/README.md" <<EOF
# Forms 1.3.19

Miglioramenti Builder: conferme sicure, anteprime email ripristinate e layout drag & drop bidimensionale.

- Aggiunta una modal riutilizzabile per tutte le azioni di eliminazione nel Builder: modulo, modello rapido, campo personalizzato, campo del modulo, stato, condizione ed email aggiuntiva.
- “Salva struttura” ora usa una modal con nome del modello e conferma esplicita; anche “Salva come campo personalizzato” richiede conferma.
- Ripristinate le anteprime dei template email: le card sono sempre visibili e il pulsante “◉ Anteprima” apre il facsimile; gli iframe completi restano caricati solo quando serve.
- “Modifica campo” è più veloce: non ricostruisce più il canvas due volte e non riesegue la scansione globale dei controlli durante ogni modifica.
- Drag & drop del layout esteso a righe e colonne: a sinistra/destra si crea o riordina una colonna nella stessa riga; al centro si crea una nuova riga.
- Badge Tipo/Larghezza più leggibili rispetto allo sfondo della testata del campo.
- Accordion interni del pannello campo più compatti e uniformi.
- Consolidati i colori dei pulsanti principali/secondari/distruttivi per evitare conflitti nero/rosso tra light e dark mode.

SHA-256: $SHA
Dimensione: $SIZE byte
EOF
printf '%s  %s\n' "$SHA" "releases/1.3.19/pkg_decaroforms_1.3.19.zip" > "$OUTDIR/SHA256SUMS.txt"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.3.19</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.3.19/pkg_decaroforms_1.3.19.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF
cat > "$ROOT/updates/changelog.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>1.3.19</version>
<feature>Aggiunta modal di conferma comune per tutte le eliminazioni del Builder.</feature>
<feature>Salva struttura e Salva campo personalizzato ora usano una modal di conferma.</feature>
<fix>Ripristinate le anteprime e il pulsante Anteprima dei template email.</fix>
<performance>Ottimizzata l’apertura di Modifica campo evitando ricostruzioni duplicate del canvas e scansioni globali non necessarie.</performance>
<feature>Layout visuale con drag and drop bidimensionale per righe e colonne.</feature>
<fix>Migliorato il contrasto dei badge Tipo e Larghezza e compattati gli accordion interni.</fix>
<fix>Uniformati i colori dei pulsanti principali, secondari e distruttivi in light e dark mode.</fix>
<language>it-IT</language>
</changelog></changelogs>
EOF
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/pkg_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/changelog.xml"
python3 - "$ROOT/README.md" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); t=p.read_text()
t=re.sub(r'(## Current development version\n\n)\*\*[^*]+\*\*',r'\1**1.3.19**',t,1)
p.write_text(t)
PY

echo "Built Forms 1.3.19: $SHA ($SIZE bytes)"
