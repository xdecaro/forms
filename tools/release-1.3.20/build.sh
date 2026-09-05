#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TOOL="$ROOT/tools/release-1.3.20"
BASE="$ROOT/releases/1.3.19/pkg_decaroforms_1.3.19.zip"
OUTDIR="$ROOT/releases/1.3.20"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/outer" "$TMP/component" "$TMP/plugin" "$OUTDIR"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.19.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.19.zip" -d "$TMP/plugin"
python3 "$TOOL/patch.py" "$TMP/component" "$TMP/plugin"

while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.php' -print0)
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/component/com_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/plugin/decaroforms.xml"

BUILDER="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
HELPER="$TMP/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
grep -q "public const VERSION = '1.3.20'" "$HELPER"
grep -q '<version>1.3.20</version>' "$TMP/component/com_decaroforms.xml"
grep -q '<version>1.3.20</version>' "$TMP/plugin/decaroforms.xml"
grep -q 'df-custom-code-grid{display:grid;grid-template-columns:1fr;gap:12px}' "$BUILDER"
grep -q 'df-custom-code-grid .df-codearea{width:100%;max-width:none;box-sizing:border-box}' "$BUILDER"
python3 - "$BUILDER" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text()
footer=s.index('<?php echo FormHelper::footer(); ?>')
close=s.rfind('</div>',0,footer)
if close < 0 or close > footer:
    raise SystemExit('footer placement validation failed')
PY

COMPZIP="$TMP/com_decaroforms_1.3.20.zip"
PLUGZIP="$TMP/plg_system_decaroforms_1.3.20.zip"
(cd "$TMP/component" && zip -qr "$COMPZIP" .)
(cd "$TMP/plugin" && zip -qr "$PLUGZIP" .)
rm -f "$TMP/outer/com_decaroforms_1.3.19.zip" "$TMP/outer/plg_system_decaroforms_1.3.19.zip"
cp "$COMPZIP" "$TMP/outer/com_decaroforms_1.3.20.zip"
cp "$PLUGZIP" "$TMP/outer/plg_system_decaroforms_1.3.20.zip"
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); t=p.read_text()
t=t.replace('<version>1.3.19</version>','<version>1.3.20</version>')
t=t.replace('plg_system_decaroforms_1.3.19.zip','plg_system_decaroforms_1.3.20.zip')
t=t.replace('com_decaroforms_1.3.19.zip','com_decaroforms_1.3.20.zip')
p.write_text(t)
PY

TARGET="$OUTDIR/pkg_decaroforms_1.3.20.zip"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
SIZE="$(stat -c%s "$TARGET")"

cat > "$OUTDIR/README.md" <<EOF
# Forms 1.3.20

Correzioni layout del Builder.

- CSS personalizzato ora occupa il 100% della larghezza disponibile.
- Anche JavaScript personalizzato viene disposto su una riga separata a larghezza piena.
- Il footer “© 2026 Forms · Sviluppato da Luca De Caro · Versione 1.3.20” è stato spostato fuori dal Builder/form e resta in fondo alla pagina.
- Footer reso esplicitamente full-width e separato dal contenuto con bordo superiore.

SHA-256: $SHA
Dimensione: $SIZE byte
EOF
printf '%s  %s\n' "$SHA" "releases/1.3.20/pkg_decaroforms_1.3.20.zip" > "$OUTDIR/SHA256SUMS.txt"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.3.20</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.3.20/pkg_decaroforms_1.3.20.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF
cat > "$ROOT/updates/changelog.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>1.3.20</version>
<fix>CSS e JavaScript personalizzati ora usano tutta la larghezza disponibile nel Builder.</fix>
<fix>Il footer del componente è stato spostato fuori dal contenuto del Builder e posizionato a fondo pagina.</fix>
<language>it-IT</language>
</changelog></changelogs>
EOF
python3 - "$ROOT/README.md" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); t=p.read_text()
t=re.sub(r'(## Current development version\n\n)\*\*[^*]+\*\*',r'\1**1.3.20**',t,1)
p.write_text(t)
PY

echo "Built Forms 1.3.20: $SHA ($SIZE bytes)"
