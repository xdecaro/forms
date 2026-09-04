#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TOOL="$ROOT/tools/release-1.3.0"
BASE="$ROOT/releases/1.2.22/pkg_decaroforms_1.2.22.zip"
OUTDIR="$ROOT/releases/1.3.0"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -f "$BASE" ] || { echo "Missing base package: $BASE" >&2; exit 1; }
mkdir -p "$TMP/outer" "$TMP/component" "$TMP/plugin" "$OUTDIR"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.2.22.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.2.22.zip" -d "$TMP/plugin"

# Overlay redesigned sources, then patch the rest of the proven 1.2.22 package in place.
cp -R "$TOOL/src/component/." "$TMP/component/"
cp -R "$TOOL/src/plugin/." "$TMP/plugin/"
python3 "$TOOL/apply.py" "$TMP/component" "$TMP/plugin" "$TOOL"
python3 "$TOOL/plugin_fix.py" "$TMP/plugin/src/Extension/FormsPlugin.php"
python3 "$TOOL/translations.py" "$TMP/component" "$TMP/plugin"

# Static checks before packaging.
while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.php' -print0)
while IFS= read -r -d '' f; do php -r '$x=parse_ini_file($argv[1],false,INI_SCANNER_RAW); if($x===false){fwrite(STDERR,"Invalid INI: {$argv[1]}\n"); exit(1);}' "$f"; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.ini' -print0)
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/component/com_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/plugin/decaroforms.xml"

grep -q "public const VERSION = '1.3.0'" "$TMP/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
grep -q '<version>1.3.0</version>' "$TMP/component/com_decaroforms.xml"
grep -q '<version>1.3.0</version>' "$TMP/plugin/decaroforms.xml"
grep -q 'builder_config_json' "$TMP/component/script.php"
grep -q 'payment_json' "$TMP/component/script.php"
grep -q 'COM_DECAROFORMS_SECTION_LAYOUT' "$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
grep -q 'PLG_SYSTEM_DECAROFORMS_BANK_TRANSFER' "$TMP/plugin/src/Extension/FormsPlugin.php"

# Rebuild inner extension archives.
COMPZIP="$TMP/com_decaroforms_1.3.0.zip"
PLUGZIP="$TMP/plg_system_decaroforms_1.3.0.zip"
(cd "$TMP/component" && zip -qr "$COMPZIP" .)
(cd "$TMP/plugin" && zip -qr "$PLUGZIP" .)
rm -f "$TMP/outer/com_decaroforms_1.2.22.zip" "$TMP/outer/plg_system_decaroforms_1.2.22.zip"
cp "$COMPZIP" "$TMP/outer/com_decaroforms_1.3.0.zip"
cp "$PLUGZIP" "$TMP/outer/plg_system_decaroforms_1.3.0.zip"
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); t=p.read_text()
t=t.replace('<version>1.2.22</version>','<version>1.3.0</version>').replace('<creationDate>2026-09-03</creationDate>','<creationDate>2026-09-04</creationDate>').replace('plg_system_decaroforms_1.2.22.zip','plg_system_decaroforms_1.3.0.zip').replace('com_decaroforms_1.2.22.zip','com_decaroforms_1.3.0.zip')
p.write_text(t)
PY
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/outer/pkg_decaroforms.xml"

TARGET="$OUTDIR/pkg_decaroforms_1.3.0.zip"
rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
SIZE="$(stat -c%s "$TARGET")"

cat > "$OUTDIR/README.md" <<EOF
# Forms 1.3.0

Builder avanzato e frontend aggiornati sulla base di Forms 1.2.22.

## Principali novità
- Builder a 10 sezioni accordion responsive: impostazioni, modelli, campi, layout, libreria, invii, email, validazione, codice personalizzato, integrazioni.
- Layout 1–4 colonne con percentuali 0–100, preset e stacking smartphone.
- Libreria campi raggruppata con nuovi tipi: CAP Italia, regione/paese/nazionalità, mappa, range slider, upload multiplo, pagamento, separatore, pagebreak, multipage, calcoli e campi struttura.
- Conditional Fields con logica ALL/ANY e azioni mostra/nascondi/obbligatorio/disabilita.
- Pagamento via bonifico con IBAN, importo, causale dinamica, riferimento persistente e stato Da verificare/Verificato.
- Email separate amministrazione/utente, email aggiuntive condizionali, variabili, allegati e fallback globale Forms/Joomla.
- 8 template email pronti + Personalizzato + HTML libero + generatore prompt ChatGPT (nessun dato reale esportato automaticamente).
- Conferma frontend sotto Invia, opzioni sostituzione/modal, multipage con Indietro/Avanti e barra avanzamento.
- CSS/JavaScript per-form riservati ai Super User.
- Google Sheets tramite webhook HTTPS Google Apps Script; il database Joomla resta la fonte principale.
- Nuove impostazioni globali mittente e Reply-To.

SHA-256: $SHA
Dimensione: $SIZE byte
EOF

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.3.0</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.3.0/pkg_decaroforms_1.3.0.zip</downloadurl></downloads>
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
    <version>1.3.0</version>
    <security>Codice CSS/JavaScript per-form limitato ai Super User; validazione server e condizioni applicate anche al submit.</security>
    <fix>Messaggio di conferma spostato sotto il pulsante Invia; gestione email resa più chiara con fallback Forms/Joomla.</fix>
    <addition>Builder accordion, layout colonne, libreria estesa, conditional fields, multipage, pagamento bonifico, 11 modalità template email, email aggiuntive, calcoli, mappa e Google Sheets webhook.</addition>
    <language>it-IT</language>
  </changelog>
</changelogs>
EOF

php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/pkg_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/changelog.xml"

printf '%s  %s\n' "$SHA" "releases/1.3.0/pkg_decaroforms_1.3.0.zip" > "$OUTDIR/SHA256SUMS.txt"
echo "Built Forms 1.3.0: $SHA ($SIZE bytes)"
