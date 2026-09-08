#!/usr/bin/env bash
set -Eeuo pipefail
trap 'status=$?; echo "Build failed at line ${LINENO}: ${BASH_COMMAND}" >&2; exit "$status"' ERR

BASE_VERSION="1.4.2"
NEW_VERSION="1.5.0"
RELEASE_DATE="2026-09-08"
MINIMUM_CORE_UI="1.1.0"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASE_ZIP="$ROOT/releases/$BASE_VERSION/pkg_decaroforms_$BASE_VERSION.zip"
OUT="$ROOT/releases/$NEW_VERSION"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

[[ -f "$BASE_ZIP" ]] || { echo "Base package not found: $BASE_ZIP" >&2; exit 1; }

rm -rf "$OUT"
mkdir -p "$OUT" "$WORK/outer" "$WORK/component-old" "$WORK/component" "$WORK/system-old" "$WORK/system" "$WORK/editor-old" "$WORK/editor"
unzip -q "$BASE_ZIP" -d "$WORK/outer"
unzip -q "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" -d "$WORK/component-old"
unzip -q "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" -d "$WORK/component"
unzip -q "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" -d "$WORK/system-old"
unzip -q "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" -d "$WORK/system"
unzip -q "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip" -d "$WORK/editor-old"
unzip -q "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip" -d "$WORK/editor"

VIEW="$WORK/component/administrator/components/com_decaroforms/src/View/Information/HtmlView.php"
DEFAULT_TPL="$WORK/component/administrator/components/com_decaroforms/tmpl/information/default.php"
CORE_TPL="$WORK/component/administrator/components/com_decaroforms/tmpl/information/core.php"
BRIDGE="$WORK/component/media/css/core-bridge.css"
HELPER="$WORK/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"

for file in "$VIEW" "$DEFAULT_TPL" "$HELPER"; do
  [[ -f "$file" ]] || { echo "Required Forms Information source missing: $file" >&2; exit 1; }
done

# The 1.4.2 Information layout remains byte-identical and is the fallback.
cp "$DEFAULT_TPL" "$CORE_TPL"

python3 - "$CORE_TPL" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')
old = '<div class="dfi-page">'
new = '<div class="dfi-page xdecaro-scope forms-core-scope">'
if s.count(old) != 1:
    raise SystemExit('Forms Information root marker not found exactly once')
s = s.replace(old, new, 1)
# Dual classes consume Core primitives while dfi-* remains the compatibility layer.
s = s.replace('class="dfi-card ', 'class="dfi-card xdecaro-card ')
s = s.replace('class="dfi-card"', 'class="dfi-card xdecaro-card"')
s = s.replace('class="dfi-summary"', 'class="dfi-summary xdecaro-card"')
s = s.replace('class="dfi-badge ', 'class="dfi-badge xdecaro-badge ')
s = s.replace('class="dfi-badge"', 'class="dfi-badge xdecaro-badge"')
s = s.replace('class="btn btn-primary"', 'class="btn btn-primary xdecaro-button xdecaro-button--primary"')
s = s.replace('class="btn btn-secondary"', 'class="btn btn-secondary xdecaro-button"')
s = s.replace('class="btn btn-outline-secondary"', 'class="btn btn-outline-secondary xdecaro-button"')
if 'forms-core-scope' not in s or 'xdecaro-card' not in s or 'xdecaro-badge' not in s:
    raise SystemExit('Core UI dual-class transformation did not apply')
p.write_text(s, encoding='utf-8')
PY

