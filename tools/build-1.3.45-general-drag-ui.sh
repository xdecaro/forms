#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.44"
NEW="1.3.45"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1345-builder.js' EXIT
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
    if old not in s: raise SystemExit(f'1.3.45: {label} anchor missing')
    s=s.replace(old,new,count)

# General stays open when Collapse all is used.
old="toolbar.querySelector('[data-layout-collapse]').onclick=()=>{groups.forEach(g=>{layoutSectionState.set(g.id,false);g.rows.forEach(r=>layoutRowState.set(r.rowNo,false));});renderLayoutCanvas();};"
new="toolbar.querySelector('[data-layout-collapse]').onclick=()=>{groups.forEach(g=>{const keep=g.id==='general';layoutSectionState.set(g.id,keep);g.rows.forEach(r=>layoutRowState.set(r.rowNo,keep));});renderLayoutCanvas();};"
rep(old,new,'collapse all general')

# General itself is permanently open.
old="const activeInGroup=(group.sectionField?.[0]?.key===activeFieldKey)||group.rows.some(r=>r.items.some(([f])=>f.key===activeFieldKey)||activeStructureSelection?.type==='row'&&Number(activeStructureSelection.row)===Number(r.rowNo));const sectionOpen=layoutSectionState.has(group.id)?layoutSectionState.get(group.id):(activeInGroup||groups.length===1||(gi===0&&!activeFieldKey));"
new="const activeInGroup=(group.sectionField?.[0]?.key===activeFieldKey)||group.rows.some(r=>r.items.some(([f])=>f.key===activeFieldKey)||activeStructureSelection?.type==='row'&&Number(activeStructureSelection.row)===Number(r.rowNo));const sectionOpen=group.id==='general'?true:(layoutSectionState.has(group.id)?layoutSectionState.get(group.id):(activeInGroup||groups.length===1||(gi===0&&!activeFieldKey)));"
rep(old,new,'general permanently open')

# Align General title with structural titles, but do not show a collapse chevron.
old="const sectionDescription=group.sectionField?.[0]?.config?.content||'',sectionHandle=group.sectionField?`<span class=\"df-layout-structure-handle df-section-drag-handle\" role=\"button\" tabindex=\"0\" title=\"Trascina sezione\" aria-label=\"Trascina sezione\">${modernUiIcon('grip')}</span>`:'';head.innerHTML=`${sectionHandle}<span class=\"df-layout-section-chevron\">›</span><span class=\"df-layout-section-title\"><strong>${esc(group.title)}</strong>${sectionDescription?`<span class=\"df-layout-structure-description\">${esc(sectionDescription)}</span>`:''}<span class=\"df-layout-section-summary\">${count} ${esc(structureUi.fields)} · ${rowCount} ${esc(structureUi.rows)}</span></span>${sectionActions}`;if(group.sectionField){const handle=head.querySelector('.df-section-drag-handle');handle?.addEventListener('pointerdown',e=>structureQueue(e,handle,'section',group.id,group.title));handle?.addEventListener('click',e=>{e.stopPropagation();});}"
new="const sectionDescription=group.sectionField?.[0]?.config?.content||'',sectionHandle=group.sectionField?`<span class=\"df-layout-structure-handle df-section-drag-handle\" role=\"button\" tabindex=\"0\" title=\"Trascina sezione\" aria-label=\"Trascina sezione\">${modernUiIcon('grip')}</span>`:'',sectionLeading=group.id==='general'?'<span class=\"df-layout-leading-spacer\" aria-hidden=\"true\"></span>':`${sectionHandle}<span class=\"df-layout-section-chevron\">›</span>`;head.innerHTML=`${sectionLeading}<span class=\"df-layout-section-title\"><strong>${esc(group.title)}</strong>${sectionDescription?`<span class=\"df-layout-structure-description\">${esc(sectionDescription)}</span>`:''}<span class=\"df-layout-section-summary\">${count} ${esc(structureUi.fields)} · ${rowCount} ${esc(structureUi.rows)}</span></span>${sectionActions}`;if(group.sectionField){const handle=head.querySelector('.df-section-drag-handle');handle?.addEventListener('pointerdown',e=>structureQueue(e,handle,'section',group.id,group.title));handle?.addEventListener('click',e=>{e.stopPropagation();});head.addEventListener('pointerdown',e=>{if(e.target.closest('button,a,input,select,textarea,label,.df-layout-section-chevron,.df-layout-structure-handle'))return;structureQueue(e,head,'section',group.id,group.title);});}"
rep(old,new,'section leading/full header drag')

