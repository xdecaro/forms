#!/usr/bin/env bash
set -euo pipefail

BASE_VERSION="1.3.73"
NEW_VERSION="1.3.74"
RELEASE_DATE="2026-09-08"
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

CSS="$WORK/component/media/css/information.css"
MODEL="$WORK/component/administrator/components/com_decaroforms/src/Model/InformationModel.php"
TPL="$WORK/component/administrator/components/com_decaroforms/tmpl/information/default.php"
[[ -f "$CSS" && -f "$MODEL" && -f "$TPL" ]] || { echo "Forms Information source files missing" >&2; exit 1; }

# 1) Integration data: expose the number of available Courses records safely.
python3 - "$MODEL" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')

old_call = '''            $this->getRelatedComponent(\n                'Courses by xdecaro',\n                'com_decarocourses',\n                'xdecaro/courses',\n                false\n            ),'''
new_call = '''            $this->getRelatedComponent(\n                'Courses by xdecaro',\n                'com_decarocourses',\n                'xdecaro/courses',\n                false,\n                '#__decarocourses_courses'\n            ),'''
if s.count(old_call) != 1:
    raise SystemExit('Related Courses integration call not found exactly once')
s = s.replace(old_call, new_call, 1)

old_method = '''    private function getRelatedComponent(\n        string $name,\n        string $element,\n        string $repository,\n        bool $required\n    ): array {\n        $extension = $this->getExtension('component', $element);\n\n        return [\n            'name' => $name,\n            'element' => $element,\n            'repository' => $repository,\n            'required' => $required,\n            'installed' => $extension !== null,\n            'version' => $this->getManifestVersion($extension),\n            'enabled' => $extension !== null && (int) ($extension->enabled ?? 0) === 1,\n        ];\n    }'''
new_method = '''    private function getRelatedComponent(\n        string $name,\n        string $element,\n        string $repository,\n        bool $required,\n        ?string $countTable = null\n    ): array {\n        $extension = $this->getExtension('component', $element);\n        $count = 0;\n\n        if ($extension !== null && $countTable !== null) {\n            $db = $this->getDatabase();\n            $realTable = $db->replacePrefix($countTable);\n\n            try {\n                if (in_array($realTable, $db->getTableList(), true)) {\n                    $query = $db->getQuery(true)\n                        ->select('COUNT(*)')\n                        ->from($db->quoteName($countTable));\n                    $count = (int) $db->setQuery($query)->loadResult();\n                }\n            } catch (\\Throwable) {\n                $count = 0;\n            }\n        }\n\n        return [\n            'name' => $name,\n            'element' => $element,\n            'repository' => $repository,\n            'required' => $required,\n            'installed' => $extension !== null,\n            'version' => $this->getManifestVersion($extension),\n            'enabled' => $extension !== null && (int) ($extension->enabled ?? 0) === 1,\n            'count' => $count,\n        ];\n    }'''
if s.count(old_method) != 1:
    raise SystemExit('getRelatedComponent method not found exactly once')
s = s.replace(old_method, new_method, 1)
p.write_text(s, encoding='utf-8')
PY

