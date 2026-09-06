#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.46"
NEW="1.3.47"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1347-builder.js' EXIT
mkdir -p "$TMP/outer" "$TMP/component" "$TMP/plugin" "$TARGET_DIR"
test -f "$BASE"
unzip -q "$BASE" -d "$TMP/outer"
COMP_OLD="$TMP/outer/com_decaroforms_$OLD.zip"
PLUGIN_OLD="$TMP/outer/plg_system_decaroforms_$OLD.zip"
test -f "$COMP_OLD"; test -f "$PLUGIN_OLD"
unzip -q "$COMP_OLD" -d "$TMP/component"
unzip -q "$PLUGIN_OLD" -d "$TMP/plugin"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
P="$TMP/plugin/src/Extension/FormsPlugin.php"
test -f "$B"; test -f "$P"

python3 - "$B" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
def rep(old,new,label,count=1):
    global s
    if old not in s: raise SystemExit(f'1.3.47: {label} anchor missing')
    s=s.replace(old,new,count)

# Generic empty-slot metadata helpers. No fake fields are created.
old="function smartAutoWidths(n){n=Math.max(1,Number(n)||1);if(n===1)return[100];if(n===2)return[50,50];if(n===3)return[33,33,34];if(n===4)return[25,25,25,25];const base=Math.floor(100/n),extra=100-base*n;return Array.from({length:n},(_,i)=>base+(i>=n-extra?1:0));}"
new=old+" function smartOffsetBefore(f){return Math.max(0,Math.min(90,Number(f?.config?.layout?.offset_before||0)||0));} function smartOffsetAfter(f){return Math.max(0,Math.min(90,Number(f?.config?.layout?.offset_after||0)||0));} function smartClearOffsets(f){if(!f)return;defaultFieldConfig(f);delete f.config.layout.offset_before;delete f.config.layout.offset_after;} function smartEffectiveWidth(f){return smartOffsetBefore(f)+Math.max(1,Math.min(100,Number(f?.config?.layout?.width||100)))+smartOffsetAfter(f);}"
rep(old,new,'slot helpers')

old="function visualLinesForItems(items){const lines=[];let line=[],total=0;(Array.isArray(items)?items:[]).forEach(entry=>{const f=entry?.[0],w=Math.max(1,Math.min(100,Number(f?.config?.layout?.width||100)));if(line.length&&total+w>101){lines.push(line);line=[];total=0;}line.push(entry);total+=w;if(total>=99){lines.push(line);line=[];total=0;}});if(line.length)lines.push(line);return lines;}"
new="function visualLinesForItems(items){const lines=[];let line=[],total=0;(Array.isArray(items)?items:[]).forEach(entry=>{const f=entry?.[0],span=smartEffectiveWidth(f);if(line.length&&total+span>101){lines.push(line);line=[];total=0;}line.push(entry);total+=span;if(total>=99){lines.push(line);line=[];total=0;}});if(line.length)lines.push(line);return lines;}"
rep(old,new,'visual lines with slots')

old="function normalizeVisualLines(row){const items=fieldsInRow(row);if(!items.length)return;const lines=visualLinesForItems(items);lines.forEach(line=>{if(!line.length)return;if(line.length===1){line[0][0].config.layout.width=100;return;}const widths=line.map(([f])=>Number(f.config?.layout?.width||0)),total=widths.reduce((a,b)=>a+b,0),valid=total>=99&&total<=101&&widths.every(w=>Number.isFinite(w)&&w>0&&w<100);if(!valid){const auto=smartAutoWidths(line.length);line.forEach(([f],i)=>f.config.layout.width=auto[i]??100);}});fieldsInRow(row).forEach(([f],i)=>f.config.layout.col=i+1);}"
new="function normalizeVisualLines(row){const items=fieldsInRow(row);if(!items.length)return;const lines=visualLinesForItems(items);lines.forEach(line=>{if(!line.length)return;if(line.length===1){const f=line[0][0],w=Math.max(1,Math.min(100,Number(f.config?.layout?.width||100))),before=smartOffsetBefore(f),after=smartOffsetAfter(f),total=before+w+after;if((before>0||after>0)&&total>=99&&total<=101)return;smartClearOffsets(f);f.config.layout.width=100;return;}const effective=line.reduce((n,[f])=>n+smartEffectiveWidth(f),0),hasSlots=line.some(([f])=>smartOffsetBefore(f)>0||smartOffsetAfter(f)>0);if(hasSlots&&effective>=99&&effective<=101)return;line.forEach(([f])=>smartClearOffsets(f));const widths=line.map(([f])=>Number(f.config?.layout?.width||0)),total=widths.reduce((a,b)=>a+b,0),valid=total>=99&&total<=101&&widths.every(w=>Number.isFinite(w)&&w>0&&w<100);if(!valid){const auto=smartAutoWidths(line.length);line.forEach(([f],i)=>f.config.layout.width=auto[i]??100);}});fieldsInRow(row).forEach(([f],i)=>f.config.layout.col=i+1);}"
rep(old,new,'normalize slots')

