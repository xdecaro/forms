#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.25/pkg_decaroforms_1.3.25.zip"
OUTDIR="$ROOT/releases/1.3.26"
OUT="$OUTDIR/pkg_decaroforms_1.3.26.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component" "$TMP/system" "$TMP/editor" "$OUTDIR"

unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.25.zip" -d "$TMP/component"
unzip -q "$TMP/outer/plg_system_decaroforms_1.3.25.zip" -d "$TMP/system"
unzip -q "$TMP/outer/plg_editors-xtd_decaroforms_1.3.25.zip" -d "$TMP/editor"

python3 "$ROOT/tools/release-1.3.26/patch.py" "$TMP/component" "$TMP/system" "$TMP/editor"

python3 - "$TMP/outer/pkg_decaroforms.xml" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8')
s=s.replace('<version>1.3.25</version>','<version>1.3.26</version>')
s=s.replace('com_decaroforms_1.3.25.zip','com_decaroforms_1.3.26.zip')
s=s.replace('plg_system_decaroforms_1.3.25.zip','plg_system_decaroforms_1.3.26.zip')
s=s.replace('plg_editors-xtd_decaroforms_1.3.25.zip','plg_editors-xtd_decaroforms_1.3.26.zip')
p.write_text(s,encoding='utf-8')
PY

rm -f "$TMP/outer/com_decaroforms_1.3.25.zip" "$TMP/outer/plg_system_decaroforms_1.3.25.zip" "$TMP/outer/plg_editors-xtd_decaroforms_1.3.25.zip"
(
  cd "$TMP/component"
  zip -qr "$TMP/outer/com_decaroforms_1.3.26.zip" .
)
(
  cd "$TMP/system"
  zip -qr "$TMP/outer/plg_system_decaroforms_1.3.26.zip" .
)
(
  cd "$TMP/editor"
  zip -qr "$TMP/outer/plg_editors-xtd_decaroforms_1.3.26.zip" .
)
(
  cd "$TMP/outer"
  zip -qr "$OUT" .
)

B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
C="$TMP/component/administrator/components/com_decaroforms/src/Controller/BuilderController.php"
php -l "$B" >/dev/null
php -l "$C" >/dev/null
php -l "$TMP/component/script.php" >/dev/null
php -l "$TMP/editor/services/provider.php" >/dev/null
php -l "$TMP/editor/src/Extension/Forms.php" >/dev/null
python3 - "$TMP/outer/pkg_decaroforms.xml" "$TMP/component/com_decaroforms.xml" "$TMP/system/decaroforms.xml" "$TMP/editor/decaroforms.xml" <<'PY'
import sys,xml.etree.ElementTree as ET
for f in sys.argv[1:]:ET.parse(f)
PY

grep -q "window.dfBuilderRuntime={version:'1.3.26'" "$B"
grep -q 'sandbox="allow-scripts"' "$B"
grep -q 'function sanitizeEmailPreviewHtml' "$B"
grep -q 'sanitizeEmailPreviewHtml(emailPreviewHtml(audience,key))' "$B"
grep -q "querySelectorAll('script,object,embed')" "$B"
unzip -l "$OUT" | grep -q 'plg_editors-xtd_decaroforms_1.3.26.zip'

SHA="$(sha256sum "$OUT" | awk '{print $1}')"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.3.26</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.3.26/pkg_decaroforms_1.3.26.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>${SHA}</sha256>
</update></updates>
EOF

cat > "$ROOT/updates/changelog.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog>
<element>pkg_decaroforms</element><type>package</type><version>1.3.26</version>
<fix>Eliminati gli avvisi ripetuti della Console generati dalle miniature di anteprima email in iframe sandboxati.</fix>
<fix>Le anteprime email restano isolate in sandbox senza allow-same-origin, form, popup o navigazione.</fix>
<security>L'HTML delle miniature viene sanificato prima del caricamento: script, object, embed, handler JavaScript inline e URL javascript: vengono rimossi.</security>
<language>it-IT</language>
</changelog></changelogs>
EOF

python3 - "$ROOT/README.md" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8')
s=s.replace('**1.3.25**','**1.3.26**',1)
p.write_text(s,encoding='utf-8')
PY
python3 - "$ROOT/updates/pkg_decaroforms.xml" "$ROOT/updates/changelog.xml" <<'PY'
import sys,xml.etree.ElementTree as ET
for f in sys.argv[1:]:ET.parse(f)
PY

rm -rf "$ROOT/releases/_upload"
echo "FORMS_RELEASE_VERSION=1.3.26"
echo "FORMS_RELEASE_SHA256=$SHA"
echo "FORMS_RELEASE_PATH=releases/1.3.26/pkg_decaroforms_1.3.26.zip"
