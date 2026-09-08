#!/usr/bin/env bash
set -Eeuo pipefail
trap 'status=$?; echo "Build failed at line ${LINENO}: ${BASH_COMMAND}" >&2; exit "$status"' ERR

BASE_VERSION="1.3.74"
NEW_VERSION="1.4.0"
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

MODEL="$WORK/component/administrator/components/com_decaroforms/src/Model/InformationModel.php"
TPL="$WORK/component/administrator/components/com_decaroforms/tmpl/information/default.php"
VIEW="$WORK/component/administrator/components/com_decaroforms/src/View/Information/HtmlView.php"
HELPER="$WORK/component/administrator/components/com_decaroforms/src/Helper/FormHelper.php"
[[ -f "$MODEL" && -f "$TPL" && -f "$VIEW" && -f "$HELPER" ]] || {
    echo "Forms Information source files missing" >&2
    exit 1
}

# 1) Add optional Xdecaro Core detection through the stable public Version API.
python3 - "$MODEL" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')

needle = "    public const MINIMUM_PHP = '8.3.0';\n"
replacement = needle + "    public const MINIMUM_CORE = '1.0.0';\n"
if s.count(needle) != 1:
    raise SystemExit('MINIMUM_PHP marker not found exactly once')
s = s.replace(needle, replacement, 1)

old_integrations = """        $integrations = [
            $this->getRelatedComponent(
                'Courses by xdecaro',
                'com_decarocourses',
                'xdecaro/courses',
                false,
                '#__decarocourses_courses'
            ),
        ];
"""
new_integrations = """        $coreIntegration = $this->getCoreIntegration();
        $integrations = [
            $coreIntegration,
            $this->getRelatedComponent(
                'Courses by xdecaro',
                'com_decarocourses',
                'xdecaro/courses',
                false,
                '#__decarocourses_courses'
            ),
        ];
"""
if s.count(old_integrations) != 1:
    raise SystemExit('1.3.74 integrations block not found exactly once')
s = s.replace(old_integrations, new_integrations, 1)

needle = """        $criticalIssues = [];
        $warnings = [];

"""
replacement = """        $criticalIssues = [];
        $warnings = [];

        if (empty($coreIntegration['compatible'])) {
            $warnings[] = 'core';
        }

"""
if s.count(needle) != 1:
    raise SystemExit('Warnings initialization marker not found exactly once')
s = s.replace(needle, replacement, 1)

needle = """            'integrations' => $integrations,
            'critical_issues' => $criticalIssues,
"""
replacement = """            'integrations' => $integrations,
            'core_installed' => !empty($coreIntegration['installed']),
            'core_compatible' => !empty($coreIntegration['compatible']),
            'core_api_available' => !empty($coreIntegration['api_available']),
            'core_version' => (string) ($coreIntegration['version'] ?? ''),
            'minimum_core' => self::MINIMUM_CORE,
            'critical_issues' => $criticalIssues,
"""
if s.count(needle) != 1:
    raise SystemExit('Return integrations marker not found exactly once')
s = s.replace(needle, replacement, 1)

method_marker = """    private function getRelatedComponent(
"""
core_method = r"""    private function getCoreIntegration(): array
    {
        $package = $this->getExtension('package', 'pkg_xdecarocore');
        $plugin = $this->getExtension('plugin', 'xdecarocore', 'system');
        $apiAvailable = class_exists('\\Xdecaro\\Core\\Version');
        $apiVersion = $apiAvailable ? trim((string) \Xdecaro\Core\Version::VERSION) : '';
        $packageVersion = $this->getManifestVersion($package);
        $version = $apiVersion !== '' ? $apiVersion : $packageVersion;
        $installed = $package !== null || $apiAvailable;
        $compatible = $apiAvailable
            && $version !== ''
            && version_compare($version, self::MINIMUM_CORE, '>=');

        return [
            'name' => 'Xdecaro Core',
            'element' => 'pkg_xdecarocore',
            'repository' => 'xdecaro/core',
            'required' => false,
            'installed' => $installed,
            'version' => $version,
            'enabled' => $plugin !== null && (int) ($plugin->enabled ?? 0) === 1,
            'compatible' => $compatible,
            'api_available' => $apiAvailable,
            'minimum_version' => self::MINIMUM_CORE,
            'metric_label_key' => 'COM_DECAROFORMS_INFO_CORE_API',
            'metric_value_key' => $apiAvailable
                ? 'COM_DECAROFORMS_INFO_AVAILABLE'
                : 'COM_DECAROFORMS_INFO_UNAVAILABLE',
        ];
    }

"""
if s.count(method_marker) != 1:
    raise SystemExit('getRelatedComponent marker not found exactly once')
