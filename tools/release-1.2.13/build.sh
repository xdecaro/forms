#!/usr/bin/env bash
set -euo pipefail

ROOT=/tmp/forms1213
OUTER="$ROOT/outer"
COMP="$ROOT/component"
PLUGIN="$ROOT/plugin"
rm -rf "$ROOT"
mkdir -p "$OUTER" "$COMP" "$PLUGIN" releases/1.2.13

unzip -q releases/1.2.12/pkg_decaroforms_1.2.12.zip -d "$OUTER"
COM_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'com_decaroforms_*.zip' | head -n1)"
PLG_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'plg_*decaroforms*.zip' | head -n1)"
unzip -q "$COM_ZIP" -d "$COMP"
unzip -q "$PLG_ZIP" -d "$PLUGIN"

FORM_VIEW="$COMP/administrator/components/com_decaroforms/tmpl/forms/default.php"

python3 - <<'PY'
from pathlib import Path
import re
p=Path('/tmp/forms1213/component/administrator/components/com_decaroforms/tmpl/forms/default.php')
s=p.read_text()

# Add a short Menu label wherever the Actions label already exists.
for f in Path('/tmp/forms1213/component').rglob('*.ini'):
    t=f.read_text(errors='ignore')
    if 'COM_DECAROFORMS_ACTIONS=' in t and 'COM_DECAROFORMS_MENU_SHORT=' not in t:
        f.write_text(t.rstrip()+"\nCOM_DECAROFORMS_MENU_SHORT=\"Menu\"\n")

# Button label and accessibility attributes.
s=s.replace(
    '<button class="df-btn" type="button" id="df-open-actions"><?php echo Text::_(\'COM_DECAROFORMS_ACTIONS\'); ?> ▾</button>',
    '<button class="df-btn" type="button" id="df-open-actions" aria-haspopup="menu" aria-expanded="false" aria-controls="df-actions-menu"><?php echo Text::_(\'COM_DECAROFORMS_MENU_SHORT\'); ?> ▾</button>'
)

# Replace the central dialog HTML with a compact menu container.
pattern=re.compile(r'\s*<dialog class="df-actions-dialog" id="df-actions-dialog">.*?</dialog>\s*',re.S)
replacement='''\n  <div class="df-actions-menu" id="df-actions-menu" role="menu" hidden>\n    <div class="df-dialog-links">\n      <a class="df-btn" role="menuitem" href="<?php echo $this->dashboardUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_DASHBOARD'); ?></a>\n      <a class="df-btn" role="menuitem" href="<?php echo $this->recentUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_RECENT'); ?></a>\n      <a class="df-btn" role="menuitem" href="<?php echo $this->importUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_MENU_IMPORT'); ?></a>\n      <a class="df-btn" role="menuitem" href="<?php echo $this->informationUrl; ?>"><?php echo Text::_('COM_DECAROFORMS_INFORMATION'); ?></a>\n    </div>\n  </div>\n\n'''
s,n=pattern.subn(replacement,s,count=1)
if n!=1:
    raise SystemExit('Actions dialog HTML not found')

# Compact dropdown styling. One navigation item per row.
css_pattern=re.compile(r'\.df-actions-dialog\{.*?\.df-dialog-links \.df-btn\{width:100%;min-height:48px;justify-content:center\}',re.S)
css_new='.df-actions-menu{position:fixed;z-index:1200;width:min(240px,calc(100vw - 24px));padding:8px;border:1px solid var(--df-border);border-radius:8px;background:var(--df-panel);color:inherit;box-shadow:0 14px 36px rgba(0,0,0,.28)}.df-actions-menu[hidden]{display:none!important}.df-dialog-links{display:grid;grid-template-columns:1fr;gap:6px;padding:0}.df-dialog-links .df-btn{width:100%;min-height:44px;justify-content:flex-start;padding-left:14px;padding-right:14px}'
s,n=css_pattern.subn(css_new,s,count=1)
if n!=1:
    raise SystemExit('Actions dialog CSS not found')
s=s.replace('.df-actions-dialog::backdrop{background:rgba(0,0,0,.56)}','')
s=re.sub(r'\.df-dialog-head\{.*?\.df-dialog-close\{.*?\}', '', s, count=1, flags=re.S)

