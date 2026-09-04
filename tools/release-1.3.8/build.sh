#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TOOL="$ROOT/tools/release-1.3.8"
BASE="$ROOT/releases/1.3.7/pkg_decaroforms_1.3.7.zip"
OUTDIR="$ROOT/releases/1.3.8"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -f "$BASE" ] || { echo "Missing base package: $BASE" >&2; exit 1; }
mkdir -p "$TMP/outer" "$TMP/component" "$TMP/plugin" "$OUTDIR"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.7.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.7.zip" -d "$TMP/plugin"
python3 "$TOOL/patch.py" "$TMP/component" "$TMP/plugin"

while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.php' -print0)
while IFS= read -r -d '' f; do php -r '$x=parse_ini_file($argv[1],false,INI_SCANNER_RAW); if($x===false){fwrite(STDERR,"Invalid INI: {$argv[1]}\n"); exit(1);}' "$f"; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.ini' -print0)
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/component/com_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/plugin/decaroforms.xml"

BUILDER="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
HELPER="$TMP/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
grep -q "public const VERSION = '1.3.8'" "$HELPER"
grep -q '<version>1.3.8</version>' "$TMP/component/com_decaroforms.xml"
grep -q '<version>1.3.8</version>' "$TMP/plugin/decaroforms.xml"
grep -q "savedPresetStorageKey='decaroforms_saved_field_presets_v1'" "$BUILDER"
grep -q 'data-act="save-preset"' "$BUILDER"
grep -q 'saveFieldPreset(x)' "$BUILDER"
grep -q 'df-lib-delete' "$BUILDER"
grep -q 'renderEmailPickers();' "$BUILDER"
grep -q 'templateDefs.slice(0,7).map' "$BUILDER"
grep -q 'background:#f6f7f9!important' "$BUILDER"

COMPZIP="$TMP/com_decaroforms_1.3.8.zip"
PLUGZIP="$TMP/plg_system_decaroforms_1.3.8.zip"
(cd "$TMP/component" && zip -qr "$COMPZIP" .)
(cd "$TMP/plugin" && zip -qr "$PLUGZIP" .)
rm -f "$TMP/outer/com_decaroforms_1.3.7.zip" "$TMP/outer/plg_system_decaroforms_1.3.7.zip"
cp "$COMPZIP" "$TMP/outer/com_decaroforms_1.3.8.zip"
cp "$PLUGZIP" "$TMP/outer/plg_system_decaroforms_1.3.8.zip"
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); t=p.read_text()
t=t.replace('<version>1.3.7</version>','<version>1.3.8</version>')
t=t.replace('plg_system_decaroforms_1.3.7.zip','plg_system_decaroforms_1.3.8.zip')
t=t.replace('com_decaroforms_1.3.7.zip','com_decaroforms_1.3.8.zip')
p.write_text(t)
PY
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/outer/pkg_decaroforms.xml"

TARGET="$OUTDIR/pkg_decaroforms_1.3.8.zip"
rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
SIZE="$(stat -c%s "$TARGET")"

cat > "$OUTDIR/README.md" <<EOF
# Forms 1.3.8

Migliorie Builder: campi personalizzati riutilizzabili, template email visibili e accordion light più leggero.

- Nuova icona Salva su ogni campo selezionato per memorizzare la configurazione come campo personalizzato riutilizzabile.
- I campi salvati compaiono in Libreria > Personalizzati e possono essere aggiunti ai moduli futuri.
- Possibilità di rimuovere un preset personalizzato salvato dalla Libreria.
- Ripristinata la visualizzazione dei 10 template email: 7 predefiniti + Personalizzato + HTML libero + AI.
- Il template Personalizzato può basarsi solo sui 7 template predefiniti.
- Accordion in light mode alleggeriti con sfondo #f6f7f9, hover neutro e stato aperto discreto.

Nota: i preset campo personalizzati vengono conservati nel browser dell'amministratore tramite localStorage.

SHA-256: $SHA
Dimensione: $SIZE byte
EOF
printf '%s  %s\n' "$SHA" "releases/1.3.8/pkg_decaroforms_1.3.8.zip" > "$OUTDIR/SHA256SUMS.txt"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.3.8</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.3.8/pkg_decaroforms_1.3.8.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF
cat > "$ROOT/updates/changelog.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>1.3.8</version>
<feature>Salvataggio dei campi configurati come preset personalizzati riutilizzabili.</feature>
<fix>Ripristinata la visualizzazione dei 10 template email nel Builder.</fix>
<change>Accordion light mode alleggeriti con sfondo #f6f7f9.</change>
<language>it-IT</language>
</changelog></changelogs>
EOF
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/pkg_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/changelog.xml"
echo "Built Forms 1.3.8: $SHA ($SIZE bytes)"