s = s.replace(method_marker, core_method + method_marker, 1)

p.write_text(s, encoding='utf-8')
PY

# 2) Show Core in integrations and diagnostics without making it a hard dependency.
python3 - "$TPL" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
s = p.read_text(encoding='utf-8')

needle = """$warnings = (array) ($info['warnings'] ?? []);
$systemOk = count($criticalIssues) === 0;
"""
replacement = """$warnings = (array) ($info['warnings'] ?? []);
$coreInstalled = !empty($info['core_installed']);
$coreCompatible = !empty($info['core_compatible']);
$coreApiAvailable = !empty($info['core_api_available']);
$coreVersion = (string) ($info['core_version'] ?? '');
$systemOk = count($criticalIssues) === 0;
"""
if s.count(needle) != 1:
    raise SystemExit('Template status variables marker not found exactly once')
s = s.replace(needle, replacement, 1)

needle = """    'Forms ' . $installedVersion,
    'Joomla: ' . (string) ($info['joomla_version'] ?? '—'),
"""
replacement = """    'Forms ' . $installedVersion,
    'Xdecaro Core: ' . ($coreInstalled
        ? (($coreVersion !== '' ? $coreVersion : '—') . ($coreApiAvailable ? ' (API disponibile)' : ' (API non disponibile)'))
        : 'non installato'),
    'Joomla: ' . (string) ($info['joomla_version'] ?? '—'),
"""
if s.count(needle) != 1:
    raise SystemExit('Diagnostic lines marker not found exactly once')
s = s.replace(needle, replacement, 1)

needle = """                    $installed = !empty($integration['installed']);
                    $required = !empty($integration['required']);
                    $integrationVersion = (string) ($integration['version'] ?? '');
"""
replacement = """                    $installed = !empty($integration['installed']);
                    $required = !empty($integration['required']);
                    $integrationVersion = (string) ($integration['version'] ?? '');
                    $integrationCompatible = !array_key_exists('compatible', $integration) || !empty($integration['compatible']);
                    $minimumVersion = (string) ($integration['minimum_version'] ?? '');
                    $metricLabelKey = (string) ($integration['metric_label_key'] ?? 'COM_DECAROFORMS_INFO_AVAILABLE_MODULES');
                    $metricValueKey = (string) ($integration['metric_value_key'] ?? '');
                    $metricValue = $metricValueKey !== ''
                        ? Text::_($metricValueKey)
                        : (string) (int) ($integration['count'] ?? 0);
"""
if s.count(needle) != 1:
    raise SystemExit('Integration variables marker not found exactly once')
s = s.replace(needle, replacement, 1)

needle = """                                · <code><?= $this->escape((string) ($integration['element'] ?? '')); ?></code>
                            </div>
"""
replacement = """                                · <code><?= $this->escape((string) ($integration['element'] ?? '')); ?></code>
                                <?php if ($minimumVersion !== '') : ?>
                                    · <?= Text::sprintf('COM_DECAROFORMS_INFO_CORE_MINIMUM', $this->escape($minimumVersion)); ?>
                                <?php endif; ?>
                            </div>
"""
if s.count(needle) != 1:
    raise SystemExit('Integration meta marker not found exactly once')
s = s.replace(needle, replacement, 1)

needle = """                            <div>
                                <span class="dfi-small-label"><?= Text::_('COM_DECAROFORMS_INFO_AVAILABLE_MODULES'); ?></span>
                                <strong><?= (int) ($integration['count'] ?? 0); ?></strong>
                            </div>
"""
replacement = """                            <div>
                                <span class="dfi-small-label"><?= Text::_($metricLabelKey); ?></span>
                                <strong><?= $this->escape($metricValue); ?></strong>
                            </div>
"""
if s.count(needle) != 1:
    raise SystemExit('Integration second metric marker not found exactly once')