cat > "$BRIDGE" <<'CSS'
/* Forms 1.5.0 - optional bridge to Core by xdecaro 1.1+ design tokens. */
.forms-core-scope.dfi-page {
    --dfi-text: var(--xdecaro-color-text, #172033);
    --dfi-muted: var(--xdecaro-color-muted, #667085);
    --dfi-border: var(--xdecaro-color-border, #e2e7ee);
    --dfi-surface: var(--xdecaro-color-surface, #ffffff);
    --dfi-surface-soft: var(--xdecaro-color-surface-subtle, #f8fafc);
    --dfi-primary: var(--xdecaro-color-primary, #1358d0);
    --dfi-success: var(--xdecaro-color-success, #137a4f);
    --dfi-success-soft: var(--xdecaro-color-success-soft, #eaf8f1);
    --dfi-warning: var(--xdecaro-color-warning, #9a6200);
    --dfi-warning-soft: var(--xdecaro-color-warning-soft, #fff4d6);
    --dfi-danger: var(--xdecaro-color-danger, #b42318);
    --dfi-danger-soft: var(--xdecaro-color-danger-soft, #fff0ef);
    --dfi-neutral: var(--xdecaro-color-muted, #5e6978);
    --dfi-neutral-soft: var(--xdecaro-color-surface-subtle, #eef1f5);
    font-family: var(--xdecaro-font-family, inherit);
}

.forms-core-scope .dfi-card.xdecaro-card,
.forms-core-scope .dfi-summary.xdecaro-card {
    border-color: var(--xdecaro-color-border, var(--dfi-border));
    border-radius: var(--xdecaro-radius-lg, 12px);
    box-shadow: var(--xdecaro-shadow-sm, 0 2px 8px rgba(15, 23, 42, .025));
}

.forms-core-scope .dfi-actions .xdecaro-button {
    border-radius: var(--xdecaro-radius-md, 8px);
}

.forms-core-scope .dfi-page-header h1,
.forms-core-scope .dfi-card-head h2,
.forms-core-scope .dfi-diagnostic-top h2 {
    color: var(--xdecaro-color-text, var(--dfi-text));
}
CSS

if grep -Fq '!important' "$BRIDGE"; then
  echo "core-bridge.css must not use !important" >&2
  exit 1
fi

python3 - "$VIEW" "$NEW_VERSION" "$MINIMUM_CORE_UI" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1]); version = sys.argv[2]; minimum_core = sys.argv[3]
s = p.read_text(encoding='utf-8')
needle = """    public array $info = [];
    public bool $canManageInstaller = false;
"""
replacement = f"""    private const MINIMUM_CORE_UI_VERSION = '{minimum_core}';

    public array $info = [];
    public bool $canManageInstaller = false;
    public bool $coreUiEnabled = false;
"""
if s.count(needle) != 1:
    raise SystemExit('Information view property marker not found exactly once')
s = s.replace(needle, replacement, 1)
# Existing local Information assets stay present; only their cache version changes.
s, n = re.subn(r"('version'\s*=>\s*)'[^']+'", rf"\g<1>'{version}'", s)
if n < 2:
    raise SystemExit('Unable to update Information local asset versions')
needle = """        $document = $app->getDocument();
        $wa = $document->getWebAssetManager();

"""
replacement = f"""        $document = $app->getDocument();
        $wa = $document->getWebAssetManager();

        $coreVersion = class_exists(\\Xdecaro\\Core\\Version::class)
            ? trim((string) \\Xdecaro\\Core\\Version::VERSION)
            : '';

        if (
            $coreVersion !== ''
            && version_compare($coreVersion, self::MINIMUM_CORE_UI_VERSION, '>=')
            && class_exists(\\Xdecaro\\Core\\Asset\\AssetService::class)
        ) {{
            try {{
                $coreAssets = new \\Xdecaro\\Core\\Asset\\AssetService();
                $this->coreUiEnabled = $coreAssets->useComponents($wa);
            }} catch (\\Throwable) {{
                $this->coreUiEnabled = false;
            }}
        }}

        if ($this->coreUiEnabled) {{
            if (!$wa->assetExists('style', 'com_decaroforms.core-bridge')) {{
                $wa->registerStyle(
                    'com_decaroforms.core-bridge',
                    'com_decaroforms/core-bridge.css',
                    ['version' => '{version}']
                );
            }}
            $wa->useStyle('com_decaroforms.core-bridge');
            $this->setLayout('core');
        }}

"""
if s.count(needle) != 1:
    raise SystemExit('Information WAM marker not found exactly once')
s = s.replace(needle, replacement, 1)
p.write_text(s, encoding='utf-8')
PY

python3 - "$HELPER" "$NEW_VERSION" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1]); version = sys.argv[2]
s = p.read_text(encoding='utf-8')
s, n = re.subn(r"public const VERSION\s*=\s*'[^']+';", f"public const VERSION = '{version}';", s, count=1)
if n != 1: raise SystemExit('Unable to update FormHelper::VERSION')
p.write_text(s, encoding='utf-8')
PY

python3 - "$WORK/component/com_decaroforms.xml" "$WORK/system/decaroforms.xml" "$WORK/editor/decaroforms.xml" "$NEW_VERSION" "$RELEASE_DATE" <<'PY'
from pathlib import Path
import re, sys
version, release_date = sys.argv[4], sys.argv[5]
for filename in sys.argv[1:4]:
    p = Path(filename); s = p.read_text(encoding='utf-8')
    s, n = re.subn(r'<version>[^<]+</version>', f'<version>{version}</version>', s, count=1)
    if n != 1: raise SystemExit(f'Version not found in {filename}')
    s = re.sub(r'<creationDate>[^<]+</creationDate>', f'<creationDate>{release_date}</creationDate>', s, count=1)
    p.write_text(s, encoding='utf-8')
PY

# Regression guard: no Forms product behavior outside Information may change.
python3 - "$WORK/component-old" "$WORK/component" "$WORK/system-old" "$WORK/system" "$WORK/editor-old" "$WORK/editor" <<'PY'
from pathlib import Path
import hashlib, sys

def hashes(root):
    root = Path(root)
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest() for p in root.rglob('*') if p.is_file()}
old, new = hashes(sys.argv[1]), hashes(sys.argv[2])
allowed_changed = {
    'com_decaroforms.xml',
    'administrator/components/com_decaroforms/src/Helper/FormHelper.php',
    'administrator/components/com_decaroforms/src/View/Information/HtmlView.php',
}
allowed_added = {
    'administrator/components/com_decaroforms/tmpl/information/core.php',
    'media/css/core-bridge.css',
}
for path in sorted(set(old) | set(new)):
    if old.get(path) == new.get(path): continue
    if path in allowed_changed and old.get(path) is not None and new.get(path) is not None: continue
    if path in allowed_added and old.get(path) is None and new.get(path) is not None: continue
    raise SystemExit('Unexpected component regression: ' + path)
fallback = 'administrator/components/com_decaroforms/tmpl/information/default.php'
if old.get(fallback) != new.get(fallback):
    raise SystemExit('Default Information fallback layout changed unexpectedly')
for old_root, new_root in ((sys.argv[3], sys.argv[4]), (sys.argv[5], sys.argv[6])):
    oh, nh = hashes(old_root), hashes(new_root)
    changed = {p for p in set(oh) | set(nh) if oh.get(p) != nh.get(p)}
    if changed != {'decaroforms.xml'}:
        raise SystemExit('Unexpected plugin regressions: ' + ', '.join(sorted(changed)))
PY

php -l "$VIEW" >/dev/null
php -l "$CORE_TPL" >/dev/null
php -l "$DEFAULT_TPL" >/dev/null
php -l "$HELPER" >/dev/null
python3 - "$WORK/component/com_decaroforms.xml" "$WORK/system/decaroforms.xml" "$WORK/editor/decaroforms.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
for p in sys.argv[1:]: ET.parse(p)
PY

grep -Fq "MINIMUM_CORE_UI_VERSION = '$MINIMUM_CORE_UI'" "$VIEW"
grep -Fq 'Xdecaro\Core\Asset\AssetService' "$VIEW"
grep -Fq 'useComponents($wa)' "$VIEW"
grep -Fq "setLayout('core')" "$VIEW"
grep -Fq 'forms-core-scope' "$CORE_TPL"
grep -Fq 'xdecaro-card' "$CORE_TPL"
grep -Fq 'xdecaro-badge' "$CORE_TPL"
grep -Fq -- '--dfi-text: var(--xdecaro-color-text' "$BRIDGE"

rm -f "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip"
(cd "$WORK/component" && zip -qr "$WORK/outer/com_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')
(cd "$WORK/system" && zip -qr "$WORK/outer/plg_system_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')
(cd "$WORK/editor" && zip -qr "$WORK/outer/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')

python3 - "$WORK/outer/pkg_decaroforms.xml" "$BASE_VERSION" "$NEW_VERSION" "$RELEASE_DATE" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1]); base, new, release_date = sys.argv[2:5]
s = p.read_text(encoding='utf-8')
s, n = re.subn(r'<version>[^<]+</version>', f'<version>{new}</version>', s, count=1)
if n != 1: raise SystemExit('Package version not found')
s = re.sub(r'<creationDate>[^<]+</creationDate>', f'<creationDate>{release_date}</creationDate>', s, count=1)
for stem in ('com_decaroforms', 'plg_system_decaroforms', 'plg_editors-xtd_decaroforms'):
    old = f'{stem}_{base}.zip'; target = f'{stem}_{new}.zip'
    if s.count(old) != 1: raise SystemExit(f'Nested package filename marker not found exactly once: {old}')
    s = s.replace(old, target, 1)
p.write_text(s, encoding='utf-8')
PY
python3 - "$WORK/outer/pkg_decaroforms.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
ET.parse(sys.argv[1])
PY

(cd "$WORK/outer" && zip -qr "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store' '*.log' '*.tmp')
cp "$WORK/outer/com_decaroforms_${NEW_VERSION}.zip" "$OUT/com_decaroforms_${NEW_VERSION}.zip"
cp "$WORK/outer/plg_system_decaroforms_${NEW_VERSION}.zip" "$OUT/plg_system_decaroforms_${NEW_VERSION}.zip"
cp "$WORK/outer/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip" "$OUT/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip"
cp "$WORK/outer/pkg_decaroforms.xml" "$OUT/pkg_decaroforms.xml"

SHA256="$(sha256sum "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | awk '{print $1}')"
printf '%s  %s\n' "$SHA256" "pkg_decaroforms_${NEW_VERSION}.zip" > "$OUT/SHA256SUMS.txt"
cat > "$OUT/README.md" <<EOF
# Forms $NEW_VERSION

Prima adozione reale e controllata del design system di **Core by xdecaro**.

- la pagina Informazioni/Diagnostica usa Core UI solo con Core >= $MINIMUM_CORE_UI;
- caricamento tramite \`Xdecaro\\Core\\Asset\\AssetService\` e Joomla Web Asset Manager;
- nuovo layout isolato \`core.php\` con \`.xdecaro-scope\` e primitive condivise;
- bridge locale dei token \`--dfi-*\` verso \`--xdecaro-*\`;
- il layout 1.4.2 originale resta invariato come fallback automatico;
- nessuna modifica a Builder, campi, invii, email, import/export, pagamenti o database.

SHA-256 pacchetto: \`$SHA256\`
EOF

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update><name>Forms by xdecaro</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description><element>pkg_decaroforms</element><type>package</type><client>site</client><version>$NEW_VERSION</version><downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/$NEW_VERSION/pkg_decaroforms_$NEW_VERSION.zip</downloadurl></downloads><changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags><maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl><targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA256</sha256></update></updates>
EOF

python3 - "$ROOT/updates/changelog.xml" "$NEW_VERSION" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]); version = sys.argv[2]
s = p.read_text(encoding='utf-8')
if f'<version>{version}</version>' not in s:
    entry = ("\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n"
             f"\t\t<version>{version}</version>\n"
             "\t\t<note>Prima adozione controllata del design system Core by xdecaro nella sola pagina Informazioni/Diagnostica. Core 1.1+ viene caricato via AssetService/WAM e layout scoped dedicato; il layout locale 1.4.2 resta fallback automatico. Builder, campi, invii, email, import/export e database invariati.</note>\n\t</changelog>\n")
    s = s.replace('<changelogs>\n', '<changelogs>\n' + entry, 1)
    p.write_text(s, encoding='utf-8')
PY

python3 - "$ROOT/README.md" "$BASE_VERSION" "$NEW_VERSION" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]); base, new = sys.argv[2:4]
s = p.read_text(encoding='utf-8')
marker = f'**{base}**'
if s.count(marker) != 1: raise SystemExit('README current-version marker not found exactly once')
s = s.replace(marker, f'**{new}**', 1)
p.write_text(s, encoding='utf-8')
PY

unzip -t "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" >/dev/null
unzip -l "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | grep -Fq "com_decaroforms_${NEW_VERSION}.zip"
unzip -l "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | grep -Fq "plg_system_decaroforms_${NEW_VERSION}.zip"
unzip -l "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | grep -Fq "plg_editors-xtd_decaroforms_${NEW_VERSION}.zip"
unzip -l "$OUT/com_decaroforms_${NEW_VERSION}.zip" | grep -Fq 'administrator/components/com_decaroforms/tmpl/information/core.php'
unzip -l "$OUT/com_decaroforms_${NEW_VERSION}.zip" | grep -Fq 'media/css/core-bridge.css'
unzip -p "$OUT/com_decaroforms_${NEW_VERSION}.zip" administrator/components/com_decaroforms/src/View/Information/HtmlView.php | grep -Fq "MINIMUM_CORE_UI_VERSION = '$MINIMUM_CORE_UI'"
unzip -p "$OUT/com_decaroforms_${NEW_VERSION}.zip" administrator/components/com_decaroforms/src/View/Information/HtmlView.php | grep -Fq 'useComponents($wa)'
unzip -p "$OUT/com_decaroforms_${NEW_VERSION}.zip" administrator/components/com_decaroforms/tmpl/information/core.php | grep -Fq 'dfi-page xdecaro-scope forms-core-scope'
python3 - "$ROOT/updates/pkg_decaroforms.xml" "$ROOT/updates/changelog.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
for p in sys.argv[1:]: ET.parse(p)
PY

echo "Built Forms $NEW_VERSION"
echo "SHA256: $SHA256"
