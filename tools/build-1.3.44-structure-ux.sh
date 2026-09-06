#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.43"
NEW="1.3.44"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1344-builder.js' EXIT
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
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')

def replace_between(start,end,new,label):
    global s
    a=s.find(start)
    if a<0: raise SystemExit(f'1.3.44: {label} start missing')
    b=s.find(end,a+len(start))
    if b<0: raise SystemExit(f'1.3.44: {label} end missing')
    s=s[:a]+new+s[b:]

# ---------------------------------------------------------------------------
# 1) General is the permanent neutral base container.
# ---------------------------------------------------------------------------
new_groups=r'''function layoutGroups(){
 const rows=[...new Set(selected.map(f=>Number(f.config.layout.row||1)))].sort((a,b)=>a-b).map(rowNo=>({rowNo,items:fieldsInRow(rowNo)}));
 const groups=[];let current={id:'general',sectionField:null,title:structureUi.general,rows:[]};
 rows.forEach(model=>{const marker=model.items.find(([f])=>isLayoutSectionField(f));if(marker){if(current.id==='general'||current.rows.length||current.sectionField)groups.push(current);const [sf,si]=marker;current={id:'section:'+sf.key,sectionField:marker,title:layoutSectionTitle(sf),rows:[]};const rest=model.items.filter(x=>x!==marker);if(rest.length)current.rows.push({rowNo:model.rowNo,items:rest});}else current.rows.push(model);});
 if(current.rows.length||current.sectionField||current.id==='general'||!groups.length)groups.push(current);
 if(!groups.some(g=>g.id==='general'))groups.unshift({id:'general',sectionField:null,title:structureUi.general,rows:[]});
 return groups;
}

'''
replace_between('function layoutGroups(){','function renderLayoutCanvas(){',new_groups,'layoutGroups')

old_empty=" if(!selected.length){layoutCanvas.innerHTML='<div class=\"df-layout-empty\">Il modulo è vuoto. Premi “Aggiungi campo” per iniziare.</div>';return;}\n const groups=layoutGroups();"
new_empty=" const groups=layoutGroups();"
if old_empty not in s: raise SystemExit('1.3.44: empty Builder return anchor missing')
s=s.replace(old_empty,new_empty,1)

old_wrap="const wrap=document.createElement('div');wrap.className='df-layout-section-group'+(sectionOpen?' is-open':'');wrap.dataset.sectionId=group.id;"
new_wrap="const wrap=document.createElement('div');wrap.className='df-layout-section-group'+(group.id==='general'?' is-general':' is-section')+(sectionOpen?' is-open':'');wrap.dataset.sectionId=group.id;"
if old_wrap not in s: raise SystemExit('1.3.44: section wrap anchor missing')
s=s.replace(old_wrap,new_wrap,1)

old_section_empty="if(!group.rows.length){const empty=document.createElement('div');empty.className='df-layout-section-empty';empty.textContent='Sezione vuota';body.appendChild(empty);}"
new_section_empty="if(!group.rows.length){const empty=document.createElement('div');empty.className='df-layout-section-empty';empty.textContent=group.id==='general'?'Nessun campo generale':'Sezione vuota';body.appendChild(empty);}"
if old_section_empty not in s: raise SystemExit('1.3.44: section empty anchor missing')
s=s.replace(old_section_empty,new_section_empty,1)