s = s.replace(needle, replacement, 1)

needle = """                        <div class="dfi-integration-badges">
                            <span class="dfi-badge <?= $installed ? 'is-success' : ($required ? 'is-danger' : 'is-muted'); ?>"><?= Text::_($installed ? 'COM_DECAROFORMS_INFO_INSTALLED' : 'COM_DECAROFORMS_INFO_NOT_INSTALLED'); ?></span>
                            <span class="dfi-badge <?= $required ? 'is-warning' : 'is-muted'; ?>"><?= Text::_($required ? 'COM_DECAROFORMS_INFO_REQUIRED' : 'COM_DECAROFORMS_INFO_OPTIONAL'); ?></span>
                        </div>
"""
replacement = """                        <div class="dfi-integration-badges">
                            <span class="dfi-badge <?= !$installed ? ($required ? 'is-danger' : 'is-muted') : ($integrationCompatible ? 'is-success' : 'is-warning'); ?>"><?= Text::_(!$installed ? 'COM_DECAROFORMS_INFO_NOT_INSTALLED' : ($integrationCompatible ? 'COM_DECAROFORMS_INFO_INSTALLED' : 'COM_DECAROFORMS_INFO_CHECK_REQUIRED')); ?></span>
                            <span class="dfi-badge <?= $required ? 'is-warning' : 'is-muted'; ?>"><?= Text::_($required ? 'COM_DECAROFORMS_INFO_REQUIRED' : 'COM_DECAROFORMS_INFO_OPTIONAL'); ?></span>
                        </div>
"""
if s.count(needle) != 1:
    raise SystemExit('Integration badges marker not found exactly once')
s = s.replace(needle, replacement, 1)

needle = """                <div class="dfi-check <?= $environmentCompatible ? 'is-ok' : 'is-bad'; ?>"><span aria-hidden="true"><?= $environmentCompatible ? '✓' : '!'; ?></span><?= Text::_('COM_DECAROFORMS_INFO_CHECK_ENVIRONMENT'); ?></div>
            </div>
"""
replacement = """                <div class="dfi-check <?= $environmentCompatible ? 'is-ok' : 'is-bad'; ?>"><span aria-hidden="true"><?= $environmentCompatible ? '✓' : '!'; ?></span><?= Text::_('COM_DECAROFORMS_INFO_CHECK_ENVIRONMENT'); ?></div>
                <div class="dfi-check <?= $coreCompatible ? 'is-ok' : 'is-warn'; ?>"><span aria-hidden="true"><?= $coreCompatible ? '✓' : '!'; ?></span><?= Text::_('COM_DECAROFORMS_INFO_CHECK_CORE'); ?></div>
            </div>
"""
if s.count(needle) != 1:
    raise SystemExit('Diagnostics checks marker not found exactly once')
s = s.replace(needle, replacement, 1)

needle = """                    <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_PACKAGE_ID'); ?></dt><dd><code>pkg_decaroforms</code></dd></div>
                </dl>
"""
replacement = """                    <div class="dfi-row"><dt><?= Text::_('COM_DECAROFORMS_INFO_PACKAGE_ID'); ?></dt><dd><code>pkg_decaroforms</code></dd></div>
                    <div class="dfi-row"><dt>Xdecaro Core</dt><dd><code><?= $coreVersion !== '' ? $this->escape($coreVersion) : '—'; ?></code></dd></div>
                </dl>
"""
if s.count(needle) != 1:
    raise SystemExit('Technical details marker not found exactly once')
s = s.replace(needle, replacement, 1)

p.write_text(s, encoding='utf-8')
PY

