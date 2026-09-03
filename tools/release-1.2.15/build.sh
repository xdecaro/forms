#!/usr/bin/env bash
set -euo pipefail

ROOT=/tmp/forms1215
OUTER="$ROOT/outer"
COMP="$ROOT/component"
PLUGIN="$ROOT/plugin"
rm -rf "$ROOT"
mkdir -p "$OUTER" "$COMP" "$PLUGIN" releases/1.2.15

unzip -q releases/1.2.14/pkg_decaroforms_1.2.14.zip -d "$OUTER"
COM_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'com_decaroforms_*.zip' | head -n1)"
PLG_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'plg_*decaroforms*.zip' | head -n1)"
unzip -q "$COM_ZIP" -d "$COMP"
unzip -q "$PLG_ZIP" -d "$PLUGIN"

FORM_VIEW="$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"

python3 - <<'PY'
from pathlib import Path
import re
p=Path('/tmp/forms1215/component/administrator/components/com_decaroforms/tmpl/forms/default.php')
s=p.read_text()

# Add the existing builder close-reason mapping once before the forms loop.
loop_pat=r'(<div class="df-list" id="df-list">\s*)(<\?php foreach\s*\(\$this->forms\s+as\s+\$form\)\s*:)'
m=re.search(loop_pat,s,re.S)
if not m:
    raise SystemExit('Forms loop anchor not found')
reason_php=r'''<?php
$closedReasonLabels = [
    'closed' => Text::_('COM_DECAROFORMS_CLOSED_REGISTRATIONS'),
    'limit' => Text::_('COM_DECAROFORMS_LIMIT_REACHED'),
    'deadline' => Text::_('COM_DECAROFORMS_DEADLINE_EXPIRED'),
    'temporary' => Text::_('COM_DECAROFORMS_TEMPORARILY_CLOSED'),
    'custom' => Text::_('COM_DECAROFORMS_CUSTOM_MESSAGE'),
];
$closedReasonClasses = [
    'closed' => 'df-reason-closed',
    'limit' => 'df-reason-limit',
    'deadline' => 'df-reason-deadline',
    'temporary' => 'df-reason-temporary',
    'custom' => 'df-reason-custom',
];
?>
'''
s=s[:m.start(2)] + reason_php + s[m.start(2):]

# Add per-card reason state after the enabled assignment.
enabled_pat=r'(\$enabled\s*=\s*[^;]+;)'
m=re.search(enabled_pat,s)
if not m:
    raise SystemExit('Enabled assignment not found')
reason_state=r'''
$closedReason = (string) ($form['closed_reason'] ?? 'closed');
if (!isset($closedReasonLabels[$closedReason])) {
    $closedReason = 'closed';
}
$closedReasonLabel = $closedReasonLabels[$closedReason];
$closedReasonClass = $closedReasonClasses[$closedReason];
$closedReasonTitle = $closedReason === 'custom' ? trim((string) ($form['closed_message'] ?? '')) : '';
'''
s=s[:m.end()] + reason_state + s[m.end():]

# Replace the old single status badge with a status + reason badge group.
old=r'''<div class="df-card-main"><div><h3><?php echo htmlspecialchars($form['title'],ENT_QUOTES,'UTF-8'); ?></h3><p><?php echo htmlspecialchars((string)$form['description'],ENT_QUOTES,'UTF-8'); ?></p></div><span class="df-badge <?php echo $enabled?'df-on':'df-off'; ?>"><?php echo $enabled?Text::_('COM_DECAROFORMS_ENABLED'):Text::_('COM_DECAROFORMS_DISABLED'); ?></span></div>'''
new=r'''<div class="df-card-main"><div><h3><?php echo htmlspecialchars($form['title'],ENT_QUOTES,'UTF-8'); ?></h3><p><?php echo htmlspecialchars((string)$form['description'],ENT_QUOTES,'UTF-8'); ?></p></div><div class="df-card-badges"><span class="df-badge <?php echo $enabled?'df-on':'df-off'; ?>"><?php echo $enabled?Text::_('COM_DECAROFORMS_ENABLED'):Text::_('COM_DECAROFORMS_DISABLED'); ?></span><?php if(!$enabled): ?><span class="df-badge df-reason <?php echo htmlspecialchars($closedReasonClass,ENT_QUOTES,'UTF-8'); ?>"<?php echo $closedReasonTitle!==''?' title="'.htmlspecialchars($closedReasonTitle,ENT_QUOTES,'UTF-8').'"':''; ?>><?php echo htmlspecialchars($closedReasonLabel,ENT_QUOTES,'UTF-8'); ?></span><?php endif; ?></div></div>'''
if old not in s:
    raise SystemExit('Card status badge block not found')
s=s.replace(old,new,1)

