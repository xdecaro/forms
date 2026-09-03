#!/usr/bin/env bash
set -euo pipefail

ROOT=/tmp/forms1210
OUTER="$ROOT/outer"
COMP="$ROOT/component"
PLUGIN="$ROOT/plugin"
rm -rf "$ROOT"
mkdir -p "$OUTER" "$COMP" "$PLUGIN" releases/1.2.10

unzip -q releases/1.2.9/pkg_decaroforms_1.2.9.zip -d "$OUTER"
COM_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'com_decaroforms_*.zip' | head -n1)"
PLG_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'plg_*decaroforms*.zip' | head -n1)"
unzip -q "$COM_ZIP" -d "$COMP"
unzip -q "$PLG_ZIP" -d "$PLUGIN"

python3 - <<'PY'
from pathlib import Path
import re

p=Path('/tmp/forms1210/component/administrator/components/com_decaroforms/tmpl/forms/default.php')
s=p.read_text()

# Shared visual variables and neutral hover feedback.
s=s.replace(
    '--df-border:var(--bs-border-color,#dfe3e7);max-width:none',
    '--df-border:var(--bs-border-color,#dfe3e7);--df-hover:var(--bs-tertiary-bg,#eef1f4);--df-border-strong:#b8c1cc;max-width:none'
)
s=s.replace(
    'cursor:pointer;text-align:center;line-height:1.2}',
    'cursor:pointer;text-align:center;line-height:1.2;transition:background-color .16s ease,border-color .16s ease,color .16s ease,transform .16s ease}'
)
s=s.replace(
    '.df-btn-primary{background:var(--df);border-color:var(--df);color:#fff!important}',
    '.df-btn:not(.df-btn-primary):hover{background:var(--df-hover);border-color:var(--df-border-strong)}.df-btn:focus-visible{outline:2px solid #1683d8;outline-offset:2px}.df-btn-primary{background:var(--df);border-color:var(--df);color:#fff!important}'
)

# Remove any residual title strip/background, including wrappers and pseudo-elements.
s=s.replace(
    '.df-card h3{margin:0 0 4px;font-size:19px;overflow-wrap:anywhere;background:transparent!important;background-color:transparent!important;padding:0!important;border:0!important;box-shadow:none!important}',
    '.df-card-main>div{background:transparent!important;background-color:transparent!important}.df-card h3{margin:0 0 4px;font-size:19px;overflow-wrap:anywhere;background:transparent!important;background-color:transparent!important;padding:0!important;border:0!important;box-shadow:none!important}.df-card h3::before,.df-card h3::after{content:none!important;display:none!important;background:none!important}'
)

# Strengthen dark theme variables and provide a JS-detected fallback class.
s=s.replace(
    '--df-field:#121a23;--df-border:#3b4857;color:#f3f6fa}',
    '--df-field:#121a23;--df-border:#3b4857;--df-hover:#263443;--df-border-strong:#56677a;color:#f3f6fa}'
)
anchor='html[data-bs-theme="dark"] .df-wrap code,html[data-color-scheme="dark"] .df-wrap code{color:#f07a9b}'
if anchor in s and '.df-wrap.df-dark-theme{' not in s:
    addition='''.df-wrap.df-dark-theme{--df:#9f1239;--df-dark:#7f0d2e;--df-panel:#1a232d;--df-panel-alt:#202b37;--df-field:#121a23;--df-border:#3b4857;--df-hover:#263443;--df-border-strong:#56677a;color:#f3f6fa}\n.df-wrap.df-dark-theme .df-head p,.df-wrap.df-dark-theme .df-card p{color:#b5c0cc}.df-wrap.df-dark-theme .df-on{background:#163b29;color:#a8e5bd}.df-wrap.df-dark-theme .df-off{background:#4a1f28;color:#ffb5c0}.df-wrap.df-dark-theme code{color:#f07a9b}.df-wrap.df-dark-theme .df-btn-primary{background:#9f1239!important;border-color:#9f1239!important;color:#fff!important}.df-wrap.df-dark-theme .df-btn-primary:hover{background:#7f0d2e!important;border-color:#7f0d2e!important}.df-wrap.df-dark-theme .df-btn:not(.df-btn-primary):hover{background:#263443;border-color:#56677a}\n'''
    s=s.replace(anchor, addition+anchor)