# 3) Add only the new Core-related translations.
python3 - "$WORK/component" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])
translations = {
    'it-IT': {
        'COM_DECAROFORMS_INFO_CORE_API': 'API pubblica',
        'COM_DECAROFORMS_INFO_AVAILABLE': 'Disponibile',
        'COM_DECAROFORMS_INFO_UNAVAILABLE': 'Non disponibile',
        'COM_DECAROFORMS_INFO_CORE_MINIMUM': 'Core minimo: %s',
        'COM_DECAROFORMS_INFO_CHECK_CORE': 'Xdecaro Core',
    },
    'en-GB': {
        'COM_DECAROFORMS_INFO_CORE_API': 'Public API',
        'COM_DECAROFORMS_INFO_AVAILABLE': 'Available',
        'COM_DECAROFORMS_INFO_UNAVAILABLE': 'Unavailable',
        'COM_DECAROFORMS_INFO_CORE_MINIMUM': 'Minimum Core: %s',
        'COM_DECAROFORMS_INFO_CHECK_CORE': 'Xdecaro Core',
    },
    'fr-FR': {
        'COM_DECAROFORMS_INFO_CORE_API': 'API publique',
        'COM_DECAROFORMS_INFO_AVAILABLE': 'Disponible',
        'COM_DECAROFORMS_INFO_UNAVAILABLE': 'Indisponible',
        'COM_DECAROFORMS_INFO_CORE_MINIMUM': 'Core minimum : %s',
        'COM_DECAROFORMS_INFO_CHECK_CORE': 'Xdecaro Core',
    },
}

for tag, items in translations.items():
    p = root / 'administrator/components/com_decaroforms/language' / tag / 'com_decaroforms.ini'
    s = p.read_text(encoding='utf-8')
    for key, value in items.items():
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

# 4) Version/cache markers. No Forms business logic is changed.
python3 - "$HELPER" "$VIEW" "$NEW_VERSION" <<'PY'
from pathlib import Path
import re
import sys

helper = Path(sys.argv[1])
view = Path(sys.argv[2])
version = sys.argv[3]

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
import re
import sys

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

# Regression guard: only Information, translations and release metadata may change.
python3 - "$WORK/component-old" "$WORK/component" "$WORK/system-old" "$WORK/system" "$WORK/editor-old" "$WORK/editor" <<'PY'
from pathlib import Path
import hashlib
import sys

def hashes(root):
    out = {}
    for p in Path(root).rglob('*'):
        if p.is_file():
            out[str(p.relative_to(root))] = hashlib.sha256(p.read_bytes()).hexdigest()
    return out

