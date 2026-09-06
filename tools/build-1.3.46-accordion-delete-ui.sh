#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.45"
NEW="1.3.46"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1346-builder.js' EXIT
mkdir -p "$TMP/outer" "$TMP/component" "$TARGET_DIR"
test -f "$BASE"
unzip -q "$BASE" -d "$TMP/outer"
COMP_OLD="$TMP/outer/com_decaroforms_$OLD.zip"
test -f "$COMP_OLD"
unzip -q "$COMP_OLD" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
test -f "$B"

python3 - "$B" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')

def rep(old,new,label,count=1):
    global s
    if old not in s:
        raise SystemExit(f'1.3.46: {label} anchor missing')
    s=s.replace(old,new,count)

# 1) Expand/Collapse affects every accordion, including General and its rows.
rep(
"toolbar.querySelector('[data-layout-collapse]').onclick=()=>{groups.forEach(g=>{const keep=g.id==='general';layoutSectionState.set(g.id,keep);g.rows.forEach(r=>layoutRowState.set(r.rowNo,keep));});renderLayoutCanvas();};",
"toolbar.querySelector('[data-layout-collapse]').onclick=()=>{groups.forEach(g=>{layoutSectionState.set(g.id,false);g.rows.forEach(r=>layoutRowState.set(r.rowNo,false));});renderLayoutCanvas();};",
'collapse all'
)

# 2) General is an accordion again.
rep(
"const activeInGroup=(group.sectionField?.[0]?.key===activeFieldKey)||group.rows.some(r=>r.items.some(([f])=>f.key===activeFieldKey)||activeStructureSelection?.type==='row'&&Number(activeStructureSelection.row)===Number(r.rowNo));const sectionOpen=group.id==='general'?true:(layoutSectionState.has(group.id)?layoutSectionState.get(group.id):(activeInGroup||groups.length===1||(gi===0&&!activeFieldKey)));",
"const activeInGroup=(group.sectionField?.[0]?.key===activeFieldKey)||group.rows.some(r=>r.items.some(([f])=>f.key===activeFieldKey)||activeStructureSelection?.type==='row'&&Number(activeStructureSelection.row)===Number(r.rowNo));const sectionOpen=layoutSectionState.has(group.id)?layoutSectionState.get(group.id):(activeInGroup||groups.length===1||(gi===0&&!activeFieldKey));",
'general section state'
)

# 3) General has a chevron aligned in the same column as normal sections.
old="const sectionDescription=group.sectionField?.[0]?.config?.content||'',sectionHandle=group.sectionField?`<span class=\"df-layout-structure-handle df-section-drag-handle\" role=\"button\" tabindex=\"0\" title=\"Trascina sezione\" aria-label=\"Trascina sezione\">${modernUiIcon('grip')}</span>`:'',sectionLeading=group.id==='general'?'<span class=\"df-layout-leading-spacer\" aria-hidden=\"true\"></span>':`${sectionHandle}<span class=\"df-layout-section-chevron\">›</span>`;"
new="const sectionDescription=group.sectionField?.[0]?.config?.content||'',sectionHandle=group.sectionField?`<span class=\"df-layout-structure-handle df-section-drag-handle\" role=\"button\" tabindex=\"0\" title=\"Trascina sezione\" aria-label=\"Trascina sezione\">${modernUiIcon('grip')}</span>`:'',sectionLeading=group.id==='general'?'<span class=\"df-layout-general-grip-spacer\" aria-hidden=\"true\"></span><span class=\"df-layout-section-chevron\">›</span>':`${sectionHandle}<span class=\"df-layout-section-chevron\">›</span>`;"
rep(old,new,'General chevron alignment')