# Smartphone: two equal header actions, uniform accordion control, 46px card actions.
old='@container formslist (max-width:560px){.df-head{flex-direction:column;align-items:stretch;gap:10px}.df-actions{width:100%;display:grid;grid-template-columns:1fr}.df-actions>.df-btn{width:100%;min-height:44px}.df-filter-toggle{display:flex}.df-tools{display:none;grid-template-columns:1fr;margin-bottom:14px}.df-tools.is-open{display:grid}.df-card-main{padding:15px 16px;gap:10px}.df-card-meta{padding:12px 16px}.df-card-actions{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:8px;width:100%}.df-card-actions>*{width:100%}.df-card-actions .df-btn,.df-card-actions form .df-btn,.df-card-actions>a{width:100%;height:44px;min-height:44px;padding:0 7px;white-space:nowrap;font-size:12.5px;align-items:center;justify-content:center;text-align:center}.df-card-actions>*:nth-child(3){grid-column:1/-1}.df-card-actions>*:nth-child(3).df-btn{width:100%}.df-badge{margin-top:1px}}'
new='@container formslist (max-width:560px){.df-head{flex-direction:column;align-items:stretch;gap:10px}.df-actions{width:100%;display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px}.df-actions>.df-btn{width:100%;height:46px;min-height:46px;padding:0 8px;white-space:nowrap;font-size:13px}.df-filter-toggle{display:flex;position:relative;height:46px;min-height:46px;padding:0 42px 0 12px;align-items:center;justify-content:center;text-align:center;font-size:13px}.df-filter-toggle .df-chevron{position:absolute;right:14px;top:50%;transform:translateY(-50%)}.df-filter-toggle[aria-expanded="true"] .df-chevron{transform:translateY(-50%) rotate(180deg)}.df-tools{display:none;grid-template-columns:1fr;margin-bottom:14px}.df-tools.is-open{display:grid}.df-card-main{padding:15px 16px;gap:10px}.df-card-meta{padding:12px 16px}.df-card-actions{display:grid;grid-template-columns:minmax(0,1fr) minmax(0,1fr);gap:8px;width:100%}.df-card-actions>*{width:100%}.df-card-actions .df-btn,.df-card-actions form .df-btn,.df-card-actions>a{width:100%;height:46px;min-height:46px;padding:0 7px;white-space:nowrap;font-size:12.5px;align-items:center;justify-content:center;text-align:center}.df-card-actions>*:nth-child(3){grid-column:1/-1}.df-card-actions>*:nth-child(3).df-btn{width:100%}.df-badge{margin-top:1px}}'
if old not in s:
    raise SystemExit('Expected 1.2.9 smartphone container rule not found')
s=s.replace(old,new)

# Add robust dark-mode detection because Joomla theme state may not always be exposed on the same attribute.
needle='(()=>{\n const q=document.getElementById(\'df-search\')'
if needle not in s:
    raise SystemExit('Expected forms list JS start not found')
replacement='''(()=>{\n const wrap=document.querySelector('.df-wrap'),root=document.documentElement,body=document.body;\n const darkState=()=>{\n   const values=[root?.dataset?.bsTheme,root?.dataset?.colorScheme,body?.dataset?.bsTheme,body?.dataset?.colorScheme].filter(Boolean).map(v=>String(v).toLowerCase());\n   if(values.includes('dark')) return true;\n   if(values.includes('light')) return false;\n   const rgb=(getComputedStyle(body).backgroundColor.match(/[\\d.]+/g)||[]).slice(0,3).map(Number);\n   return rgb.length===3 && (0.2126*rgb[0]+0.7152*rgb[1]+0.0722*rgb[2])<128;\n };\n const syncTheme=()=>wrap?.classList.toggle('df-dark-theme',darkState());\n syncTheme();\n const observer=new MutationObserver(syncTheme);\n observer.observe(root,{attributes:true,attributeFilter:['data-bs-theme','data-color-scheme','class']});\n if(body) observer.observe(body,{attributes:true,attributeFilter:['data-bs-theme','data-color-scheme','class']});\n const q=document.getElementById('df-search')'''
s=s.replace(needle,replacement)