# ---------------------------------------------------------------------------
# 2) Duplicate a real section as a sibling block, with all rows/fields/meta.
#    References to cloned field keys are remapped inside cloned configs.
# ---------------------------------------------------------------------------
anchor='function structureMoveSection('
pos=s.find(anchor)
if pos<0: raise SystemExit('1.3.44: structureMoveSection anchor missing')
section_duplicate=r'''function remapSectionCloneRefs(value,keyMap){
 if(Array.isArray(value))return value.map(v=>remapSectionCloneRefs(v,keyMap));
 if(value&&typeof value==='object'){Object.keys(value).forEach(k=>{value[k]=remapSectionCloneRefs(value[k],keyMap);});return value;}
 if(typeof value==='string'&&keyMap.has(value))return keyMap.get(value);
 return value;
}
function duplicateLayoutSection(sectionId){
 if(!sectionId||sectionId==='general')return false;
 const blocks=structureRowBlocks(),range=structureSectionRange(blocks,sectionId);if(!range||range.start>=range.end)return false;
 const source=blocks.slice(range.start,range.end),used=new Set(selected.map(f=>String(f.key||''))),keyMap=new Map(),pairs=[];
 const reserveKey=base=>{const stem=String(base||'field').replace(/[^a-zA-Z0-9_]+/g,'_')||'field';let n=2,k=`${stem}_${n}`;while(used.has(k)){n++;k=`${stem}_${n}`;}used.add(k);return k;};
 source.forEach(block=>block.fields.forEach(f=>{const cf=clone(f),oldKey=String(f.key||'');cf.key=reserveKey(oldKey);if(oldKey)keyMap.set(oldKey,cf.key);pairs.push({original:f,copy:cf});}));
 pairs.forEach(({copy})=>{const keepKey=copy.key;remapSectionCloneRefs(copy,keyMap);copy.key=keepKey;defaultFieldConfig(copy);});
 let pi=0,newSectionKey='';
 const clones=source.map(block=>{const fields=block.fields.map(()=>pairs[pi++].copy),marker=fields.find(isLayoutSectionField);if(marker&&!newSectionKey){marker.label=`${String(marker.label||structureUi.section).trim()||structureUi.section} copia`;newSectionKey=marker.key;}return{rowNo:0,fields,meta:block.meta?clone(block.meta):null,sectionKey:marker?.key||null};});
 blocks.splice(range.end,0,...clones);structureApplyBlocks(blocks);normalizeLayoutRows();sortSelectedByLayout();activeStructureSelection=null;activeFieldKey=newSectionKey||clones.flatMap(b=>b.fields)[0]?.key||null;if(newSectionKey)layoutSectionState.set('section:'+newSectionKey,true);sync();renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();clearTimeout(historyTimer);pushHistory();return true;
}
'''
s=s[:pos]+section_duplicate+s[pos:]

old_copy="head.querySelector('[data-section-copy]').onclick=e=>{e.stopPropagation();duplicateField(si);};"
new_copy="head.querySelector('[data-section-copy]').onclick=e=>{e.stopPropagation();duplicateLayoutSection(group.id);};"
if old_copy not in s: raise SystemExit('1.3.44: section duplicate handler anchor missing')
s=s.replace(old_copy,new_copy,1)

# ---------------------------------------------------------------------------
# 3) Smart drag: left/right = same visual line; top/bottom = a new 100% line
#    inside the SAME logical row. Row empty area still appends to that row.
# ---------------------------------------------------------------------------
new_restore=r'''function smartRestorePreviewDom(){
 layoutCanvas?.querySelectorAll('.df-smart-placeholder,.df-smart-newrow-preview,.df-smart-row-join-preview,.df-smart-line-preview').forEach(el=>el.remove());
 layoutCanvas?.querySelectorAll('.df-smart-target-left,.df-smart-target-right,.df-smart-row-target-before,.df-smart-row-target-after,.df-smart-row-join-target,.df-smart-line-target-before,.df-smart-line-target-after').forEach(el=>el.classList.remove('df-smart-target-left','df-smart-target-right','df-smart-row-target-before','df-smart-row-target-after','df-smart-row-join-target','df-smart-line-target-before','df-smart-line-target-after'));
 layoutCanvas?.querySelectorAll('.df-layout-row[data-smart-original-grid]').forEach(row=>{row.style.gridTemplateColumns=row.getAttribute('data-smart-original-grid')||'';row.removeAttribute('data-smart-original-grid');});
 layoutCanvas?.querySelectorAll('.df-smart-source-row-empty').forEach(el=>el.classList.remove('df-smart-source-row-empty'));
 layoutCanvas?.querySelectorAll('.df-smart-source-line-empty').forEach(el=>el.classList.remove('df-smart-source-line-empty'));
 if(smartDrag.active)smartReflowSourceRow();
}
'''
replace_between('function smartRestorePreviewDom(){','function smartReflowSourceRow(',new_restore,'smartRestorePreviewDom')