# 4) Whole section header toggles the accordion. Edit remains on the pencil button.
rep(
"const toggleSection=()=>{if(group.id==='general')return;layoutSectionState.set(group.id,!wrap.classList.contains('is-open'));renderLayoutCanvas();};head.addEventListener('click',e=>{if(Date.now()<structureSuppressClickUntil||e.target.closest('.df-layout-structure-handle'))return;if(e.target.closest('button'))return;if(e.target.closest('.df-layout-section-chevron')){toggleSection();return;}if(group.sectionField){const [,si]=group.sectionField;selectField(si);layoutSectionState.set(group.id,true);}else toggleSection();});head.addEventListener('keydown',e=>{if((e.key==='Enter'||e.key===' ')&&!e.target.closest('button')){e.preventDefault();if(group.sectionField){const [,si]=group.sectionField;selectField(si);layoutSectionState.set(group.id,true);}else toggleSection();}});",
"const toggleSection=()=>{layoutSectionState.set(group.id,!wrap.classList.contains('is-open'));renderLayoutCanvas();};head.addEventListener('click',e=>{if(Date.now()<structureSuppressClickUntil||e.target.closest('.df-layout-structure-handle'))return;if(e.target.closest('button'))return;toggleSection();});head.addEventListener('keydown',e=>{if((e.key==='Enter'||e.key===' ')&&!e.target.closest('button')){e.preventDefault();toggleSection();}});",
'section accordion toggle'
)

# 5) Rows in General are accordions again.
rep(
"const rowSelected=activeStructureSelection?.type==='row'&&Number(activeStructureSelection.row)===Number(model.rowNo),rowActive=rowSelected||model.items.some(([f])=>f.key===activeFieldKey),rowOpen=group.id==='general'?true:(layoutRowState.has(model.rowNo)?layoutRowState.get(model.rowNo):(rowActive||(sectionOpen&&group.rows.length===1)));",
"const rowSelected=activeStructureSelection?.type==='row'&&Number(activeStructureSelection.row)===Number(model.rowNo),rowActive=rowSelected||model.items.some(([f])=>f.key===activeFieldKey),rowOpen=layoutRowState.has(model.rowNo)?layoutRowState.get(model.rowNo):(rowActive||(sectionOpen&&group.rows.length===1));",
'row accordion state'
)

# 6) Every row shows its chevron.
rep(
"const rowChevron=group.id==='general'?'':`<span class=\"df-layout-row-chevron\">›</span>`;",
"const rowChevron=`<span class=\"df-layout-row-chevron\">›</span>`;",
'row chevron'
)

# 7) Whole row header toggles. Pencil remains the explicit settings action.
rep(
"const toggleRow=()=>{if(group.id==='general')return;layoutRowState.set(model.rowNo,!rowGroup.classList.contains('is-open'));renderLayoutCanvas();};rowHead.onclick=e=>{if(Date.now()<structureSuppressClickUntil||e.target.closest('.df-layout-structure-handle')||e.target.closest('button'))return;if(e.target.closest('.df-layout-row-chevron'))toggleRow();else selectRowSettings(model.rowNo);};rowHead.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();selectRowSettings(model.rowNo);}};",
"const toggleRow=()=>{layoutRowState.set(model.rowNo,!rowGroup.classList.contains('is-open'));renderLayoutCanvas();};rowHead.onclick=e=>{if(Date.now()<structureSuppressClickUntil||e.target.closest('.df-layout-structure-handle')||e.target.closest('button'))return;toggleRow();};rowHead.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();toggleRow();}};",
'row accordion toggle'
)

# 8) CSS override: closed really means hidden, despite the multi-line flex layout.
marker='/* Forms 1.3.45: permanent General rows + aligned drag affordances. */'
pos=s.find(marker)
if pos<0:
    raise SystemExit('1.3.46: 1.3.45 CSS marker missing')
css=r'''
/* Forms 1.3.46: real accordions + uniform destructive actions. */
.df-layout-general-grip-spacer{width:30px;height:30px;min-width:30px;flex:0 0 30px;display:block}
.df-layout-section-group.is-general>.df-layout-section-head{cursor:pointer}
.df-layout-section-group:not(.is-open)>.df-layout-section-body{display:none!important}
.df-layout-section-group.is-open>.df-layout-section-body{display:block!important}
.df-builder-workspace .df-layout-row-group:not(.is-open)>.df-layout-row-body{display:none!important}
.df-builder-workspace .df-layout-row-group.is-open>.df-layout-row-body{display:flex!important;flex-direction:column}
[data-section-remove],[data-row-remove],[data-structure-remove]{color:#dc3545!important;background:transparent!important}
[data-section-remove]:hover,[data-section-remove]:focus-visible,[data-row-remove]:hover,[data-row-remove]:focus-visible,[data-structure-remove]:hover,[data-structure-remove]:focus-visible{color:#b42318!important;background:color-mix(in srgb,#dc3545 10%,transparent)!important;outline:none}
@media(max-width:800px){.df-layout-general-grip-spacer{width:34px;height:34px;min-width:34px;flex-basis:34px}}
'''
s=s[:pos]+css+'\n'+s[pos:]