# General never toggles closed.
old="const toggleSection=()=>{layoutSectionState.set(group.id,!wrap.classList.contains('is-open'));renderLayoutCanvas();};"
new="const toggleSection=()=>{if(group.id==='general')return;layoutSectionState.set(group.id,!wrap.classList.contains('is-open'));renderLayoutCanvas();};"
rep(old,new,'general toggle guard')

# Rows inside General remain permanently open.
old="const rowSelected=activeStructureSelection?.type==='row'&&Number(activeStructureSelection.row)===Number(model.rowNo),rowActive=rowSelected||model.items.some(([f])=>f.key===activeFieldKey),rowOpen=layoutRowState.has(model.rowNo)?layoutRowState.get(model.rowNo):(rowActive||(sectionOpen&&group.rows.length===1));"
new="const rowSelected=activeStructureSelection?.type==='row'&&Number(activeStructureSelection.row)===Number(model.rowNo),rowActive=rowSelected||model.items.some(([f])=>f.key===activeFieldKey),rowOpen=group.id==='general'?true:(layoutRowState.has(model.rowNo)?layoutRowState.get(model.rowNo):(rowActive||(sectionOpen&&group.rows.length===1)));"
rep(old,new,'general rows permanently open')

# No row collapse chevron in General; row title/header is also a drag surface.
old="rowHead.innerHTML=`${rowHandle}<span class=\"df-layout-row-chevron\">›</span><span class=\"df-layout-row-label\">${esc(rowTitle)}</span>${meta.description?`<span class=\"df-layout-structure-description\">${esc(meta.description)}</span>`:''}<span class=\"df-layout-row-summary\">${model.items.length} ${esc(structureUi.fields)} · ${esc(widths)}</span>${rowActions}`;\n   const rowDragHandle=rowHead.querySelector('.df-row-drag-handle');rowDragHandle?.addEventListener('pointerdown',e=>structureQueue(e,rowDragHandle,'row',model.rowNo,rowTitle));rowDragHandle?.addEventListener('click',e=>e.stopPropagation());"
new="const rowChevron=group.id==='general'?'':`<span class=\"df-layout-row-chevron\">›</span>`;rowHead.innerHTML=`${rowHandle}${rowChevron}<span class=\"df-layout-row-label\">${esc(rowTitle)}</span>${meta.description?`<span class=\"df-layout-structure-description\">${esc(meta.description)}</span>`:''}<span class=\"df-layout-row-summary\">${model.items.length} ${esc(structureUi.fields)} · ${esc(widths)}</span>${rowActions}`;\n   const rowDragHandle=rowHead.querySelector('.df-row-drag-handle');rowDragHandle?.addEventListener('pointerdown',e=>structureQueue(e,rowDragHandle,'row',model.rowNo,rowTitle));rowDragHandle?.addEventListener('click',e=>e.stopPropagation());rowHead.addEventListener('pointerdown',e=>{if(e.target.closest('button,a,input,select,textarea,label,.df-layout-row-chevron,.df-layout-structure-handle'))return;structureQueue(e,rowHead,'row',model.rowNo,rowTitle);});"
rep(old,new,'general row chevron/full header drag')

old="const toggleRow=()=>{layoutRowState.set(model.rowNo,!rowGroup.classList.contains('is-open'));renderLayoutCanvas();};"
new="const toggleRow=()=>{if(group.id==='general')return;layoutRowState.set(model.rowNo,!rowGroup.classList.contains('is-open'));renderLayoutCanvas();};"
rep(old,new,'general row toggle guard')

