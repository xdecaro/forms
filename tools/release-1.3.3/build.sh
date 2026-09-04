#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TOOL="$ROOT/tools/release-1.3.3"
BASE="$ROOT/releases/1.3.2/pkg_decaroforms_1.3.2.zip"
OUTDIR="$ROOT/releases/1.3.3"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

[ -f "$BASE" ] || { echo "Missing base package: $BASE" >&2; exit 1; }
mkdir -p "$TMP/outer" "$TMP/component" "$TMP/plugin" "$OUTDIR"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.2.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.2.zip" -d "$TMP/plugin"
python3 "$TOOL/patch.py" "$TMP/component" "$TMP/plugin"

while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.php' -print0)
while IFS= read -r -d '' f; do php -r '$x=parse_ini_file($argv[1],false,INI_SCANNER_RAW); if($x===false){fwrite(STDERR,"Invalid INI: {$argv[1]}\n"); exit(1);}' "$f"; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.ini' -print0)
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/component/com_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/plugin/decaroforms.xml"

BUILDER="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
HELPER="$TMP/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
grep -q "public const VERSION = '1.3.3'" "$HELPER"
grep -q '<version>1.3.3</version>' "$TMP/component/com_decaroforms.xml"
grep -q '<version>1.3.3</version>' "$TMP/plugin/decaroforms.xml"
grep -Fq 'split(/\r?\n/)' "$BUILDER"
grep -q 'const accordionSections=' "$BUILDER"
grep -q 'Forms 1.3.3 interaction hotfix' "$BUILDER"

python3 - "$BUILDER" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text()
# The 1.3.2 regression was a JavaScript regex literal broken by a physical newline.
if re.search(r"split\(/\\r\?\\\s*\n/\)", s):
    raise SystemExit('Broken multiline option split regex still present')
if s.count("split(/\\r?\\n/)") < 1:
    raise SystemExit('Valid option split regex missing')
if 'const accordionSections=' not in s:
    raise SystemExit('Accordion hotfix missing')
print('Forms 1.3.3 regression checks OK')
PY

COMPZIP="$TMP/com_decaroforms_1.3.3.zip"
PLUGZIP="$TMP/plg_system_decaroforms_1.3.3.zip"
(cd "$TMP/component" && zip -qr "$COMPZIP" .)
(cd "$TMP/plugin" && zip -qr "$PLUGZIP" .)
rm -f "$TMP/outer/com_decaroforms_1.3.2.zip" "$TMP/outer/plg_system_decaroforms_1.3.2.zip"
cp "$COMPZIP" "$TMP/outer/com_decaroforms_1.3.3.zip"
cp "$PLUGZIP" "$TMP/outer/plg_system_decaroforms_1.3.3.zip"
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); t=p.read_text()
t=t.replace('<version>1.3.2</version>','<version>1.3.3</version>')
t=t.replace('plg_system_decaroforms_1.3.2.zip','plg_system_decaroforms_1.3.3.zip')
t=t.replace('com_decaroforms_1.3.2.zip','com_decaroforms_1.3.3.zip')
p.write_text(t)
PY
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/outer/pkg_decaroforms.xml"

TARGET="$OUTDIR/pkg_decaroforms_1.3.3.zip"
rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
SIZE="$(stat -c%s "$TARGET")"

cat > "$OUTDIR/README.md" <<EOF
# Forms 1.3.3

Hotfix del Builder dopo Forms 1.3.2.

- Corretto il JavaScript che bloccava i comandi del Builder e gli accordion.
- Gli accordion principali partono con Impostazioni modulo aperto e le altre sezioni chiuse; ogni sezione torna cliccabile in modo indipendente.
- Rimosso l'hover rosa/rosso personalizzato dalle intestazioni: torna il comportamento neutro coerente con Joomla.
- Il blocco Quando disattivato / Messaggio di chiusura usa ora un rosso molto chiaro con bordo discreto invece del fondo rosso pieno.

SHA-256: $SHA
Dimensione: $SIZE byte
EOF
printf '%s  %s\n' "$SHA" "releases/1.3.3/pkg_decaroforms_1.3.3.zip" > "$OUTDIR/SHA256SUMS.txt"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.3.3</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.3.3/pkg_decaroforms_1.3.3.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF
cat > "$ROOT/updates/changelog.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>1.3.3</version>
<fix>Corretto il JavaScript che poteva bloccare il Builder e impedire l'apertura/chiusura degli accordion.</fix>
<fix>Ripristinato hover neutro coerente con Joomla per le intestazioni del Builder.</fix>
<change>Il blocco di chiusura del modulo usa un'evidenza rossa chiara e discreta.</change>
<language>it-IT</language>
</changelog></changelogs>
EOF
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/pkg_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/changelog.xml"
echo "Built Forms 1.3.3: $SHA ($SIZE bytes)"