# Keep the legacy dialog JS harmless (the dialog no longer exists) and add the new menu logic.
# This is deliberately additive so the release is resilient to minor formatting changes in prior JS.
menu_js="""
 const menuNav=document.getElementById('df-actions-menu'),menuBtnNav=document.getElementById('df-open-actions');
 const closeMenuNav=()=>{if(!menuNav)return;menuNav.hidden=true;menuBtnNav?.setAttribute('aria-expanded','false');};
 const placeMenuNav=()=>{if(!menuNav||!menuBtnNav||menuNav.hidden)return;const r=menuBtnNav.getBoundingClientRect();const w=menuNav.offsetWidth||240;const left=Math.max(12,Math.min(r.left,window.innerWidth-w-12));menuNav.style.left=`${left}px`;const maxTop=Math.max(12,window.innerHeight-menuNav.offsetHeight-12);menuNav.style.top=`${Math.min(r.bottom+8,maxTop)}px`;};
 menuBtnNav?.addEventListener('click',e=>{e.preventDefault();e.stopPropagation();if(!menuNav)return;const opening=menuNav.hidden;if(opening){menuNav.hidden=false;menuBtnNav.setAttribute('aria-expanded','true');requestAnimationFrame(placeMenuNav);}else closeMenuNav();});
 menuNav?.addEventListener('click',e=>e.stopPropagation());
 menuNav?.querySelectorAll('a').forEach(a=>a.addEventListener('click',closeMenuNav));
 document.addEventListener('click',closeMenuNav);
 document.addEventListener('keydown',e=>{if(e.key==='Escape')closeMenuNav();});
 window.addEventListener('resize',placeMenuNav);
 window.addEventListener('scroll',placeMenuNav,true);
"""
marker='})();'
pos=s.rfind(marker)
if pos<0:
    raise SystemExit('Forms list IIFE end not found')
s=s[:pos]+menu_js+s[pos:]

p.write_text(s)
PY

# Version bump.
while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.12/1.2.13/g' "$file"
done < <(find "$COMP" "$PLUGIN" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)
while IFS= read -r -d '' file; do
  sed -i 's/1\.2\.12/1.2.13/g' "$file"
done < <(find "$OUTER" -maxdepth 1 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.txt' \) -print0)

COM_NEW="$OUTER/com_decaroforms_1.2.13.zip"
PLG_BASENAME="$(basename "$PLG_ZIP")"
PLG_NEW="$OUTER/${PLG_BASENAME/1.2.12/1.2.13}"
rm -f "$COM_ZIP" "$PLG_ZIP"
(cd "$COMP" && zip -qr "$COM_NEW" .)
(cd "$PLUGIN" && zip -qr "$PLG_NEW" .)

TARGET="$GITHUB_WORKSPACE/releases/1.2.13/pkg_decaroforms_1.2.13.zip"
rm -f "$TARGET"
(cd "$OUTER" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

# Automated validation.
find "$COMP" -type f -name '*.php' -print0 | xargs -0 -n1 php -l >/tmp/forms1213-php.log
python3 - <<'PY'
import xml.etree.ElementTree as ET
ET.parse('/tmp/forms1213/component/com_decaroforms.xml')
PY
unzip -tq "$TARGET" >/dev/null
grep -q 'id="df-actions-menu" role="menu" hidden' "$FORM_VIEW"
grep -q 'aria-haspopup="menu"' "$FORM_VIEW"
grep -q 'COM_DECAROFORMS_MENU_SHORT' "$FORM_VIEW"
grep -q 'width:min(240px,calc(100vw - 24px))' "$FORM_VIEW"
grep -q "document.addEventListener('click',closeMenuNav)" "$FORM_VIEW"
! grep -q '<dialog class="df-actions-dialog"' "$FORM_VIEW"

cat > releases/1.2.13/README.md <<EOF
# Forms 1.2.13

Rifinitura finale del menu di navigazione nell'Elenco moduli.

## Modifiche

- "Azioni" diventa "Menu";
- eliminata la finestra modale centrale;
- Menu apre un dropdown compatto direttamente sotto il pulsante;
- nessun oscuramento della pagina;
- Riepilogo, Invii recenti, Importa dati e Guida restano una voce per riga;
- chiusura automatica con clic fuori, selezione di una voce o tasto Esc;
- layout coerente con light e dark mode;
- nessuna modifica allo schema database e nessuna perdita di dati.

SHA-256: $SHA
EOF

cat > updates/pkg_decaroforms.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update>
<name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description>
<element>pkg_decaroforms</element><type>package</type><client>site</client><version>1.2.13</version>
<downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/1.2.13/pkg_decaroforms_1.2.13.zip</downloadurl></downloads>
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
entry='''  <changelog>\n    <element>pkg_decaroforms</element><type>package</type><version>1.2.13</version>\n    <change><item>Renamed the Forms list navigation action from Azioni to Menu.</item><item>Replaced the central modal with a compact anchored dropdown menu.</item><item>The navigation menu closes on outside click, selection, or Escape.</item></change>\n  </changelog>\n'''
s=s.replace('<changelogs>\n','<changelogs>\n'+entry,1)
p.write_text(s)
ET.parse('updates/pkg_decaroforms.xml')
ET.parse('updates/changelog.xml')
PY

rm -rf releases/_upload