# Append visual rules: reason colors, subtle open animation, dark small-label contrast.
css=r'''
/* Forms 1.2.15: disabled reason badge + lightweight motion */
.df-card-badges{display:flex;flex-wrap:wrap;align-items:flex-start;justify-content:flex-end;gap:6px;max-width:100%}
.df-badge.df-reason{border:1px solid transparent}
.df-badge.df-reason-closed{background:#fff0e5!important;color:#a33a00!important;border-color:#ffc79f!important}
.df-badge.df-reason-limit{background:#fff7d6!important;color:#805b00!important;border-color:#efd36c!important}
.df-badge.df-reason-deadline{background:#ffebe5!important;color:#a83214!important;border-color:#efb29f!important}
.df-badge.df-reason-temporary{background:#eef2f6!important;color:#475467!important;border-color:#cfd7e3!important}
.df-badge.df-reason-custom{background:#f4ebff!important;color:#6941c6!important;border-color:#d6bbfb!important}
.df-actions-menu:not([hidden]){transform-origin:top right;animation:df-menu-in .18s cubic-bezier(.2,.7,.2,1) both}
.df-tools.is-open{transform-origin:top center;animation:df-filter-in .2s ease both}
@keyframes df-menu-in{from{opacity:0;transform:translateY(-6px) scale(.98)}to{opacity:1;transform:translateY(0) scale(1)}}
@keyframes df-filter-in{from{opacity:0;transform:translateY(-4px)}to{opacity:1;transform:translateY(0)}}
html[data-bs-theme="dark"] .df-wrap .df-code small,
html[data-bs-theme="dark"] .df-wrap .df-count small,
html[data-color-scheme="dark"] .df-wrap .df-code small,
html[data-color-scheme="dark"] .df-wrap .df-count small,
.df-wrap.df-dark-theme .df-code small,
.df-wrap.df-dark-theme .df-count small{color:#b5c0cc}
@container formslist (max-width:560px){.df-card-badges{flex-direction:column;align-items:flex-end;justify-content:flex-start;flex-wrap:nowrap}.df-badge.df-reason{max-width:150px;white-space:normal;text-align:center;line-height:1.15}}
@media (prefers-reduced-motion:reduce){.df-actions-menu:not([hidden]),.df-tools.is-open{animation:none!important}.df-filter-toggle .df-chevron,.df-btn{transition:none!important}}
'''
if '</style>' not in s:
    raise SystemExit('Style end not found')
s=s.replace('</style>',css+'\n</style>',1)

# Validation inside source.
for needle in ['df-card-badges','df-reason-closed','COM_DECAROFORMS_CLOSED_REGISTRATIONS','df-menu-in','prefers-reduced-motion']:
    if needle not in s:
        raise SystemExit(f'Missing expected marker: {needle}')
p.write_text(s)
PY

# Version bump in component/plugin/package metadata and PHP/text references.
while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.14/1.2.15/g' "$file"
done < <(find "$COMP" "$PLUGIN" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)
while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.14/1.2.15/g' "$file"
done < <(find "$OUTER" -maxdepth 1 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)

COM_NEW="$OUTER/com_decaroforms_1.2.15.zip"
PLG_BASENAME="$(basename "$PLG_ZIP")"
PLG_NEW="$OUTER/${PLG_BASENAME/1.2.14/1.2.15}"
rm -f "$COM_ZIP" "$PLG_ZIP"
(cd "$COMP" && zip -qr "$COM_NEW" .)
(cd "$PLUGIN" && zip -qr "$PLG_NEW" .)

TARGET="$GITHUB_WORKSPACE/releases/1.2.15/pkg_decaroforms_1.2.15.zip"
rm -f "$TARGET"
(cd "$OUTER" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

# Automated validation.
find "$COMP" -type f -name '*.php' -print0 | xargs -0 -n1 php -l >/tmp/forms1215-php.log
python3 - <<'PY'
import xml.etree.ElementTree as ET
ET.parse('/tmp/forms1215/component/com_decaroforms.xml')
PY
unzip -tq "$TARGET" >/dev/null
grep -q 'Forms 1.2.15: disabled reason badge + lightweight motion' "$FORM_VIEW"
grep -q 'df-card-badges' "$FORM_VIEW"
grep -q 'df-reason-custom' "$FORM_VIEW"
grep -q 'prefers-reduced-motion:reduce' "$FORM_VIEW"
grep -q "\$form\['closed_reason'\]" "$FORM_VIEW"

cat > releases/1.2.15/README.md <<EOF
# Forms 1.2.15

Motivazione visiva della disattivazione e micro-animazioni dell'Elenco moduli.

## Modifiche

- quando un modulo è disattivato mostra un secondo badge con il motivo già configurato nel builder;
- valori supportati: Iscrizioni chiuse, Limite raggiunto, Termine scaduto, Chiuso temporaneamente e Messaggio personalizzato;
- Iscrizioni chiuse resta il motivo predefinito già previsto dal componente;
- il badge usa colori semantici leggibili e indipendenti dal tema light/dark;
- per Messaggio personalizzato, il testo di chiusura configurato viene esposto come tooltip quando presente;
- aggiunta animazione leggera all'apertura del Menu e dell'accordion Cerca e filtra;
- rispettata la preferenza di sistema prefers-reduced-motion;
- aumentato il contrasto di SHORTCODE e INVII nel dark mode;
- nessuna modifica allo schema database e nessuna perdita di dati.

SHA-256: $SHA
EOF

cat > updates/pkg_decaroforms.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.2.15</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.2.15/pkg_decaroforms_1.2.15.zip</downloadurl></downloads>
<changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags>
<maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl>
<targetplatform name="joomla" version="6\\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256>
</update></updates>
EOF

python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET
p=Path('updates/changelog.xml')
s=p.read_text()
entry='''  <changelog>\n    <element>pkg_decaroforms</element><type>package</type><version>1.2.15</version>\n    <change><item>Added a second semantic badge showing the configured disabled reason.</item><item>Added lightweight Menu and filter accordion open animations with reduced-motion support.</item><item>Improved dark-mode contrast for SHORTCODE and INVII labels.</item></change>\n  </changelog>\n'''
if '<changelogs>\n' not in s:
    raise SystemExit('Changelog root not found')
s=s.replace('<changelogs>\n','<changelogs>\n'+entry,1)
p.write_text(s)
ET.parse('updates/pkg_decaroforms.xml')
ET.parse('updates/changelog.xml')
PY

rm -rf releases/_upload releases/_inspect-1.2.14-deactivation.txt
