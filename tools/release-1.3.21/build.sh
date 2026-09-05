#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TOOL="$ROOT/tools/release-1.3.21"
BASE="$ROOT/releases/1.3.20/pkg_decaroforms_1.3.20.zip"
OUTDIR="$ROOT/releases/1.3.21"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/outer" "$TMP/component" "$TMP/plugin" "$OUTDIR"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.20.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.20.zip" -d "$TMP/plugin"
python3 "$TOOL/patch.py" "$TMP/component" "$TMP/plugin"

while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.php' -print0)
while IFS= read -r -d '' f; do php -r '$x=parse_ini_file($argv[1],false,INI_SCANNER_RAW); if($x===false){fwrite(STDERR,"Invalid INI: {$argv[1]}\n"); exit(1);}' "$f"; done < <(find "$TMP/component" "$TMP/plugin" -type f -name '*.ini' -print0)
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/component/com_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/plugin/decaroforms.xml"

BUILDER="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
CTRL="$TMP/component/administrator/components/com_decaroforms/src/Controller/BuilderController.php"
HELPER="$TMP/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
grep -q "public const VERSION = '1.3.21'" "$HELPER"
grep -q '<version>1.3.21</version>' "$TMP/component/com_decaroforms.xml"
grep -q '<version>1.3.21</version>' "$TMP/plugin/decaroforms.xml"
grep -q 'public function token(): void' "$CTRL"
grep -q "'code' => 'invalid_token'" "$CTRL"
grep -q 'df-csrf-token-wrap' "$BUILDER"
grep -q 'window.DeCaroFormsBuilderSubmit' "$BUILDER"
grep -q 'builder.token&format=json' "$BUILDER"
grep -q 'window.dfBuilderSaveDraft=saveDraftNow' "$BUILDER"
! grep -q "getElementById('df-builder-form').addEventListener('submit'" "$BUILDER"

COMPZIP="$TMP/com_decaroforms_1.3.21.zip"
PLUGZIP="$TMP/plg_system_decaroforms_1.3.21.zip"
(cd "$TMP/component" && zip -qr "$COMPZIP" .)
(cd "$TMP/plugin" && zip -qr "$PLUGZIP" .)
rm -f "$TMP/outer/com_decaroforms_1.3.20.zip" "$TMP/outer/plg_system_decaroforms_1.3.20.zip"
cp "$COMPZIP" "$TMP/outer/com_decaroforms_1.3.21.zip"
cp "$PLUGZIP" "$TMP/outer/plg_system_decaroforms_1.3.21.zip"
python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); t=p.read_text()
t=t.replace('<version>1.3.20</version>','<version>1.3.21</version>')
t=t.replace('plg_system_decaroforms_1.3.20.zip','plg_system_decaroforms_1.3.21.zip')
t=t.replace('com_decaroforms_1.3.20.zip','com_decaroforms_1.3.21.zip')
p.write_text(t)
PY
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$TMP/outer/pkg_decaroforms.xml"

TARGET="$OUTDIR/pkg_decaroforms_1.3.21.zip"
rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
SIZE="$(stat -c%s "$TARGET")"

cat > "$OUTDIR/README.md" <<EOF
# Forms 1.3.21

Correzione prioritaria del salvataggio Builder e del token Joomla.

- Prima di ogni salvataggio il Builder richiede il token CSRF corrente alla sessione Joomla e aggiorna il campo nascosto.
- Se il token cambia tra verifica e POST, il salvataggio AJAX aggiorna il token e riprova una sola volta.
- Il gestore di Salva è separato dal resto del JavaScript del Builder: un errore in drag & drop, email o UI non può più causare un POST nativo verso una pagina 403.
- Il fallback server non mostra più la pagina Joomla 403 per token non valido: torna al Builder con messaggio e la bozza locale resta recuperabile.
- La bozza viene salvata prima del tentativo e cancellata solo dopo risposta positiva del server.

SHA-256: $SHA
Dimensione: $SIZE byte
EOF
printf '%s  %s\n' "$SHA" "releases/1.3.21/pkg_decaroforms_1.3.21.zip" > "$OUTDIR/SHA256SUMS.txt"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.3.21</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.3.21/pkg_decaroforms_1.3.21.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF
cat > "$ROOT/updates/changelog.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>1.3.21</version>
<fix>Corretto il salvataggio del Builder quando il token Joomla cambia o scade.</fix>
<security>Il controllo CSRF resta attivo; il Builder recupera il token corrente prima del POST e può riprovare una sola volta in caso di rotazione del token.</security>
<fix>Il salvataggio è ora intercettato da un handler indipendente dal resto del JavaScript del Builder, evitando POST nativi e pagine 403 grezze.</fix>
<fix>Il fallback server torna al Builder con un messaggio e mantiene disponibile la bozza locale.</fix>
<language>it-IT</language>
</changelog></changelogs>
EOF
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/pkg_decaroforms.xml"
php -r '$x=simplexml_load_file($argv[1]); if(!$x) exit(1);' "$ROOT/updates/changelog.xml"
python3 - "$ROOT/README.md" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); t=p.read_text()
t=re.sub(r'(## Current development version\n\n)\*\*[^*]+\*\*',r'\1**1.3.21**',t,1)
p.write_text(t)
PY

echo "Built Forms 1.3.21: $SHA ($SIZE bytes)"