# 2) Integration markup: use the same four visual areas as approved Courses.
python3 - "$TPL" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')
old = '''                    <article class="dfi-integration">\n                        <div>\n                            <div class="dfi-integration-name"><?= $this->escape((string) ($integration['name'] ?? '')); ?></div>\n                            <div class="dfi-integration-meta">\n                                <?= Text::_($required ? 'COM_DECAROFORMS_INFO_REQUIRED_DEPENDENCY' : 'COM_DECAROFORMS_INFO_OPTIONAL_INTEGRATION'); ?>\n                                · <code><?= $this->escape((string) ($integration['element'] ?? '')); ?></code>\n                            </div>\n                        </div>\n                        <div class="dfi-integration-status">\n                            <div>\n                                <span class="dfi-small-label"><?= Text::_('COM_DECAROFORMS_INFO_INSTALLED_VERSION'); ?></span>\n                                <strong><?= $integrationVersion !== '' ? $this->escape($integrationVersion) : '—'; ?></strong>\n                            </div>\n                            <div class="dfi-badges">\n                                <span class="dfi-badge <?= $installed ? 'is-success' : ($required ? 'is-danger' : 'is-muted'); ?>"><?= Text::_($installed ? 'COM_DECAROFORMS_INFO_INSTALLED' : 'COM_DECAROFORMS_INFO_NOT_INSTALLED'); ?></span>\n                                <span class="dfi-badge <?= $required ? 'is-warning' : 'is-muted'; ?>"><?= Text::_($required ? 'COM_DECAROFORMS_INFO_REQUIRED' : 'COM_DECAROFORMS_INFO_OPTIONAL'); ?></span>\n                            </div>\n                        </div>\n                    </article>'''
new = '''                    <article class="dfi-integration">\n                        <div class="dfi-integration-main">\n                            <div class="dfi-integration-name"><?= $this->escape((string) ($integration['name'] ?? '')); ?></div>\n                            <div class="dfi-integration-meta">\n                                <?= Text::_($required ? 'COM_DECAROFORMS_INFO_REQUIRED_DEPENDENCY' : 'COM_DECAROFORMS_INFO_OPTIONAL_INTEGRATION'); ?>\n                                · <code><?= $this->escape((string) ($integration['element'] ?? '')); ?></code>\n                            </div>\n                        </div>\n                        <div class="dfi-integration-metrics">\n                            <div>\n                                <span class="dfi-small-label"><?= Text::_('COM_DECAROFORMS_INFO_INSTALLED_VERSION'); ?></span>\n                                <strong><?= $integrationVersion !== '' ? $this->escape($integrationVersion) : '—'; ?></strong>\n                            </div>\n                            <div>\n                                <span class="dfi-small-label"><?= Text::_('COM_DECAROFORMS_INFO_AVAILABLE_MODULES'); ?></span>\n                                <strong><?= (int) ($integration['count'] ?? 0); ?></strong>\n                            </div>\n                        </div>\n                        <div class="dfi-integration-badges">\n                            <span class="dfi-badge <?= $installed ? 'is-success' : ($required ? 'is-danger' : 'is-muted'); ?>"><?= Text::_($installed ? 'COM_DECAROFORMS_INFO_INSTALLED' : 'COM_DECAROFORMS_INFO_NOT_INSTALLED'); ?></span>\n                            <span class="dfi-badge <?= $required ? 'is-warning' : 'is-muted'; ?>"><?= Text::_($required ? 'COM_DECAROFORMS_INFO_REQUIRED' : 'COM_DECAROFORMS_INFO_OPTIONAL'); ?></span>\n                        </div>\n                    </article>'''
if s.count(old) != 1:
    raise SystemExit('Integration template block not found exactly once')
s = s.replace(old, new, 1)
p.write_text(s, encoding='utf-8')
PY

# 3) Integration CSS only: match approved Courses 1.0.44 geometry and responsive behavior.
python3 - "$CSS" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')

# Preserve the already-approved diagnostics CSS byte-for-byte.
diag_before = s[s.index('.dfi-checks {'):s.index('@media (max-width: 900px)')]

old_grid = '''.dfi-integration {\n  display: grid;\n  grid-template-columns: minmax(220px, 1fr) minmax(320px, 1fr);\n  align-items: center;\n  gap: 20px;\n  padding: 14px 0 2px;\n  border-bottom: 1px solid var(--dfi-border);\n}\n'''
new_grid = '''.dfi-integration {\n  display: grid;\n  grid-template-columns: minmax(240px, 1.25fr) minmax(230px, .85fr) auto;\n  align-items: center;\n  gap: 20px;\n  padding: 14px 0 2px;\n  border-bottom: 1px solid var(--dfi-border);\n}\n'''
if s.count(old_grid) != 1:
    raise SystemExit('Forms integration grid block not found exactly once')
s = s.replace(old_grid, new_grid, 1)