new_preview=r'''function smartRenderPreview(spec){const id=smartSpecId(spec);if(id===smartDrag.specKey)return;const before=smartCaptureRects();smartRestorePreviewDom();smartDrag.spec=spec;smartDrag.specKey=id;if(!spec){smartAnimateFrom(before);return;}
 if(spec.kind==='beside'){
  const target=layoutCanvas?.querySelector(`.df-layout-card[data-field-key="${CSS.escape(spec.targetKey)}"]`);if(target){const row=target.closest('.df-layout-row'),ph=document.createElement('div');ph.className='df-smart-placeholder '+(spec.position==='before'?'is-left':'is-right');ph.innerHTML=`<span>${spec.position==='before'?'SINISTRA':'DESTRA'}</span>`;if(spec.position==='before')target.before(ph);else target.after(ph);target.classList.add(spec.position==='before'?'df-smart-target-left':'df-smart-target-right');smartSetGrid(row,smartPreviewBesideWidths(spec));}
 }else if(spec.kind==='line'){
  const target=layoutCanvas?.querySelector(`.df-layout-card[data-field-key="${CSS.escape(spec.targetKey)}"]`),line=target?.closest('.df-layout-row');if(line){const ph=document.createElement('div'),title=rowMeta(Number(spec.row)).title||`Riga ${Number(spec.row)}`;ph.className='df-smart-line-preview';ph.innerHTML=`<span class="df-smart-line-label">AGGIUNGI A ${esc(title).toUpperCase()} · ${spec.position==='before'?'SOPRA':'SOTTO'}</span><span class="df-smart-line-field">${esc(smartFieldByKey(smartDrag.fieldKey)?.label||'Campo')} · 100%</span>`;if(spec.position==='before')line.before(ph);else line.after(ph);line.classList.add(spec.position==='before'?'df-smart-line-target-before':'df-smart-line-target-after');}
 }else if(spec.kind==='joinrow'){
  const group=layoutCanvas?.querySelector(`.df-layout-row-group[data-row-no="${Number(spec.row)}"]`);if(group){const ph=document.createElement('div'),title=rowMeta(Number(spec.row)).title||`Riga ${Number(spec.row)}`;ph.className='df-smart-row-join-preview';ph.innerHTML=`<span class="df-smart-row-join-label">AGGIUNGI A ${esc(title).toUpperCase()}</span><span class="df-smart-row-join-field">${esc(smartFieldByKey(smartDrag.fieldKey)?.label||'Campo')} · 100%</span>`;group.classList.add('df-smart-row-join-target');(group.querySelector('.df-layout-row-body')||group).appendChild(ph);}
 }else if(spec.kind==='newrow'){
  const group=layoutCanvas?.querySelector(`.df-layout-row-group[data-row-no="${Number(spec.row)}"]`);if(group){const ph=document.createElement('div');ph.className='df-smart-newrow-preview';ph.innerHTML=`<span class="df-smart-newrow-label">${spec.position==='before'?'SOPRA':'SOTTO'} · NUOVA RIGA</span><span class="df-smart-newrow-field">${esc(smartFieldByKey(smartDrag.fieldKey)?.label||'Campo')} · 100%</span>`;if(spec.position==='before')group.before(ph);else group.after(ph);group.classList.add(spec.position==='before'?'df-smart-row-target-before':'df-smart-row-target-after');}
 }else if(spec.kind==='append'){
  const ph=document.createElement('div');ph.className='df-smart-newrow-preview is-append';ph.innerHTML=`<span class="df-smart-newrow-label">NUOVA RIGA</span><span class="df-smart-newrow-field">${esc(smartFieldByKey(smartDrag.fieldKey)?.label||'Campo')} · 100%</span>`;layoutCanvas?.appendChild(ph);
 }
 smartAnimateFrom(before);
}
'''
replace_between('function smartRenderPreview(','function smartClassifyCard(',new_preview,'smartRenderPreview')

new_classify=r'''function smartClassifyCard(card,x,y){if(!card||card.dataset.fieldKey===smartDrag.fieldKey)return null;const target=smartFieldByKey(card.dataset.fieldKey),source=smartFieldByKey(smartDrag.fieldKey);if(!target||!source)return null;const r=card.getBoundingClientRect(),rx=(x-r.left)/Math.max(1,r.width),ry=(y-r.top)/Math.max(1,r.height),targetLine=visualLineForField(target).map(([f])=>f),sourceInLine=targetLine.includes(source),count=targetLine.filter(f=>f!==source).length+(sourceInLine?0:1),canSide=count<=4,row=Number(target.config?.layout?.row||1);
 if(canSide&&rx<=.24)return{kind:'beside',targetKey:target.key,row,position:'before'};
 if(canSide&&rx>=.76)return{kind:'beside',targetKey:target.key,row,position:'after'};
 return{kind:'line',row,targetKey:target.key,position:ry<.5?'before':'after'};
}
'''
replace_between('function smartClassifyCard(','function smartNearestCardInRow(',new_classify,'smartClassifyCard')

