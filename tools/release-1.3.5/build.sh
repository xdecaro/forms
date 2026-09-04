#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TOOL="$ROOT/tools/release-1.3.5"
BASE="$ROOT/releases/1.3.4/pkg_decaroforms_1.3.4.zip"
OUTDIR="$ROOT/releases/1.3.5"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -f "$BASE" ] || { echo "Missing base package: $BASE" >&2; exit 1; }
mkdir -p "$TMP/outer" "$TMP/component" "$TMP/plugin" "$OUTDIR"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.4.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.4.zip" -d "$TMP/plugin"
python3 "$TOOL/patch.py" "$TMP/component" "$TMP/plugin"

while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.php' -print0)
while IFS= read -r -d '' f; do php -r '$x=parse_ini_file($argv[1],false,INI_SCANNER_RAW); if($x===false){fwrite(STDERR,"Invalid INI: {$argv[1]}\n"); exit(1);}' "$f"; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.ini' -print0)
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/component/com_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/plugin/decaroforms.xml"

BUILDER="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
HELPER="$TMP/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
grep -q "public const VERSION = '1.3.5'" "$HELPER"
grep -q '<version>1.3.5</version>' "$TMP/component/com_decaroforms.xml"
grep -q '<version>1.3.5</version>' "$TMP/plugin/decaroforms.xml"
grep -q 'Forms 1.3.5 dark-mode surfaces' "$BUILDER"
grep -q -- '--df-theme-surface:#1f2937' "$BUILDER"
grep -q -- '--df-close-bg:rgba(230,0,70,.14)' "$BUILDER"
grep -q 'df-custom-code-grid .df-note' "$BUILDER"
if grep -Fq "if(window.matchMedia('(max-width:800px)').matches&&open){accordionSections.forEach" "$BUILDER"; then echo 'Accordion auto-close still present' >&2; exit 1; fi
if grep -Fq "if(window.matchMedia('(max-width:800px)').matches){sections.forEach" "$BUILDER"; then echo 'Quick accordion auto-close still present' >&2; exit 1; fi

COMPZIP="$TMP/com_decaroforms_1.3.5.zip"
PLUGZIP="$TMP/plg_system_decaroforms_1.3.5.zip"
(cd "$TMP/component" && zip -qr "$COMPZIP" .)
(cd "$TMP/plugin" && zip -qr "$PLUGZIP" .)
rm -f "$TMP/outer/com_decaroforms_1.3.4.zip" "$TMP/outer/plg_system_decaroforms_1.3.4.zip"
cp "$COMPZIP" "$TMP/outer/com_decaroforms_1.3.5.zip"
cp "$PLUGZIP" "$TMP/outer/plg_system_decaroforms_1.3.5.zip"
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); t=p.read_text()
t=t.replace('<version>1.3.4</version>','<version>1.3.5</version>')
t=t.replace('plg_system_decaroforms_1.3.4.zip','plg_system_decaroforms_1.3.5.zip')
t=t.replace('com_decaroforms_1.3.4.zip','com_decaroforms_1.3.5.zip')
p.write_text(t)
PY
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/outer/pkg_decaroforms.xml"

TARGET="$OUTDIR/pkg_decaroforms_1.3.5.zip"
rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
SIZE="$(stat -c%s "$TARGET")"

cat > "$OUTDIR/README.md" <<EOF
# Forms 1.3.5

Correzioni Builder e dark mode.

- Accordion indipendenti anche su smartphone: aprire una sezione non chiude le altre.
- Dark mode corretto per Gestione invii, Email, Validazione e conferma e relativi controlli interni.
- Blocco Quando disattivato reso coerente con il dark mode tramite evidenza rosso scuro trasparente.
- Corretta la leggibilità di colonne, stati, intestazioni email e testi secondari in dark mode.
- Aggiunto padding sinistro alla nota sotto gli editor CSS/JavaScript personalizzati.

SHA-256: $SHA
Dimensione: $SIZE byte
EOF
printf '%s  %s\n' "$SHA" "releases/1.3.5/pkg_decaroforms_1.3.5.zip" > "$OUTDIR/SHA256SUMS.txt"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.3.5</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.3.5/pkg_decaroforms_1.3.5.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF
cat > "$ROOT/updates/changelog.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>1.3.5</version>
<fix>Accordion indipendenti anche su smartphone.</fix>
<fix>Dark mode corretto per Gestione invii, Email e Validazione e conferma.</fix>
<fix>Blocco di chiusura del modulo adattato al dark mode.</fix>
<change>Aggiunto padding alla nota degli editor CSS e JavaScript personalizzati.</change>
<language>it-IT</language>
</changelog></changelogs>
EOF
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/pkg_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/changelog.xml"
echo "Built Forms 1.3.5: $SHA ($SIZE bytes)"