old_status = '''.dfi-integration-status {\n  display: flex;\n  align-items: center;\n  justify-content: space-between;\n  gap: 16px;\n}\n\n.dfi-small-label {\n  display: block;\n  margin-bottom: 2px;\n  color: var(--dfi-muted);\n  font-size: 10px;\n}\n\n.dfi-integration-status strong {\n  font-size: 12px;\n}\n\n.dfi-badges {\n  display: flex;\n  justify-content: flex-end;\n  flex-wrap: wrap;\n  gap: 6px;\n}\n'''
new_status = '''.dfi-integration-main {\n  min-width: 0;\n}\n\n.dfi-integration-metrics {\n  display: grid;\n  grid-template-columns: repeat(2, minmax(0, 1fr));\n  gap: 18px;\n}\n\n.dfi-small-label {\n  display: block;\n  margin-bottom: 2px;\n  color: var(--dfi-muted);\n  font-size: 10px;\n}\n\n.dfi-integration-metrics strong {\n  display: block;\n  font-size: 12px;\n}\n\n.dfi-integration-badges {\n  display: flex;\n  justify-content: flex-end;\n  flex-wrap: wrap;\n  gap: 6px;\n}\n'''
if s.count(old_status) != 1:
    raise SystemExit('Old integration status CSS not found exactly once')
s = s.replace(old_status, new_status, 1)

old_900 = '''@media (max-width: 900px) {\n  .dfi-grid {\n    grid-template-columns: 1fr;\n  }\n\n  .dfi-full {\n    grid-column: auto;\n  }\n\n  .dfi-checks {\n    grid-template-columns: repeat(2, minmax(0, 1fr));\n  }\n}\n'''
new_900 = '''@media (max-width: 900px) {\n  .dfi-grid {\n    grid-template-columns: 1fr;\n  }\n\n  .dfi-full {\n    grid-column: auto;\n  }\n\n  .dfi-integration {\n    grid-template-columns: 1fr;\n    gap: 10px;\n  }\n\n  .dfi-integration-badges {\n    justify-content: flex-start;\n  }\n\n  .dfi-checks {\n    grid-template-columns: repeat(2, minmax(0, 1fr));\n  }\n}\n'''
if s.count(old_900) != 1:
    raise SystemExit('900px media block not found exactly once')
s = s.replace(old_900, new_900, 1)

old_700 = '''  .dfi-integration {\n    grid-template-columns: 1fr;\n    gap: 10px;\n  }\n\n  .dfi-card-head,\n  .dfi-diagnostic-top {\n    flex-direction: column;\n  }\n}\n'''
new_700 = '''  .dfi-card-head,\n  .dfi-diagnostic-top {\n    flex-direction: column;\n  }\n}\n'''
if s.count(old_700) != 1:
    raise SystemExit('700px integration media fragment not found exactly once')
s = s.replace(old_700, new_700, 1)

old_mobile = '''  .dfi-integration-status {\n    align-items: flex-start;\n    flex-direction: column;\n  }\n\n  .dfi-badges {\n    justify-content: flex-start;\n  }\n\n  .dfi-checks {'''
new_mobile = '''  .dfi-integration-metrics {\n    grid-template-columns: 1fr 1fr;\n  }\n\n  .dfi-checks {'''
if s.count(old_mobile) != 1:
    raise SystemExit('Old mobile integration CSS not found exactly once')
s = s.replace(old_mobile, new_mobile, 1)

# Diagnostics section must remain untouched.
diag_after = s[s.index('.dfi-checks {'):s.index('@media (max-width: 900px)')]
if diag_before != diag_after:
    raise SystemExit('Regression guard: diagnostics CSS changed unexpectedly')

p.write_text(s, encoding='utf-8')
PY

# 4) Add the integration metric label to all supported languages.
python3 - "$WORK/component" <<'PY'
from pathlib import Path
import re, sys
root = Path(sys.argv[1])
values = {
    'it-IT': 'Moduli disponibili',
    'en-GB': 'Available modules',
    'fr-FR': 'Modules disponibles',
}
key = 'COM_DECAROFORMS_INFO_AVAILABLE_MODULES'
for tag, value in values.items():
    p = root / 'administrator/components/com_decaroforms/language' / tag / 'com_decaroforms.ini'
    s = p.read_text(encoding='utf-8')
    line = f'{key}="{value}"'
    pattern = re.compile(rf'(?m)^{re.escape(key)}=.*$')
    if pattern.search(s):
        s = pattern.sub(line, s, count=1)
    else:
        if not s.endswith('\n'):
            s += '\n'
        s += line + '\n'
    p.write_text(s, encoding='utf-8')