# A single field may now intentionally occupy part of a line.
old="function setFieldWidth(index,width){if(index==null||!selected[index])return;const field=selected[index],row=Number(field.config.layout.row||1),line=visualLineForField(field),members=line.map(([f])=>f);width=Math.max(10,Math.min(100,Number(width)||100));if(members.length<=1){field.config.layout.width=100;}else if(width===100){members.forEach(f=>f.config.layout.width=100);}else{field.config.layout.width=width;const others=members.filter(f=>f!==field),remaining=100-width,base=Math.floor(remaining/Math.max(1,others.length)),extra=remaining-base*Math.max(1,others.length);others.forEach((f,i)=>f.config.layout.width=Math.max(1,base+(i<extra?1:0)));}normalizeVisualLines(row);sync();renderSelected();renderLayoutCanvas();}"
new="function setFieldWidth(index,width){if(index==null||!selected[index])return;const field=selected[index],row=Number(field.config.layout.row||1),line=visualLineForField(field),members=line.map(([f])=>f);width=Math.max(10,Math.min(100,Number(width)||100));if(members.length<=1){const wasRight=smartOffsetBefore(field)>0;field.config.layout.width=width;if(width>=100){smartClearOffsets(field);field.config.layout.width=100;}else if(wasRight){field.config.layout.offset_before=100-width;delete field.config.layout.offset_after;}else{field.config.layout.offset_after=100-width;delete field.config.layout.offset_before;}}else if(width===100){members.forEach(f=>{smartClearOffsets(f);f.config.layout.width=100;});}else{members.forEach(f=>smartClearOffsets(f));field.config.layout.width=width;const others=members.filter(f=>f!==field),remaining=100-width,base=Math.floor(remaining/Math.max(1,others.length)),extra=remaining-base*Math.max(1,others.length);others.forEach((f,i)=>f.config.layout.width=Math.max(1,base+(i<extra?1:0)));}normalizeVisualLines(row);sync();renderSelected();renderLayoutCanvas();}"
rep(old,new,'single field width slots')

# Render actual empty slot affordances in Builder.
old="visualLines.forEach((line,lineIndex)=>{const row=document.createElement('div');row.className='df-layout-row';row.dataset.row=String(model.rowNo);row.dataset.line=String(lineIndex+1);row.style.gridTemplateColumns=line.map(([f])=>Math.max(10,Number(f.config.layout.width||100))+'fr').join(' ');line.forEach(([f,i])=>renderLayoutFieldCard(f,i,model.rowNo,row));row.addEventListener('dragover',e=>{if(e.target.closest('.df-layout-card'))return;e.preventDefault();row.classList.add('is-over');});"
new="visualLines.forEach((line,lineIndex)=>{const row=document.createElement('div');row.className='df-layout-row';row.dataset.row=String(model.rowNo);row.dataset.line=String(lineIndex+1);const parts=[];line.forEach(([f,i])=>{const before=smartOffsetBefore(f),after=smartOffsetAfter(f);if(before>0)parts.push({slot:true,width:before,side:'before'});parts.push({slot:false,width:Math.max(1,Number(f.config.layout.width||100)),f,i});if(after>0)parts.push({slot:true,width:after,side:'after'});});row.style.gridTemplateColumns=parts.map(part=>Math.max(1,Number(part.width||1))+'fr').join(' ');parts.forEach(part=>{if(part.slot){const slot=document.createElement('div');slot.className='df-layout-empty-slot';slot.innerHTML='<span>VUOTO '+Math.round(part.width)+'%</span>';row.appendChild(slot);}else renderLayoutFieldCard(part.f,part.i,model.rowNo,row);});row.addEventListener('dragover',e=>{if(e.target.closest('.df-layout-card'))return;e.preventDefault();row.classList.add('is-over');});"
rep(old,new,'render empty slots')