old, new = hashes(sys.argv[1]), hashes(sys.argv[2])
allowed = {
    'com_decaroforms.xml',
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

# Syntax + exact Core integration guards.
php -l "$MODEL" >/dev/null
php -l "$TPL" >/dev/null
php -l "$VIEW" >/dev/null
php -l "$HELPER" >/dev/null
python3 - "$WORK/component/com_decaroforms.xml" "$WORK/system/decaroforms.xml" "$WORK/editor/decaroforms.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET
for path in sys.argv[1:]:
    ET.parse(path)
PY

grep -q "public const MINIMUM_CORE = '1.0.0';" "$MODEL"
grep -q "class_exists" "$MODEL"
grep -Fq "Version::VERSION" "$MODEL"
grep -q "'pkg_xdecarocore'" "$MODEL"
grep -q "'core_compatible'" "$MODEL"
grep -q 'COM_DECAROFORMS_INFO_CORE_API' "$MODEL"
grep -Fq '$metricLabelKey' "$TPL"
grep -q 'COM_DECAROFORMS_INFO_CHECK_CORE' "$TPL"
grep -q 'COM_DECAROFORMS_INFO_CORE_MINIMUM' "$TPL"
grep -q "'#__decarocourses_courses'" "$MODEL"

# Rebuild nested ZIPs.
rm -f "$WORK/outer/com_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_system_decaroforms_${BASE_VERSION}.zip" "$WORK/outer/plg_editors-xtd_decaroforms_${BASE_VERSION}.zip"
(cd "$WORK/component" && zip -qr "$WORK/outer/com_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')
(cd "$WORK/system" && zip -qr "$WORK/outer/plg_system_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')
(cd "$WORK/editor" && zip -qr "$WORK/outer/plg_editors-xtd_decaroforms_${NEW_VERSION}.zip" . -x '*.DS_Store' '*/.DS_Store')

python3 - "$WORK/outer/pkg_decaroforms.xml" "$BASE_VERSION" "$NEW_VERSION" "$RELEASE_DATE" <<'PY'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
base, new, release_date = sys.argv[2:5]
s = p.read_text(encoding='utf-8').replace(base, new)
s = re.sub(r'<creationDate>[^<]+</creationDate>', f'<creationDate>{release_date}</creationDate>', s, count=1)
p.write_text(s, encoding='utf-8')
PY
python3 - "$WORK/outer/pkg_decaroforms.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET
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

Prima integrazione runtime opzionale con **Xdecaro Core 1.0+**.

- rilevamento sicuro di \`pkg_xdecarocore\` e della public API \`Xdecaro\\Core\\Version\`;
- Core mostrato nella pagina Informazioni con versione installata, disponibilità API e versione minima;
- nuovo controllo Core nella Diagnostica e nel testo diagnostico esportabile;
- Core resta opzionale: la sua assenza non provoca errori fatali né blocca Forms;
- se Core è presente ma la public API non è disponibile/compatibile, Informazioni mostra uno stato da verificare;
- Courses continua a essere rilevato con il conteggio già introdotto in 1.3.74;
- Builder, drag & drop, invii, email, import/export, database e frontend Forms non modificati.

SHA-256 pacchetto: \`$SHA256\`
EOF

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update><name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description><element>pkg_decaroforms</element><type>package</type><client>site</client><version>$NEW_VERSION</version><downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/$NEW_VERSION/pkg_decaroforms_$NEW_VERSION.zip</downloadurl></downloads><changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags><maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl><targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA256</sha256></update></updates>
EOF

python3 - "$ROOT/updates/changelog.xml" "$NEW_VERSION" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
version = sys.argv[2]
s = p.read_text(encoding='utf-8')
if f'<version>{version}</version>' not in s:
    entry = (
        "\t<changelog>\n"
        "\t\t<element>pkg_decaroforms</element>\n"
        "\t\t<type>package</type>\n"
        f"\t\t<version>{version}</version>\n"
        "\t\t<note>Prima integrazione runtime opzionale con Xdecaro Core 1.0+: rilevamento package/API/versione nella pagina Informazioni e nuovo controllo Diagnostica. Core assente non blocca Forms; Builder e logica applicativa invariati.</note>\n"
        "\t</changelog>\n"
    )
    s = s.replace('<changelogs>\n', '<changelogs>\n' + entry, 1)
    p.write_text(s, encoding='utf-8')
PY

python3 - "$ROOT/README.md" "$BASE_VERSION" "$NEW_VERSION" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
base, new = sys.argv[2:4]
s = p.read_text(encoding='utf-8')
marker = f'**{base}**'
if s.count(marker) != 1:
    raise SystemExit('README current version marker not found exactly once')
s = s.replace(marker, f'**{new}**', 1)
feature = '- optional Xdecaro Core 1.0+ detection and diagnostics without making Core a hard runtime dependency;\n'
anchor = '- package-level Joomla update server.\n'
if feature not in s:
    if s.count(anchor) != 1:
        raise SystemExit('README main-features anchor not found exactly once')
    s = s.replace(anchor, feature + anchor, 1)
p.write_text(s, encoding='utf-8')
PY

# Final package verification.
unzip -t "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" >/dev/null
unzip -l "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | grep -q "com_decaroforms_${NEW_VERSION}.zip"
unzip -l "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | grep -q "plg_system_decaroforms_${NEW_VERSION}.zip"
unzip -l "$OUT/pkg_decaroforms_${NEW_VERSION}.zip" | grep -q "plg_editors-xtd_decaroforms_${NEW_VERSION}.zip"
unzip -p "$OUT/com_decaroforms_${NEW_VERSION}.zip" administrator/components/com_decaroforms/src/Model/InformationModel.php | grep -q "MINIMUM_CORE = '1.0.0'"
unzip -p "$OUT/com_decaroforms_${NEW_VERSION}.zip" administrator/components/com_decaroforms/tmpl/information/default.php | grep -q 'COM_DECAROFORMS_INFO_CHECK_CORE'
python3 - "$ROOT/updates/pkg_decaroforms.xml" "$ROOT/updates/changelog.xml" <<'PY'
import sys
import xml.etree.ElementTree as ET
for path in sys.argv[1:]:
    ET.parse(path)
PY

echo "Built Forms $NEW_VERSION"
echo "SHA256: $SHA256"