PY

# 5) Version/cache markers only; application behavior outside Information stays unchanged.
python3 - "$WORK/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php" "$WORK/component/administrator/components/com_decaroforms/src/View/Information/HtmlView.php" "$NEW_VERSION" <<'PY'
from pathlib import Path
import re, sys
helper = Path(sys.argv[1]); view = Path(sys.argv[2]); version = sys.argv[3]
s = helper.read_text(encoding='utf-8')
s, n = re.subn(r"public const VERSION\s*=\s*'[^']+';", f"public const VERSION = '{version}';", s, count=1)
if n != 1:
    raise SystemExit('Unable to update FormHelper::VERSION')
helper.write_text(s, encoding='utf-8')

s = view.read_text(encoding='utf-8')
s, n = re.subn(r"'version'\s*=>\s*'[^']+'", f"'version' => '{version}'", s)
if n < 2:
    raise SystemExit(f'Expected both Information asset versions, found {n}')
view.write_text(s, encoding='utf-8')
PY

python3 - "$WORK/component/com_decaroforms.xml" "$WORK/system/decaroforms.xml" "$WORK/editor/decaroforms.xml" "$NEW_VERSION" "$RELEASE_DATE" <<'PY'
from pathlib import Path
import re, sys
version, release_date = sys.argv[4], sys.argv[5]
for filename in sys.argv[1:4]:
    p = Path(filename)
    s = p.read_text(encoding='utf-8')
    s, n = re.subn(r'<version>[^<]+</version>', f'<version>{version}</version>', s, count=1)
    if n != 1:
        raise SystemExit(f'Version not found in {filename}')
    s = re.sub(r'<creationDate>[^<]+</creationDate>', f'<creationDate>{release_date}</creationDate>', s, count=1)
    p.write_text(s, encoding='utf-8')
PY

# Regression guard: only explicit Information files + release metadata may change.
python3 - "$WORK/component-old" "$WORK/component" "$WORK/system-old" "$WORK/system" "$WORK/editor-old" "$WORK/editor" <<'PY'
from pathlib import Path
import hashlib, sys

def hashes(root):
    out = {}
    for p in Path(root).rglob('*'):
        if p.is_file():
            out[str(p.relative_to(root))] = hashlib.sha256(p.read_bytes()).hexdigest()
    return out

old, new = hashes(sys.argv[1]), hashes(sys.argv[2])
allowed = {
    'com_decaroforms.xml',
    'media/css/information.css',
    'administrator/components/com_decaroforms/src/Model/InformationModel.php',
    'administrator/components/com_decaroforms/tmpl/information/default.php',
    'administrator/components/com_decaroforms/src/Helper/FormHelper.php',
    'administrator/components/com_decaroforms/src/View/Information/HtmlView.php',
    'administrator/components/com_decaroforms/language/it-IT/com_decaroforms.ini',
    'administrator/components/com_decaroforms/language/en-GB/com_decaroforms.ini',
    'administrator/components/com_decaroforms/language/fr-FR/com_decaroforms.ini',
}
unexpected = sorted(p for p, h in old.items() if new.get(p) != h and p not in allowed)
if unexpected:
    raise SystemExit('Unexpected component regressions: ' + ', '.join(unexpected))
for old_root, new_root in ((sys.argv[3], sys.argv[4]), (sys.argv[5], sys.argv[6])):
    oh, nh = hashes(old_root), hashes(new_root)
    unexpected = sorted(p for p, h in oh.items() if nh.get(p) != h and p != 'decaroforms.xml')
    if unexpected:
        raise SystemExit('Unexpected plugin regressions: ' + ', '.join(unexpected))
PY

# Syntax + exact integration guards.
php -l "$MODEL" >/dev/null
php -l "$TPL" >/dev/null
php -l "$WORK/component/administrator/components/com_decaroforms/src/View/Information/HtmlView.php" >/dev/null
php -l "$WORK/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php" >/dev/null
python3 - "$WORK/component/com_decaroforms.xml" "$WORK/system/decaroforms.xml" "$WORK/editor/decaroforms.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
for path in sys.argv[1:]: ET.parse(path)
PY