# UI alignment, larger grab target and clear draggable cursor.
marker='/* Forms 1.3.44: General base container + internal visual-line drop zones. */'
pos=s.find(marker)
if pos<0: raise SystemExit('1.3.45: 1.3.44 CSS marker missing')
css=r'''
/* Forms 1.3.45: permanent General rows + aligned drag affordances. */
.df-layout-section-head,.df-layout-row-head{gap:6px}
.df-layout-structure-handle,.df-layout-section-chevron,.df-layout-row-chevron{width:30px;height:30px;min-width:30px;flex:0 0 30px;display:inline-flex;align-items:center;justify-content:center;margin:0;padding:0}
.df-layout-structure-handle{border-radius:7px;cursor:grab;touch-action:none;color:var(--bs-secondary-color,#667085)}
.df-layout-structure-handle:hover,.df-layout-structure-handle:focus-visible{background:color-mix(in srgb,var(--df) 9%,transparent);color:var(--df);outline:none}
.df-layout-section-chevron,.df-layout-row-chevron{font-size:18px;line-height:1}
.df-layout-leading-spacer{width:66px;min-width:66px;flex:0 0 66px;height:30px;display:block}
.df-layout-section-group.is-section>.df-layout-section-head,.df-layout-row-head{cursor:grab}
.df-layout-section-group.is-section>.df-layout-section-head:active,.df-layout-row-head:active{cursor:grabbing}
.df-layout-section-group.is-general>.df-layout-section-head{cursor:default}
.df-layout-section-group.is-general>.df-layout-section-body{display:block!important}
.df-layout-section-group.is-general .df-layout-row-body{display:flex!important}
.df-layout-section-group.is-general .df-layout-row-group{overflow:visible}
.df-layout-section-group.is-general .df-layout-row-head{border-radius:8px}
.df-layout-section-group.is-general .df-layout-row-label{margin-left:0}
.df-layout-section-head button,.df-layout-row-head button{cursor:pointer}
@media(max-width:800px){.df-layout-structure-handle,.df-layout-section-chevron,.df-layout-row-chevron{width:34px;height:34px;min-width:34px;flex-basis:34px}.df-layout-leading-spacer{width:74px;min-width:74px;flex-basis:74px}}
'''
s=s[:pos]+css+'\n'+s[pos:]

# Runtime version.
s=s.replace("version:'1.3.44'","version:'1.3.45'")
s=s.replace('version: \"1.3.44\"','version: \"1.3.45\"')
p.write_text(s,encoding='utf-8')
PY

# Package/manifest versions.
find "$TMP/component" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.js' -o -name '*.json' \) -print0 | xargs -0 sed -i 's/1\.3\.44/1.3.45/g'
find "$TMP/outer" -maxdepth 1 -type f -name '*.xml' -print0 | xargs -0 sed -i 's/1\.3\.44/1.3.45/g'

# Syntax checks.
php -l "$B"
python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
matches=list(re.finditer(r'<script(?:\s[^>]*)?>(.*?)</script>',s,re.S|re.I))
Path('/tmp/forms-1345-builder.js').write_text('\n'.join(m.group(1) for m in matches),encoding='utf-8')
PY
node --check /tmp/forms-1345-builder.js

grep -q "group.id==='general'?true" "$B"
grep -q "df-layout-leading-spacer" "$B"
grep -q "structureQueue(e,rowHead,'row'" "$B"
grep -q "structureQueue(e,head,'section'" "$B"
grep -q "if(group.id==='general')return" "$B"
grep -q "duplicateLayoutSection" "$B"
grep -q "smartMoveLineRelative" "$B"

# Rebuild inner component zip.
rm -f "$TMP/outer/com_decaroforms_$OLD.zip"
(
  cd "$TMP/component"
  zip -qr "$TMP/outer/com_decaroforms_$NEW.zip" .
)

# Rename other nested packages carrying the old release version when present.
for f in "$TMP/outer"/*"$OLD"*.zip; do
  [ -e "$f" ] || continue
  nf="${f//$OLD/$NEW}"
  mv "$f" "$nf"
done

# Build outer package.
(
  cd "$TMP/outer"
  zip -qr "$TARGET" .
)

SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

# Update feed.
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

# Changelog prepend.
CHANGE="$ROOT/updates/changelog.xml"
if [ -f "$CHANGE" ]; then
python3 - "$CHANGE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
if '<version>1.3.45</version>' not in s:
    entry='''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>1.3.45</version>\n\t\t<note>Builder: Generale resta sempre aperto con righe visibili; allineamento icone strutturali; trascinamento Riga/Sezione disponibile anche dall’intestazione oltre al grip.</note>\n\t</changelog>'''
    pos=s.find('>')+1
    s=s[:pos]+entry+s[pos:]
    p.write_text(s,encoding='utf-8')
PY
fi

echo "Built $TARGET"
echo "SHA256 $SHA"
