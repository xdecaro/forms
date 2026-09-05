#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TOOL="$ROOT/tools/release-1.3.22"
BASE="$ROOT/releases/1.3.21/pkg_decaroforms_1.3.21.zip"
OUTDIR="$ROOT/releases/1.3.22"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/outer" "$TMP/component" "$TMP/plugin" "$OUTDIR"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.21.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.21.zip" -d "$TMP/plugin"
python3 "$TOOL/patch.py" "$TMP/component" "$TMP/plugin"

while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.php' -print0)
while IFS= read -r -d '' f; do php -r '$x=parse_ini_file($argv[1],false,INI_SCANNER_RAW); if($x===false){fwrite(STDERR,"Invalid INI: {$argv[1]}\n"); exit(1);}' "$f"; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.ini' -print0)
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/component/com_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/plugin/decaroforms.xml"

BUILDER="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
CTRL="$TMP/component/administrator/components/com_decaroforms/src/Controller/BuilderController.php"
HELPER="$TMP/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
grep -q "public const VERSION = '1.3.22'" "$HELPER"
grep -q '<version>1.3.22</version>' "$TMP/component/com_decaroforms.xml"
grep -q '<version>1.3.22</version>' "$TMP/plugin/decaroforms.xml"
grep -q "com_decaroforms.builder.csrf" "$CTRL"
grep -q 'hash_equals' "$CTRL"
grep -q "'builder_token' =>" "$CTRL"
grep -q 'name="df_builder_token"' "$BUILDER"
grep -q 'applyBuilderToken' "$BUILDER"
grep -q 'result.data.builder_token' "$BUILDER"

COMPZIP="$TMP/com_decaroforms_1.3.22.zip"
PLUGZIP="$TMP/plg_system_decaroforms_1.3.22.zip"
(cd "$TMP/component" && zip -qr "$COMPZIP" .)
(cd "$TMP/plugin" && zip -qr "$PLUGZIP" .)
rm -f "$TMP/outer/com_decaroforms_1.3.21.zip" "$TMP/outer/plg_system_decaroforms_1.3.21.zip"
cp "$COMPZIP" "$TMP/outer/com_decaroforms_1.3.22.zip"
cp "$PLUGZIP" "$TMP/outer/plg_system_decaroforms_1.3.22.zip"
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); t=p.read_text()
t=t.replace('<version>1.3.21</version>','<version>1.3.22</version>')
t=t.replace('plg_system_decaroforms_1.3.21.zip','plg_system_decaroforms_1.3.22.zip')
t=t.replace('com_decaroforms_1.3.21.zip','com_decaroforms_1.3.22.zip')
p.write_text(t)
PY
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/outer/pkg_decaroforms.xml"

TARGET="$OUTDIR/pkg_decaroforms_1.3.22.zip"
rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
SIZE="$(stat -c%s "$TARGET")"

cat > "$OUTDIR/README.md" <<EOF
# Forms 1.3.22

Correzione definitiva del salvataggio Builder su installazioni Joomla dove il token standard può risultare non valido anche dopo il refresh.

- Mantiene il token CSRF standard Joomla.
- Aggiunge un secondo nonce CSRF dedicato al Builder, generato con random_bytes, memorizzato nella sessione amministratore e verificato con hash_equals.
- Il salvataggio è accettato solo se è valido il token Joomla oppure il nonce Builder della stessa sessione autenticata e autorizzata.
- L'endpoint di refresh restituisce e aggiorna entrambi i token prima del POST.
- In caso di cambio sessione, entrambi i token vengono rinnovati e il salvataggio AJAX riprova una sola volta.
- La bozza locale continua a essere conservata fino a conferma di salvataggio riuscito.

SHA-256: $SHA
Dimensione: $SIZE byte
EOF
printf '%s  %s\n' "$SHA" "releases/1.3.22/pkg_decaroforms_1.3.22.zip" > "$OUTDIR/SHA256SUMS.txt"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.3.22</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.3.22/pkg_decaroforms_1.3.22.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF
cat > "$ROOT/updates/changelog.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>1.3.22</version>
<fix>Corretto il salvataggio del Builder quando il token Joomla standard continua a risultare non valido dopo il refresh.</fix>
<security>Aggiunto un nonce CSRF dedicato al Builder, casuale, legato alla sessione amministratore e verificato con hash_equals, mantenendo anche il controllo CSRF Joomla.</security>
<fix>L'endpoint di refresh aggiorna sia il token Joomla sia il nonce Builder prima del salvataggio.</fix>
<fix>La bozza locale viene mantenuta fino alla conferma del salvataggio riuscito.</fix>
<language>it-IT</language>
</changelog></changelogs>
EOF
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/pkg_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/changelog.xml"
python3 - "$ROOT/README.md" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); t=p.read_text()
t=re.sub(r'(## Current development version\n\n)\*\*[^*]+\*\*',r'\1**1.3.22**',t,1)
p.write_text(t)
PY

echo "Built Forms 1.3.22: $SHA ($SIZE bytes)"