grep -q "'#__decarocourses_courses'" "$MODEL"
grep -q "'count' => \$count" "$MODEL"
grep -q 'COM_DECAROFORMS_INFO_AVAILABLE_MODULES' "$TPL"
grep -q 'dfi-integration-metrics' "$TPL"
grep -q 'grid-template-columns: minmax(240px, 1.25fr) minmax(230px, .85fr) auto;' "$CSS"
grep -q 'padding: 14px 0 2px;' "$CSS"
if grep -q 'dfi-integration-status' "$TPL"; then echo 'Old integration status markup remains' >&2; exit 1; fi

# Rebuild nested ZIPs.
rm -f "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip"
(cd "$WORK/component" && zip -qr "$WORK/outer/com_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')
(cd "$WORK/system" && zip -qr "$WORK/outer/plg_system_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')
(cd "$WORK/editor" && zip -qr "$WORK/outer/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')

python3 - "$WORK/outer/pkg_decaroforms.xml" "$BASE_VERSION" "$NEW_VERSION" "$RELEASE_DATE" <<'PY'
from pathlib import Path
import re, sys
p = Path(sys.argv[1]); base, new, release_date = sys.argv[2:5]
s = p.read_text(encoding='utf-8').replace(base, new)
s = re.sub(r'<creationDate>[^<]+</creationDate>', f'<creationDate>{release_date}</creationDate>', s, count=1)
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

Rifinitura mirata della sola sezione **Integrazioni** della pagina Informazioni.

- riga Courses uniformata alla struttura approvata di Courses 1.0.44: nome, versione installata, Moduli disponibili, badge;
- aggiunto conteggio sicuro dei record nella tabella Courses solo quando componente e tabella sono presenti;
- layout desktop/tablet/smartphone allineato alla griglia già approvata in Courses;
- Diagnostica, Builder, drag & drop, database Forms e logica applicativa non modificati.

SHA-256 pacchetto: `$SHA256`
EOF

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update><name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description><element>pkg_decaroforms</element><type>package</type><client>site</client><version>$NEW_VERSION</version><downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/$NEW_VERSION/pkg_decaroforms_$NEW_VERSION.zip</downloadurl></downloads><changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags><maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl><targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA256</sha256></update></updates>
EOF

python3 - "$ROOT/updates/changelog.xml" "$NEW_VERSION" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1]); version = sys.argv[2]
s = p.read_text(encoding='utf-8')
if f'<version>{version}</version>' not in s:
    entry = ("\t<changelog>\n"
             "\t\t<element>pkg_decaroforms</element>\n"
             "\t\t<type>package</type>\n"
             f"\t\t<version>{version}</version>\n"
             "\t\t<note>Informazioni/Integrazioni: la riga Courses ora replica la struttura approvata con versione installata, Moduli disponibili e badge separati. Conteggio Courses sicuro e responsive allineato; Diagnostica e Builder invariati.</note>\n"
             "\t</changelog>\n")
    s = s.replace('<changelogs>\n', '<changelogs>\n' + entry, 1)
    p.write_text(s, encoding='utf-8')
PY

# Final package verification.
unzip -t "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" >/dev/null
unzip -l "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | grep -q "com_decaroforms_${NEW_VERSION}.zip"
unzip -l "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | grep -q "plg_system_decaroforms_${NEW_VERSION}.zip"
unzip -l "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | grep -q "plg_editors-xtd_decaroforms_${NEW_VERSION}.zip"
unzip -p "$OUT/com_decaroforms_${NEW_VERSION}.zip" administrator/components/com_decaroforms/tmpl/information/default.php | grep -q 'COM_DECAROFORMS_INFO_AVAILABLE_MODULES'
unzip -p "$OUT/com_decaroforms_${NEW_VERSION}.zip" media/css/information.css | grep -q 'minmax(240px, 1.25fr) minmax(230px, .85fr) auto'
python3 - "$ROOT/updates/pkg_decaroforms.xml" "$ROOT/updates/changelog.xml" <<'PY'
import sys, xml.etree.ElementTree as ET
for path in sys.argv[1:]: ET.parse(path)
PY

echo "Built Forms $NEW_VERSION"
echo "SHA256: $SHA256"