# Restore previews removes temporary slot UI.
old="layoutCanvas?.querySelectorAll('.df-smart-placeholder,.df-smart-newrow-preview,.df-smart-row-join-preview,.df-smart-line-preview').forEach(el=>el.remove());"
new="layoutCanvas?.querySelectorAll('.df-smart-placeholder,.df-smart-newrow-preview,.df-smart-row-join-preview,.df-smart-line-preview,.df-smart-slot-preview').forEach(el=>el.remove());"
rep(old,new,'restore slot preview')

# Empty source visual line: left/right creates a reserved half slot instead of generic join-row.
old="const row=stack.map(el=>el?.closest?.('.df-layout-row')).find(Boolean);if(row){card=smartNearestCardInRow(row,x,y);if(card)return smartClassifyCard(card,x,y);return{kind:'joinrow',row:Number(row.dataset.row||1)};}"
new="const row=stack.map(el=>el?.closest?.('.df-layout-row')).find(Boolean);if(row){card=smartNearestCardInRow(row,x,y);if(card)return smartClassifyCard(card,x,y);if(row===smartDrag.sourceRow||row.classList.contains('df-smart-source-line-empty')){const rr=row.getBoundingClientRect(),rx=(x-rr.left)/Math.max(1,rr.width);return{kind:'slot',row:Number(row.dataset.row||1),position:rx<.5?'left':'right'};}return{kind:'joinrow',row:Number(row.dataset.row||1)};}"
rep(old,new,'slot drop detection')

# Slot preview before normal beside preview.
old="if(spec.kind==='beside'){   const target=layoutCanvas?.querySelector(`.df-layout-card[data-field-key=\"${CSS.escape(spec.targetKey)}\"]`);"
new="if(spec.kind==='slot'){   const row=smartDrag.sourceRow;if(row){smartRememberGrid(row);row.style.gridTemplateColumns='1fr 1fr';const empty=document.createElement('div'),field=document.createElement('div');empty.className='df-smart-slot-preview is-empty';field.className='df-smart-slot-preview is-field';empty.innerHTML='<span>VUOTO 50%</span>';field.innerHTML=`<span>${esc(smartFieldByKey(smartDrag.fieldKey)?.label||'Campo')} · 50%</span>`;if(spec.position==='right'){row.append(empty,field);}else{row.append(field,empty);}}  }else if(spec.kind==='beside'){   const target=layoutCanvas?.querySelector(`.df-layout-card[data-field-key=\"${CSS.escape(spec.targetKey)}\"]`);"
rep(old,new,'slot preview')

# Reflow source/target lines: when a line loses a field, remaining members normalize and discard stale holes.
s=s.replace("sourceRest.forEach((f,i)=>f.config.layout.width=auto[i]??100);","sourceRest.forEach((f,i)=>{smartClearOffsets(f);f.config.layout.width=auto[i]??100;});")
s=s.replace("rest.forEach((f,i)=>f.config.layout.width=auto[i]??100);","rest.forEach((f,i)=>{smartClearOffsets(f);f.config.layout.width=auto[i]??100;});")

# Filling a side slot clears the reserved gap and distributes actual fields.
old="const newTargetLine=rowItems.filter(f=>targetMembers.includes(f)||f===field),auto=smartAutoWidths(newTargetLine.length);newTargetLine.forEach((f,i)=>f.config.layout.width=auto[i]??100);"
new="const newTargetLine=rowItems.filter(f=>targetMembers.includes(f)||f===field),auto=smartAutoWidths(newTargetLine.length);newTargetLine.forEach((f,i)=>{smartClearOffsets(f);f.config.layout.width=auto[i]??100;});"
rep(old,new,'fill reserved slot')