# Insert line-relative move before the existing row-append helper.
anchor='function smartMoveToExistingRow('
pos=s.find(anchor)
if pos<0: raise SystemExit('1.3.44: smartMoveToExistingRow anchor missing')
line_move=r'''function smartMoveLineRelative(index,targetKey,position='after'){if(index<0||!selected[index]||!targetKey)return false;const field=selected[index],target=smartFieldByKey(targetKey);if(!target||target===field)return false;const oldRow=Number(field.config?.layout?.row||1),targetRow=Number(target.config?.layout?.row||1),sourceLine=visualLineForField(field).map(([f])=>f),sourceRest=sourceLine.filter(f=>f!==field);if(sourceRest.length){const auto=smartAutoWidths(sourceRest.length);sourceRest.forEach((f,i)=>f.config.layout.width=auto[i]??100);}const targetLine=visualLineForField(target).map(([f])=>f).filter(f=>f!==field),targetItems=fieldsInRow(targetRow).map(([f])=>f).filter(f=>f!==field);if(!targetLine.length)return smartMoveToExistingRow(index,targetRow,targetKey);let first=targetItems.indexOf(targetLine[0]),last=targetItems.indexOf(targetLine[targetLine.length-1]);if(first<0||last<0)return smartMoveToExistingRow(index,targetRow,targetKey);const at=position==='before'?first:last+1;field.config.layout={...(field.config.layout||{}),row:targetRow,col:at+1,width:100};targetItems.splice(at,0,field);setLogicalRowOrder(targetRow,targetItems);normalizeLayoutRows();sortSelectedByLayout();if(selected.some(f=>Number(f.config?.layout?.row||1)===oldRow))normalizeVisualLines(oldRow);normalizeVisualLines(targetRow);activeStructureSelection=null;activeFieldKey=field.key;return true;}
'''
s=s[:pos]+line_move+s[pos:]

new_commit=r'''function smartCommitSpec(spec,key){const index=smartFieldIndex(key);if(index<0||!spec)return false;let changed=false;if(spec.kind==='beside'){const ti=smartFieldIndex(spec.targetKey);changed=smartMoveBeside(index,ti,spec.position);}else if(spec.kind==='line')changed=smartMoveLineRelative(index,spec.targetKey,spec.position);else if(spec.kind==='joinrow')changed=smartMoveToExistingRow(index,Number(spec.row),spec.targetKey||null);else if(spec.kind==='newrow')changed=smartMoveNewRow(index,Number(spec.row),spec.position);else if(spec.kind==='append'){const max=Math.max(1,...selected.map(f=>Number(f.config?.layout?.row||1)));changed=smartMoveNewRow(index,max,'after');}if(changed){sortSelectedByLayout();sync();renderSelected();clearTimeout(historyTimer);pushHistory();}return changed;}
'''
replace_between('function smartCommitSpec(','function smartEndVisual(',new_commit,'smartCommitSpec')

# ---------------------------------------------------------------------------
# 4) UI: General neutral, line drop previews clear, responsive/dark compatible.
# ---------------------------------------------------------------------------
css=r'''
/* Forms 1.3.44: General base container + internal visual-line drop zones. */
.df-layout-section-group.is-general{border-style:dashed;background:color-mix(in srgb,var(--bs-secondary-bg,#f4f6f8) 35%,var(--bs-body-bg,#fff))}
.df-layout-section-group.is-general>.df-layout-section-head{background:transparent}.df-layout-section-group.is-general>.df-layout-section-head:hover{background:color-mix(in srgb,var(--bs-secondary-bg,#eef1f4) 60%,transparent)}
.df-layout-section-group.is-general .df-layout-section-title strong{font-weight:800}.df-layout-section-group.is-general .df-layout-section-empty{color:var(--bs-secondary-color,#667085)}
.df-smart-line-preview{display:flex;align-items:center;justify-content:space-between;gap:10px;min-height:42px;margin:5px 4px;padding:8px 10px;border:2px dashed var(--df);border-radius:8px;background:color-mix(in srgb,var(--df) 6%,var(--bs-body-bg,#fff));color:var(--df);pointer-events:none}
.df-smart-line-label{font-size:10px;font-weight:950;letter-spacing:.045em}.df-smart-line-field{min-width:0;max-width:58%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:11px;font-weight:800;color:var(--bs-body-color,#1f2937)}
.df-smart-line-target-before{box-shadow:inset 0 3px 0 var(--df)}.df-smart-line-target-after{box-shadow:inset 0 -3px 0 var(--df)}
@media(max-width:800px){.df-smart-line-preview{margin:5px 2px}.df-smart-line-field{max-width:48%}}
'''
style_end=s.rfind('</style>')
if style_end<0: raise SystemExit('1.3.44: closing style tag missing')
s=s[:style_end]+css+s[style_end:]