p.write_text(s)
PY

# Bump component/plugin/package manifests and package-level metadata.
while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.9/1.2.10/g' "$file"
done < <(find "$COMP" "$PLUGIN" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)
while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.9/1.2.10/g' "$file"
done < <(find "$OUTER" -maxdepth 1 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)

COM_NEW="$OUTER/com_decaroforms_1.2.10.zip"
PLG_BASENAME="$(basename "$PLG_ZIP")"
PLG_NEW="$OUTER/${PLG_BASENAME/1.2.9/1.2.10}"
rm -f "$COM_ZIP" "$PLG_ZIP"
(cd "$COMP" && zip -qr "$COM_NEW" .)
(cd "$PLUGIN" && zip -qr "$PLG_NEW" .)

TARGET="$GITHUB_WORKSPACE/releases/1.2.10/pkg_decaroforms_1.2.10.zip"
rm -f "$TARGET"
(cd "$OUTER" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

# Automated checks.
find "$COMP" -type f -name '*.php' -print0 | xargs -0 -n1 php -l >/tmp/forms1210-php.log
python3 - <<'PY'
import xml.etree.ElementTree as ET
ET.parse('/tmp/forms1210/component/com_decaroforms.xml')
PY
unzip -tq "$TARGET" >/dev/null
grep -q 'grid-template-columns:repeat(2,minmax(0,1fr))' "$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
grep -q 'height:46px;min-height:46px' "$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
grep -q 'df-dark-theme' "$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
grep -q '#9f1239!important' "$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
grep -q 'df-btn:not(.df-btn-primary):hover' "$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"
grep -q 'df-card-main>div{background:transparent!important' "$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"

cat > releases/1.2.10/README.md <<EOF
# Forms 1.2.10

Rifinitura UI responsive e dark mode dell'Elenco moduli.

## Modifiche

- su smartphone Azioni e + Nuovo modulo sono affiancati 50/50;
- Cerca e filtra usa la stessa altezza, bordo, font e centratura dei pulsanti principali;
- Modifica modulo, Duplica e Vedi invii passano a 46 px di altezza su smartphone;
- Vedi invii e + Nuovo modulo usano un rosso scuro reale nel dark mode;
- aggiunto hover evidente e coerente a Modifica modulo e Duplica;
- aggiunto focus visibile per navigazione da tastiera;
- rafforzato il rilevamento del tema dark anche quando Joomla non espone lo stato sul medesimo attributo;
- rimossa ogni possibile fascia residua dietro ai titoli delle card;
- nessuna modifica allo schema database e nessuna perdita di dati.

SHA-256: $SHA
EOF

cat > updates/pkg_decaroforms.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.2.10</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.2.10/pkg_decaroforms_1.2.10.zip</downloadurl></downloads>
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
entry='''  <changelog>\n    <element>pkg_decaroforms</element><type>package</type><version>1.2.10</version>\n    <fix><item>Dark accent buttons now use the intended dark red variant.</item><item>Neutral form actions now provide visible hover and keyboard focus feedback.</item><item>Removed residual title-strip styling from form cards.</item></fix>\n    <change><item>Smartphone header actions are displayed in two equal columns.</item><item>Search and filter accordion matches the main action controls.</item><item>Smartphone card actions use a consistent 46-pixel height.</item></change>\n  </changelog>\n'''
s=s.replace('<changelogs>\n','<changelogs>\n'+entry,1)
p.write_text(s)
ET.parse('updates/pkg_decaroforms.xml')
ET.parse('updates/changelog.xml')
PY

rm -rf releases/_upload