# Any vertical move creates a normal full-width line.
s=s.replace("field.config.layout={...(field.config.layout||{}),row:targetRow,col:at+1,width:100};targetItems.splice(at,0,field);","smartClearOffsets(field);field.config.layout={...(field.config.layout||{}),row:targetRow,col:at+1,width:100};targetItems.splice(at,0,field);")
s=s.replace("field.config.layout={...(field.config.layout||{}),row:insertRow,col:1,width:100};normalizeLayoutRows();","smartClearOffsets(field);field.config.layout={...(field.config.layout||{}),row:insertRow,col:1,width:100};normalizeLayoutRows();")

# Commit a reserved left/right half-slot for a lone visual line.
anchor="function smartMoveNewRow(index,targetRow,position='after'){"
if anchor not in s: raise SystemExit('1.3.47: smartMoveNewRow anchor missing')
slotfn="function smartMoveToSlot(index,position='left'){if(index<0||!selected[index])return false;const field=selected[index],line=visualLineForField(field).map(([f])=>f);if(line.length!==1)return false;field.config.layout.width=50;if(position==='right'){field.config.layout.offset_before=50;delete field.config.layout.offset_after;}else{field.config.layout.offset_after=50;delete field.config.layout.offset_before;}normalizeVisualLines(Number(field.config.layout.row||1));activeStructureSelection=null;activeFieldKey=field.key;return true;} "
s=s.replace(anchor,slotfn+anchor,1)
old="let changed=false;if(spec.kind==='beside'){"
new="let changed=false;if(spec.kind==='slot')changed=smartMoveToSlot(index,spec.position);else if(spec.kind==='beside'){"
rep(old,new,'commit slot')

# Consistent action colors: Edit and Duplicate neutral; Delete semantic red.
css=r'''
/* Forms 1.3.47: smart empty slots + consistent action colors. */
.df-layout-empty-slot{min-width:0;min-height:44px;display:flex;align-items:center;justify-content:center;border:1.5px dashed color-mix(in srgb,#7c3aed 42%,var(--df-border));border-radius:8px;background:color-mix(in srgb,#7c3aed 3%,transparent);color:var(--bs-secondary-color,#667085);font-size:10px;font-weight:850;letter-spacing:.035em;pointer-events:none}
.df-smart-slot-preview{min-width:0;min-height:44px;display:flex;align-items:center;justify-content:center;border:1.5px dashed #7c3aed;border-radius:8px;background:color-mix(in srgb,#7c3aed 7%,var(--bs-body-bg,#fff));font-size:10px;font-weight:900;color:#6d28d9;pointer-events:none}
.df-smart-slot-preview.is-field{border-style:solid}
.df-layout-section-actions [data-section-edit],.df-layout-section-actions [data-section-copy],.df-layout-row-actions [data-row-edit],.df-layout-row-actions [data-row-copy],.df-mini-actions [data-row-copy]{color:var(--bs-secondary-color,#59636f)!important}
.df-layout-section-actions [data-section-remove],.df-layout-row-actions [data-row-remove],.df-mini-actions [data-row-remove],.df-mini-actions [data-structure-remove]{color:#dc3545!important}
[data-bs-theme="dark"] .df-layout-empty-slot{background:color-mix(in srgb,#7c3aed 7%,transparent);color:#aeb7c4}
'''
marker='/* Forms 1.3.46: real accordions + uniform destructive actions. */'
pos=s.find(marker)
if pos<0: raise SystemExit('1.3.47: CSS marker missing')
s=s[:pos]+css+'\n'+s[pos:]

s=s.replace("version:'1.3.46'","version:'1.3.47'")
s=s.replace('version: \"1.3.46\"','version: \"1.3.47\"')
p.write_text(s,encoding='utf-8')
PY

# Frontend: persist visual empty space using margins, not fake fields.
python3 - "$P" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
def rep(old,new,label,count=1):
    global s
    if old not in s: raise SystemExit(f'1.3.47 plugin: {label} anchor missing')
    s=s.replace(old,new,count)
