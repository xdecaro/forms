#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TOOL="$ROOT/tools/release-1.3.23"
BASE="$ROOT/releases/1.3.22/pkg_decaroforms_1.3.22.zip"
OUTDIR="$ROOT/releases/1.3.23"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/outer" "$TMP/component" "$TMP/plugin" "$OUTDIR"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.22.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.22.zip" -d "$TMP/plugin"
python3 "$TOOL/patch.py" "$TMP/component" "$TMP/plugin"

while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.php' -print0)
while IFS= read -r -d '' f; do php -r '$x=parse_ini_file($argv[1],false,INI_SCANNER_RAW); if($x===false){fwrite(STDERR,"Invalid INI: {$argv[1]}\n"); exit(1);}' "$f"; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.ini' -print0)
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/component/com_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/plugin/decaroforms.xml"

BUILDER="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
HELPER="$TMP/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
grep -q "public const VERSION = '1.3.23'" "$HELPER"
grep -q '<version>1.3.23</version>' "$TMP/component/com_decaroforms.xml"
grep -q '<version>1.3.23</version>' "$TMP/plugin/decaroforms.xml"
grep -q 'Forms 1.3.23: single button system' "$BUILDER"
grep -q -- '--df-btn-bg:#fff' "$BUILDER"
grep -q -- '--df-btn-bg:#111827' "$BUILDER"
grep -q 'df-btn-primary df-save-structure' "$BUILDER"
! grep -q '.df-builder .df-btn:not(.df-primary),' "$BUILDER"

COMPZIP="$TMP/com_decaroforms_1.3.23.zip"
PLUGZIP="$TMP/plg_system_decaroforms_1.3.23.zip"
(cd "$TMP/component" && zip -qr "$COMPZIP" .)
(cd "$TMP/plugin" && zip -qr "$PLUGZIP" .)
rm -f "$TMP/outer/com_decaroforms_1.3.22.zip" "$TMP/outer/plg_system_decaroforms_1.3.22.zip"
cp "$COMPZIP" "$TMP/outer/com_decaroforms_1.3.23.zip"
cp "$PLUGZIP" "$TMP/outer/plg_system_decaroforms_1.3.23.zip"
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); t=p.read_text()
t=t.replace('<version>1.3.22</version>','<version>1.3.23</version>')
t=t.replace('plg_system_decaroforms_1.3.22.zip','plg_system_decaroforms_1.3.23.zip')
t=t.replace('com_decaroforms_1.3.22.zip','com_decaroforms_1.3.23.zip')
p.write_text(t)
PY
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/outer/pkg_decaroforms.xml"

TARGET="$OUTDIR/pkg_decaroforms_1.3.23.zip"
rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
SIZE="$(stat -c%s "$TARGET")"

cat > "$OUTDIR/README.md" <<EOF
# Forms 1.3.23

Pulizia e consolidamento del sistema colori dei pulsanti nel Builder.

- Rimossa la vecchia regola globale che ricolorava tutti i pulsanti secondari tramite variabili di tema e poteva renderli neri in light mode.
- Rimossi override duplicati per .df-btn, .df-primary, .df-danger e Salva struttura.
- Introdotto un solo sistema di pulsanti con variabili dedicate per light e dark mode.
- In light mode i pulsanti secondari sono bianchi/grigio chiaro con testo scuro; in dark mode usano superfici scure esplicite.
- Salva struttura è ora semanticamente un pulsante primario rosso Forms.
- Salva modulo e le azioni primarie restano rosse; le azioni distruttive mantengono uno stile dedicato.
- I pulsanti dentro le modal usano lo stesso sistema, evitando differenze di colore tra Builder e finestre di conferma.

SHA-256: $SHA
Dimensione: $SIZE byte
EOF
printf '%s  %s\n' "$SHA" "releases/1.3.23/pkg_decaroforms_1.3.23.zip" > "$OUTDIR/SHA256SUMS.txt"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.3.23</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.3.23/pkg_decaroforms_1.3.23.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF
cat > "$ROOT/updates/changelog.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>1.3.23</version>
<fix>Pulito il CSS dei pulsanti del Builder eliminando regole sovrapposte che potevano mostrare pulsanti neri in light mode.</fix>
<fix>Consolidati pulsanti secondari, primari, distruttivi e pulsanti delle modal in un unico sistema light/dark.</fix>
<fix>Salva struttura usa ora esplicitamente lo stile primario rosso Forms.</fix>
<language>it-IT</language>
</changelog></changelogs>
EOF
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/pkg_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/changelog.xml"
python3 - "$ROOT/README.md" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); t=p.read_text()
t=re.sub(r'(## Current development version\n\n)\*\*[^*]+\*\*',r'\1**1.3.23**',t,1)
p.write_text(t)
PY

echo "Built Forms 1.3.23: $SHA ($SIZE bytes)"