# Runtime marker.
if "version:'1.3.43'" not in s: raise SystemExit('1.3.44: runtime marker missing')
s=s.replace("version:'1.3.43'","version:'1.3.44'")

# Regression guards.
assert "duplicateField(si)" not in s
assert "duplicateLayoutSection(group.id)" in s
assert "function duplicateLayoutSection(" in s
assert "function smartMoveLineRelative(" in s
assert "spec.kind==='line'" in s
assert "kind:'line'" in s
assert "df-smart-line-preview" in s
assert "group.id==='general'?'Nessun campo generale':'Sezione vuota'" in s
assert "group.id==='general'?' is-general':' is-section'" in s
assert ".df-smart-source-row-empty{display:none!important}" not in s
assert "version:'1.3.44'" in s

p.write_text(s,encoding='utf-8')
PY

# Keep metadata/version coherent across the component.
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$TMP/component" || true)
php -l "$B" >/dev/null

# Syntax-check the Builder helper region.
python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
a=s.find('function fieldsInRow(')
if a<0: raise SystemExit('1.3.44: helper block start missing')
ends=[x for x in (s.find('const aiAllowedTypes=',a),s.find('const aiWidths=',a),s.find('function aiOpen(',a)) if x>=0]
b=min(ends) if ends else min(len(s),a+260000)
js=re.sub(r'<\?php.*?\?>','null',s[a:b],flags=re.S)
Path('/tmp/forms-1344-builder.js').write_text(js,encoding='utf-8')
PY
node --check /tmp/forms-1344-builder.js >/dev/null

# Exact regression checks for the approved Builder behavior.
python3 - "$B" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
required=[
 "function duplicateLayoutSection(",
 "function smartMoveLineRelative(",
 "return{kind:'line'",
 "spec.kind==='line'",
 "AGGIUNGI A ${esc(title).toUpperCase()} · ${spec.position==='before'?'SOPRA':'SOTTO'}",
 "Nessun campo generale",
 " is-general",
 "function smartReflowSourceRow()",
 "function sortSelectedByLayout("
]
missing=[x for x in required if x not in s]
if missing: raise SystemExit('1.3.44 missing regression markers: '+', '.join(missing))
assert "duplicateField(si)" not in s
assert "version:'1.3.44'" in s
print('1.3.44 structure UX regression checks OK')
PY

# Rebuild component ZIP.
rm -f "$COMP_OLD"
(cd "$TMP/component" && zip -qr "$TMP/outer/com_decaroforms_$NEW.zip" .)

# Rebuild other nested extension ZIPs with version-only changes.
for z in "$TMP/outer"/*_"$OLD".zip; do
  [ -e "$z" ] || continue
  work="$TMP/sub-$(basename "$z" .zip)"
  mkdir -p "$work"
  unzip -q "$z" -d "$work"
  while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$work" || true)
  newz="${z/$OLD/$NEW}"
  rm -f "$newz"
  (cd "$work" && zip -qr "$newz" .)
  rm -f "$z"
done
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -Il -- "$OLD" "$TMP/outer"/* 2>/dev/null || true)

rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
unzip -tq "$TARGET" >/dev/null
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update><name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description><element>pkg_decaroforms</element><type>package</type><client>site</client><version>$NEW</version><downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/$NEW/pkg_decaroforms_$NEW.zip</downloadurl></downloads><changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags><maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl><targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256></update></updates>
EOF
cat > "$ROOT/updates/changelog.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog><element>pkg_decaroforms</element><type>package</type><version>$NEW</version><security><item>No security changes.</item></security><fix><item>Make General the permanent neutral base container of the Builder, without section move/copy/delete actions.</item><item>Duplicate a section as a complete sibling block, preserving its rows, fields, widths, row metadata and remapping cloned field references.</item><item>Add clear internal-line drop targets: top/bottom of a field creates a 100% line above/below inside the same logical row; left/right keeps smart same-line sizing.</item><item>Preserve the 1.3.42 Add-field hotfix and the 1.3.43 drag-visibility fix.</item></fix></changelog></changelogs>
EOF

echo "Built $TARGET"
echo "SHA256 $SHA"