rep("#'.$uid.' .df-field{width:var(--df-field-width,100%);padding:0 7px;margin-bottom:15px}","#'.$uid.' .df-field{width:var(--df-field-width,100%);padding:0 7px;margin-left:var(--df-field-offset-before,0%);margin-right:var(--df-field-offset-after,0%);margin-bottom:15px}",'field slot CSS')
rep("($mobileStack ? '#'.$uid.' .df-field{width:100%!important}' : '')","($mobileStack ? '#'.$uid.' .df-field{width:100%!important;margin-left:0!important;margin-right:0!important}' : '')",'mobile slot reset')
old="$style = '--df-field-width:' . $this->fieldWidth($field) . '%';"
new="$layoutCfg = is_array($cfg['layout'] ?? null) ? $cfg['layout'] : [];\n        $offsetBefore = max(0, min(90, (int) ($layoutCfg['offset_before'] ?? 0)));\n        $offsetAfter = max(0, min(90, (int) ($layoutCfg['offset_after'] ?? 0)));\n        $style = '--df-field-width:' . $this->fieldWidth($field) . '%;--df-field-offset-before:' . $offsetBefore . '%;--df-field-offset-after:' . $offsetAfter . '%';"
rep(old,new,'field style offsets')
p.write_text(s,encoding='utf-8')
PY

# Update versions across component/plugin/package manifests and source strings.
find "$TMP/component" "$TMP/plugin" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.js' -o -name '*.json' \) -print0 | xargs -0 sed -i 's/1\.3\.46/1.3.47/g'
find "$TMP/outer" -maxdepth 1 -type f -name '*.xml' -print0 | xargs -0 sed -i 's/1\.3\.46/1.3.47/g'

php -l "$B"
php -l "$P"
python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
js='\n'.join(m.group(1) for m in re.finditer(r'<script(?:\s[^>]*)?>(.*?)</script>',s,re.S|re.I))
js=re.sub(r'<\?(?:php|=).*?\?>','null',js,flags=re.S|re.I)
Path('/tmp/forms-1347-builder.js').write_text(js,encoding='utf-8')
PY
node --check /tmp/forms-1347-builder.js

# Regression checks.
grep -q "function smartMoveToSlot" "$B"
grep -q "offset_before" "$B"
grep -q "offset_after" "$B"
grep -q "df-layout-empty-slot" "$B"
grep -q "df-smart-slot-preview" "$B"
grep -q "spec.kind==='slot'" "$B"
grep -q "smartMoveLineRelative" "$B"
grep -q "duplicateLayoutSection" "$B"
grep -q "data-section-remove" "$B"
grep -q "data-row-remove" "$B"
grep -q "df-field-offset-before" "$P"
grep -q "df-field-offset-after" "$P"
grep -q "margin-left:0!important;margin-right:0!important" "$P"

# Rebuild nested component/plugin packages.
rm -f "$TMP/outer/com_decaroforms_$OLD.zip" "$TMP/outer/plg_system_decaroforms_$OLD.zip"
(cd "$TMP/component" && zip -qr "$TMP/outer/com_decaroforms_$NEW.zip" .)
(cd "$TMP/plugin" && zip -qr "$TMP/outer/plg_system_decaroforms_$NEW.zip" .)

# Rename any other versioned nested zips.
for f in "$TMP/outer"/*"$OLD"*.zip; do
  [ -e "$f" ] || continue
  nf="${f//$OLD/$NEW}"
  mv "$f" "$nf"
done

(cd "$TMP/outer" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

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

CHANGE="$ROOT/updates/changelog.xml"
if [ -f "$CHANGE" ]; then
python3 - "$CHANGE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
if '<version>1.3.47</version>' not in s:
    entry='''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>1.3.47</version>\n\t\t<note>Builder: smart drag con slot vuoti reali; campo singolo a sinistra/destra crea 50% + spazio libero, riempimento automatico con il secondo campo, supporto frontend degli offset e colori azioni uniformi.</note>\n\t</changelog>'''
    pos=s.find('>')+1; s=s[:pos]+entry+s[pos:]; p.write_text(s,encoding='utf-8')
PY
fi

echo "Built $TARGET"
echo "SHA256 $SHA"