# Runtime version.
s=s.replace("version:'1.3.45'","version:'1.3.46'")
s=s.replace('version: \"1.3.45\"','version: \"1.3.46\"')
p.write_text(s,encoding='utf-8')
PY

# Manifest/package versions.
find "$TMP/component" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.js' -o -name '*.json' \) -print0 | xargs -0 sed -i 's/1\.3\.45/1.3.46/g'
find "$TMP/outer" -maxdepth 1 -type f -name '*.xml' -print0 | xargs -0 sed -i 's/1\.3\.45/1.3.46/g'

# PHP + JS syntax checks.
php -l "$B"
python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
matches=list(re.finditer(r'<script(?:\s[^>]*)?>(.*?)</script>',s,re.S|re.I))
js='\n'.join(m.group(1) for m in matches)
js=re.sub(r'<\?(?:php|=).*?\?>','null',js,flags=re.S|re.I)
Path('/tmp/forms-1346-builder.js').write_text(js,encoding='utf-8')
PY
node --check /tmp/forms-1346-builder.js

# Regression checks.
grep -q "layoutSectionState.set(g.id,false)" "$B"
grep -q "const sectionOpen=layoutSectionState.has(group.id)" "$B"
grep -q "df-layout-general-grip-spacer" "$B"
grep -q "const rowChevron=\`<span class=\\\"df-layout-row-chevron" "$B"
grep -q "const toggleRow=()=>{layoutRowState.set" "$B"
grep -q "data-section-remove" "$B"
grep -q "data-row-remove" "$B"
grep -q "data-structure-remove" "$B"
grep -q "duplicateLayoutSection" "$B"
grep -q "smartMoveLineRelative" "$B"
grep -q "df-smart-source-line-empty" "$B"

# Rebuild component zip.
rm -f "$TMP/outer/com_decaroforms_$OLD.zip"
(
  cd "$TMP/component"
  zip -qr "$TMP/outer/com_decaroforms_$NEW.zip" .
)

# Rename nested packages using release number where present.
for f in "$TMP/outer"/*"$OLD"*.zip; do
  [ -e "$f" ] || continue
  nf="${f//$OLD/$NEW}"
  mv "$f" "$nf"
done

# Build package.
(
  cd "$TMP/outer"
  zip -qr "$TARGET" .
)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

# Update Joomla update feed.
FEED="$ROOT/updates/pkg_decaroforms.xml"
python3 - "$FEED" "$NEW" "$SHA" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); v=sys.argv[2]; sha=sys.argv[3]; s=p.read_text(encoding='utf-8')
s=re.sub(r'<version>[^<]+</version>',f'<version>{v}</version>',s,count=1)
s=re.sub(r'releases/[0-9.]+/pkg_decaroforms_[0-9.]+\.zip',f'releases/{v}/pkg_decaroforms_{v}.zip',s,count=1)
s=re.sub(r'<sha256>[^<]+</sha256>',f'<sha256>{sha}</sha256>',s,count=1)
p.write_text(s,encoding='utf-8')
PY

# Changelog.
CHANGE="$ROOT/updates/changelog.xml"
if [ -f "$CHANGE" ]; then
python3 - "$CHANGE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
if '<version>1.3.46</version>' not in s:
    entry='''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>1.3.46</version>\n\t\t<note>Builder: Generale, Sezioni e Righe tornano accordion reali; click intestazione apre/chiude; correzione CSS delle righe nascoste; icone Elimina di Riga e Sezione sempre rosse e uniformi.</note>\n\t</changelog>'''
    pos=s.find('>')+1
    s=s[:pos]+entry+s[pos:]
    p.write_text(s,encoding='utf-8')
PY
fi

echo "Built $TARGET"
echo "SHA256 $SHA"
