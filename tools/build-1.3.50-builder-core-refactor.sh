#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.49"
NEW="1.3.50"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1350-builder.js' EXIT
mkdir -p "$TMP/outer" "$TMP/component" "$TARGET_DIR"
test -f "$BASE"
unzip -q "$BASE" -d "$TMP/outer"
COMP_OLD="$TMP/outer/com_decaroforms_$OLD.zip"
test -f "$COMP_OLD"
unzip -q "$COMP_OLD" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
C="$TMP/component/administrator/components/com_decaroforms/src/Controller/BuilderController.php"
test -f "$B"
test -f "$C"

python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')

def sub_between(start_marker,end_marker,replacement,label):
    global s
    a=s.find(start_marker)
    if a<0: raise SystemExit(f'1.3.50 missing start: {label}')
    b=s.find(end_marker,a)
    if b<0: raise SystemExit(f'1.3.50 missing end: {label}')
    s=s[:a]+replacement+s[b:]

def replace_once(old,new,label):
    global s
    if old not in s: raise SystemExit(f'1.3.50 missing anchor: {label}')
    s=s.replace(old,new,1)

# Stable logical-row identity. row_meta becomes the persisted row registry; numeric row is position only.
sub_between(
"function rowMeta(rowNo){",
"function renderSectionSettings",
'''function newRowId(){try{if(globalThis.crypto?.randomUUID)return 'row_'+globalThis.crypto.randomUUID();}catch(e){}return 'row_'+Date.now().toString(36)+'_'+Math.random().toString(36).slice(2,10);}\nfunction rowMetaStore(){builderConfig=builderConfig&&typeof builderConfig==='object'?builderConfig:{};builderConfig.layout=builderConfig.layout&&typeof builderConfig.layout==='object'?builderConfig.layout:{};builderConfig.layout.row_meta=builderConfig.layout.row_meta&&typeof builderConfig.layout.row_meta==='object'?builderConfig.layout.row_meta:{};return builderConfig.layout.row_meta;}\nfunction rowMeta(rowNo){rowNo=Math.max(1,Number(rowNo)||1);const store=rowMetaStore(),key=String(rowNo),meta=store[key]&&typeof store[key]==='object'?store[key]:{};if(!meta.id)meta.id=newRowId();if(typeof meta.title!=='string')meta.title='';if(typeof meta.description!=='string')meta.description='';store[key]=meta;return meta;}\nfunction rowIdForRow(rowNo){return String(rowMeta(rowNo).id||'');}\nfunction rowNoForId(id){id=String(id||'');if(!id)return 0;const store=rowMetaStore();for(const [k,meta] of Object.entries(store)){if(meta&&String(meta.id||'')===id){const n=Number(k);if(Number.isFinite(n)&&n>0)return n;}}return 0;}\nfunction logicalRowNumbers(){const fieldRows=selected.map(f=>Number(f.config?.layout?.row||1)).filter(n=>Number.isFinite(n)&&n>0),metaRows=Object.keys(rowMetaStore()).map(Number).filter(n=>Number.isFinite(n)&&n>0);return [...new Set([...fieldRows,...metaRows])].sort((a,b)=>a-b);}\nfunction refreshActiveRowSelection(){if(activeStructureSelection?.type!=='row')return;if(activeStructureSelection.id){const n=rowNoForId(activeStructureSelection.id);if(n){activeStructureSelection.row=n;return;}activeStructureSelection=null;return;}const n=Math.max(1,Number(activeStructureSelection.row)||1);activeStructureSelection.id=rowIdForRow(n);activeStructureSelection.row=n;}\nfunction renderSectionSettings''',
"row identity helpers"
)

# Preserve stable IDs and truly empty logical rows during normalization.
sub_between(
"function normalizeLayoutRows(){",
"function sortSelectedByLayout",
'''function normalizeLayoutRows(){builderConfig=builderConfig&&typeof builderConfig==='object'?builderConfig:{};builderConfig.layout=builderConfig.layout&&typeof builderConfig.layout==='object'?builderConfig.layout:{};const oldMeta=rowMetaStore(),rows=logicalRowNumbers();if(!rows.length){builderConfig.layout.row_meta={};activeStructureSelection=null;return;}const map=new Map(rows.map((r,i)=>[r,i+1])),nextMeta={};rows.forEach(r=>{const nr=map.get(r),meta=oldMeta[String(r)]&&typeof oldMeta[String(r)]==='object'?oldMeta[String(r)]:null;if(meta){if(!meta.id)meta.id=newRowId();if(typeof meta.title!=='string')meta.title='';if(typeof meta.description!=='string')meta.description='';nextMeta[String(nr)]=meta;}});builderConfig.layout.row_meta=nextMeta;selected.forEach(f=>{defaultFieldConfig(f);f.config.layout.row=map.get(Number(f.config.layout.row||1))||1;});for(const row of logicalRowNumbers()){selected.filter(f=>Number(f.config.layout.row||1)===Number(row)).sort((a,b)=>(a.config.layout.col||1)-(b.config.layout.col||1)).forEach((f,i)=>f.config.layout.col=i+1);normalizeVisualLines(row);}refreshActiveRowSelection();const validIds=new Set(Object.values(builderConfig.layout.row_meta||{}).map(meta=>String(meta?.id||'')).filter(Boolean));for(const id of [...layoutRowState.keys()])if(!validIds.has(String(id)))layoutRowState.delete(id);}\nfunction sortSelectedByLayout''',
"normalizeLayoutRows"
)

# Removing a section marker must not leave a phantom empty row registry entry.
sub_between(
"function removeCanvasField(index){",
"function moveFieldToRow",
'''function removeCanvasField(index){if(index==null||!selected[index])return;const field=selected[index],old=field.key,oldRow=Number(field.config.layout.row||1),wasSection=isLayoutSectionField(field),line=visualLineForField(field),rest=line.map(([f])=>f).filter(f=>f!==field);if(rest.length){const auto=smartAutoWidths(rest.length);rest.forEach((f,i)=>{smartClearOffsets(f);f.config.layout.width=auto[i]??100;});}selected.splice(index,1);if(wasSection&&builderConfig?.layout?.row_meta)delete builderConfig.layout.row_meta[String(oldRow)];openFieldKeys.delete(old);activeFieldKey=selected[Math.min(index,selected.length-1)]?.key||null;normalizeLayoutRows();if(selected.some(f=>Number(f.config?.layout?.row||1)===oldRow))normalizeVisualLines(oldRow);renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();sync();}\nfunction moveFieldToRow''',
"removeCanvasField"
)

# Row duplicate/delete/select operate on stable metadata identity and support empty rows.
sub_between(
"function duplicateLayoutRow(rowNo){",
"function requestRemoveLayoutRow",
'''function duplicateLayoutRow(rowNo){rowNo=Math.max(1,Number(rowNo)||1);const items=fieldsInRow(rowNo).map(([f])=>f),originalMeta=clone(rowMeta(rowNo)),insertRow=rowNo+1;smartShiftRowMeta(insertRow);selected.forEach(f=>{defaultFieldConfig(f);if(Number(f.config.layout.row||1)>=insertRow)f.config.layout.row=Number(f.config.layout.row)+1;});const copies=items.map((f,i)=>{const c=clone(f);c.key=uniqueKey(c.key);defaultFieldConfig(c);c.config.layout={...(c.config.layout||{}),row:insertRow,col:i+1,width:Number(f.config?.layout?.width||100)};return c;});selected.push(...copies);const copyMeta={...originalMeta,id:newRowId(),title:originalMeta.title?`${originalMeta.title} copia`:'',description:originalMeta.description||''};rowMetaStore()[String(insertRow)]=copyMeta;normalizeLayoutRows();sortSelectedByLayout();const newRow=rowNoForId(copyMeta.id)||insertRow;if(copies.length)smartFitRow(newRow);activeFieldKey=copies[0]?.key||activeFieldKey;activeStructureSelection={type:'row',id:copyMeta.id,row:newRow};layoutRowState.set(copyMeta.id,layoutRowState.get(originalMeta.id)??false);renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();sync();clearTimeout(historyTimer);pushHistory();}\nfunction requestRemoveLayoutRow''',
"duplicateLayoutRow"
)
sub_between(
"function requestRemoveLayoutRow(rowNo){",
"function renderRowSettings",
'''function requestRemoveLayoutRow(rowNo){rowNo=Math.max(1,Number(rowNo)||1);const items=fieldsInRow(rowNo).map(([f])=>f),count=items.length,meta=rowMeta(rowNo),title=meta.title||`${structureUi.row} ${rowNo}`,rowId=meta.id;confirmDelete(`la riga “${title}” con ${count} camp${count===1?'o':'i'}`,()=>{const refs=new Set(items);for(let i=selected.length-1;i>=0;i--){if(refs.has(selected[i]))selected.splice(i,1);}if(builderConfig?.layout?.row_meta)delete builderConfig.layout.row_meta[String(rowNo)];layoutRowState.delete(rowId);activeStructureSelection=null;activeFieldKey=selected[0]?.key||null;normalizeLayoutRows();repairInvalidRows();renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();sync();clearTimeout(historyTimer);pushHistory();});}\nfunction renderRowSettings''',
"requestRemoveLayoutRow"
)
replace_once(
"function selectRowSettings(rowNo){activeStructureSelection={type:'row',row:Number(rowNo)};renderSelected();renderLayoutCanvas();}",
"function selectRowSettings(rowNo){rowNo=Math.max(1,Number(rowNo)||1);activeStructureSelection={type:'row',id:rowIdForRow(rowNo),row:rowNo};renderSelected();renderLayoutCanvas();}",
"selectRowSettings"
)
replace_once(
"function renderSelected(){sel.innerHTML='';if(activeStructureSelection?.type==='row'){renderRowSettings(activeStructureSelection.row);return;}",
"function renderSelected(){sel.innerHTML='';if(activeStructureSelection?.type==='row'){refreshActiveRowSelection();if(activeStructureSelection?.type==='row'){renderRowSettings(activeStructureSelection.row);return;}}",
"renderSelected active row"
)

# Shift the persisted row registry when inserting a row; state itself is keyed by stable row ID.
sub_between(
"function smartShiftRowMeta(insertRow){",
"function smartMoveBeside",
'''function smartShiftRowMeta(insertRow){builderConfig=builderConfig&&typeof builderConfig==='object'?builderConfig:{};builderConfig.layout=builderConfig.layout&&typeof builderConfig.layout==='object'?builderConfig.layout:{};const meta=rowMetaStore(),next={};Object.keys(meta).forEach(k=>{const n=Number(k);next[String(Number.isFinite(n)&&n>=insertRow?n+1:n)]=meta[k];});builderConfig.layout.row_meta=next;refreshActiveRowSelection();}\nfunction smartMoveBeside''',
"smartShiftRowMeta"
)

# Existing visible empty slots are real drop targets: dropping there reuses the beside engine, which consumes the offset.
replace_once(
"function smartFindDropSpec(x,y){const stack=document.elementsFromPoint?document.elementsFromPoint(x,y):[];let card=stack.find(el=>el?.classList?.contains('df-layout-card')&&!el.classList.contains('df-smart-source-hidden'));if(card)return smartClassifyCard(card,x,y);",
"function smartFindDropSpec(x,y){const stack=document.elementsFromPoint?document.elementsFromPoint(x,y):[];const emptySlot=stack.map(el=>el?.closest?.('.df-layout-empty-slot[data-slot-target-key]')).find(Boolean);if(emptySlot){const targetKey=emptySlot.dataset.slotTargetKey||'',side=emptySlot.dataset.slotSide||'before',target=smartFieldByKey(targetKey);if(target&&targetKey!==smartDrag.fieldKey)return{kind:'beside',targetKey,row:Number(target.config?.layout?.row||1),position:side==='after'?'after':'before'};}let card=stack.find(el=>el?.classList?.contains('df-layout-card')&&!el.classList.contains('df-smart-source-hidden'));if(card)return smartClassifyCard(card,x,y);",
"smart empty slot drop target"
)
replace_once(
"if(before>0)parts.push({slot:true,width:before,side:'before'});parts.push({slot:false,width:Math.max(1,Number(f.config.layout.width||100)),f,i});if(after>0)parts.push({slot:true,width:after,side:'after'});",
"if(before>0)parts.push({slot:true,width:before,side:'before',targetKey:f.key});parts.push({slot:false,width:Math.max(1,Number(f.config.layout.width||100)),f,i});if(after>0)parts.push({slot:true,width:after,side:'after',targetKey:f.key});",
"slot target metadata"
)
replace_once(
"if(part.slot){const slot=document.createElement('div');slot.className='df-layout-empty-slot';slot.innerHTML='<span>VUOTO '+Math.round(part.width)+'%</span>';row.appendChild(slot);}else renderLayoutFieldCard(part.f,part.i,model.rowNo,row);",
"if(part.slot){const slot=document.createElement('div');slot.className='df-layout-empty-slot';slot.dataset.slotTargetKey=part.targetKey||'';slot.dataset.slotSide=part.side||'before';slot.setAttribute('role','button');slot.tabIndex=0;slot.setAttribute('aria-label','Spazio vuoto '+Math.round(part.width)+'%. Trascina qui un campo.');slot.innerHTML='<span>VUOTO '+Math.round(part.width)+'%</span>';row.appendChild(slot);}else renderLayoutFieldCard(part.f,part.i,model.rowNo,row);",
"slot DOM metadata"
)

# Use logical rows (including empty ones) where a new last row is calculated.
replace_once("else{const maxRow=Math.max(0,...selected.map(f=>Number(f.config?.layout?.row||0)));x.config.layout={row:maxRow+1,col:1,width:100};", "else{const maxRow=Math.max(0,...logicalRowNumbers());x.config.layout={row:maxRow+1,col:1,width:100};", "add max logical row")
replace_once("else if(spec.kind==='append'){const max=Math.max(1,...selected.map(f=>Number(f.config?.layout?.row||1)));changed=smartMoveNewRow(index,max,'after');}", "else if(spec.kind==='append'){const max=Math.max(1,...logicalRowNumbers());changed=smartMoveNewRow(index,max,'after');}", "smart append max logical row")
replace_once("const max=Math.max(0,...selected.map(f=>Number(f.config?.layout?.row||1)));moveFieldToRow(draggedFieldIndex,max+1);", "const max=Math.max(0,...logicalRowNumbers());moveFieldToRow(draggedFieldIndex,max+1);", "new row drop max logical row")

# Structural row blocks now use stable IDs. Numeric row is only the current position.
sub_between(
"function structureRowBlocks(){",
"function structureApplyBlocks",
'''function structureRowBlocks(){\n normalizeLayoutRows();\n return logicalRowNumbers().map(rowNo=>{\n  const fields=fieldsInRow(rowNo).map(([f])=>f),storedMeta=clone(rowMeta(rowNo)),rowId=String(storedMeta.id||rowIdForRow(rowNo)),sectionKey=fields.find(isLayoutSectionField)?.key||null;\n  const node=layoutCanvas?.querySelector(`.df-layout-row-group[data-row-id="${CSS.escape(rowId)}"]`),openState=sectionKey?null:(layoutRowState.has(rowId)?!!layoutRowState.get(rowId):!!node?.classList.contains('is-open'));\n  return{rowNo,rowId,fields,meta:storedMeta,sectionKey,openState};\n });\n}\nfunction structureApplyBlocks''',
"structureRowBlocks"
)
sub_between(
"function structureApplyBlocks(blocks){",
"function structureSectionRange",
'''function structureApplyBlocks(blocks){\n builderConfig=builderConfig&&typeof builderConfig==='object'?builderConfig:{};builderConfig.layout=builderConfig.layout&&typeof builderConfig.layout==='object'?builderConfig.layout:{};\n const nextMeta={},ordered=[],nextRowState=new Map();\n blocks.forEach((block,bi)=>{\n  const row=bi+1,meta=block.meta&&typeof block.meta==='object'?clone(block.meta):{title:'',description:''};if(!meta.id)meta.id=block.rowId||newRowId();if(typeof meta.title!=='string')meta.title='';if(typeof meta.description!=='string')meta.description='';block.rowId=meta.id;nextMeta[String(row)]=meta;\n  if(!block.sectionKey&&block.openState!==null&&block.openState!==undefined)nextRowState.set(meta.id,!!block.openState);\n  block.fields.forEach((f,ci)=>{defaultFieldConfig(f);f.config.layout={...(f.config.layout||{}),row,col:ci+1};ordered.push(f);});\n });\n builderConfig.layout.row_meta=nextMeta;layoutRowState.clear();nextRowState.forEach((value,id)=>layoutRowState.set(String(id),value));selected.splice(0,selected.length,...ordered);sortSelectedByLayout();refreshActiveRowSelection();\n}\nfunction structureSectionRange''',
"structureApplyBlocks"
)

# Duplicated section rows receive new identities; metadata and open state remain logically cloned.
old_clone="const clones=source.map(block=>{const fields=block.fields.map(()=>pairs[pi++].copy),marker=fields.find(isLayoutSectionField);if(marker&&!newSectionKey){marker.label=`${String(marker.label||structureUi.section).trim()||structureUi.section} copia`;newSectionKey=marker.key;}return{rowNo:0,fields,meta:block.meta?clone(block.meta):null,sectionKey:marker?.key||null};});"
new_clone="const clones=source.map(block=>{const fields=block.fields.map(()=>pairs[pi++].copy),marker=fields.find(isLayoutSectionField),meta=block.meta?clone(block.meta):{title:'',description:''};meta.id=newRowId();if(marker&&!newSectionKey){marker.label=`${String(marker.label||structureUi.section).trim()||structureUi.section} copia`;newSectionKey=marker.key;}return{rowNo:0,rowId:meta.id,fields,meta,sectionKey:marker?.key||null,openState:block.openState};});"
replace_once(old_clone,new_clone,"duplicate section row IDs")

sub_between(
"function structureMoveRow(sourceRow,spec){",
"function structureClearTargets",
'''function structureMoveRow(sourceId,spec){\n sourceId=String(sourceId||'');let blocks=structureRowBlocks(),si=blocks.findIndex(b=>String(b.rowId||'')===sourceId);if(si<0||blocks[si].sectionKey)return false;const moved=blocks.splice(si,1)[0],movedId=String(moved.rowId||moved.meta?.id||sourceId),anchorKey=moved.fields[0]?.key||'';let at=blocks.length;\n if(spec.kind==='row'){const ti=blocks.findIndex(b=>spec.targetRowId?String(b.rowId||'')===String(spec.targetRowId):Number(b.rowNo)===Number(spec.targetRow));if(ti<0)return false;at=ti+(spec.position==='after'?1:0);}else if(spec.kind==='section'){const range=structureSectionRange(blocks,spec.sectionId);if(spec.sectionId==='general')at=range?.end??0;else at=range?range.start+1:blocks.length;}else return false;\n blocks.splice(Math.max(0,Math.min(blocks.length,at)),0,moved);structureApplyBlocks(blocks);const field=anchorKey?selected.find(f=>f.key===anchorKey):null,newRow=rowNoForId(movedId)||Number(field?.config?.layout?.row||1);activeFieldKey=field?.key||activeFieldKey;activeStructureSelection={type:'row',id:movedId,row:newRow};return true;\n}\nfunction structureClearTargets''',
"structureMoveRow stable ID"
)

# Structural drag target resolution compares row IDs, not mutable row numbers.
sub_between(
"function structureFindTarget(x,y){",
"function structureBegin",
'''function structureFindTarget(x,y){const stack=document.elementsFromPoint?document.elementsFromPoint(x,y):[];\n if(structureDrag.type==='section'){\n  const head=stack.find(el=>el?.classList?.contains('df-layout-section-head'));if(head){const wrap=head.closest('.df-layout-section-group'),targetId=wrap?.dataset.sectionId;if(targetId&&targetId!==structureDrag.id){const r=head.getBoundingClientRect();return{kind:'sectionMove',targetId,position:y<r.top+r.height/2?'before':'after'};}}\n  let best=null,dist=Infinity;for(const group of [...(layoutCanvas?.querySelectorAll('.df-layout-section-group')||[])]){const targetId=group.dataset.sectionId;if(!targetId||targetId===structureDrag.id)continue;const r=group.getBoundingClientRect();let d=Infinity,position='before';if(y<r.top){d=r.top-y;position='before';}else if(y>r.bottom){d=y-r.bottom;position='after';}if(d<dist){dist=d;best={kind:'sectionMove',targetId,position};}}if(best&&dist<=26)return best;return null;\n }\n if(structureDrag.type==='row'){\n  const rowHead=stack.find(el=>el?.classList?.contains('df-layout-row-head'));if(rowHead){const group=rowHead.closest('.df-layout-row-group'),targetRow=Number(group?.dataset.rowNo||0),targetRowId=String(group?.dataset.rowId||'');if(targetRow&&targetRowId&&targetRowId!==String(structureDrag.id||'')){const r=rowHead.getBoundingClientRect();return{kind:'row',targetRow,targetRowId,position:y<r.top+r.height/2?'before':'after'};}}\n  let best=null,dist=Infinity;for(const group of [...(layoutCanvas?.querySelectorAll('.df-layout-row-group')||[])]){const targetRow=Number(group.dataset.rowNo||0),targetRowId=String(group.dataset.rowId||'');if(!targetRow||!targetRowId||targetRowId===String(structureDrag.id||''))continue;const r=group.getBoundingClientRect();let d=Infinity,position='before';if(y<r.top){d=r.top-y;position='before';}else if(y>r.bottom){d=y-r.bottom;position='after';}if(d<dist){dist=d;best={kind:'row',targetRow,targetRowId,position};}}if(best&&dist<=18)return best;\n  const secHead=stack.find(el=>el?.classList?.contains('df-layout-section-head'));if(secHead){const wrap=secHead.closest('.df-layout-section-group'),sectionId=wrap?.dataset.sectionId;if(sectionId)return{kind:'section',sectionId};}\n }\n return null;\n}\nfunction structureBegin''',
"structureFindTarget stable row ID"
)

# Render / accordion state uses stable row IDs.
replace_once("toolbar.querySelector('[data-layout-expand]').onclick=()=>{groups.forEach(g=>{layoutSectionState.set(g.id,true);g.rows.forEach(r=>layoutRowState.set(r.rowNo,true));});renderLayoutCanvas();};", "toolbar.querySelector('[data-layout-expand]').onclick=()=>{groups.forEach(g=>{layoutSectionState.set(g.id,true);g.rows.forEach(r=>layoutRowState.set(rowIdForRow(r.rowNo),true));});renderLayoutCanvas();};", "expand rows by ID")
replace_once("toolbar.querySelector('[data-layout-collapse]').onclick=()=>{groups.forEach(g=>{layoutSectionState.set(g.id,false);g.rows.forEach(r=>layoutRowState.set(r.rowNo,false));});renderLayoutCanvas();};", "toolbar.querySelector('[data-layout-collapse]').onclick=()=>{groups.forEach(g=>{layoutSectionState.set(g.id,false);g.rows.forEach(r=>layoutRowState.set(rowIdForRow(r.rowNo),false));});renderLayoutCanvas();};", "collapse rows by ID")
replace_once("const activeInGroup=(group.sectionField?.[0]?.key===activeFieldKey)||group.rows.some(r=>r.items.some(([f])=>f.key===activeFieldKey)||activeStructureSelection?.type==='row'&&Number(activeStructureSelection.row)===Number(r.rowNo));", "const activeInGroup=(group.sectionField?.[0]?.key===activeFieldKey)||group.rows.some(r=>r.items.some(([f])=>f.key===activeFieldKey)||activeStructureSelection?.type==='row'&&(activeStructureSelection.id?String(activeStructureSelection.id)===rowIdForRow(r.rowNo):Number(activeStructureSelection.row)===Number(r.rowNo)));", "active group by row ID")
replace_once("const rowSelected=activeStructureSelection?.type==='row'&&Number(activeStructureSelection.row)===Number(model.rowNo),rowActive=rowSelected||model.items.some(([f])=>f.key===activeFieldKey),rowOpen=layoutRowState.has(model.rowNo)?layoutRowState.get(model.rowNo):(rowActive||(sectionOpen&&group.rows.length===1));", "const rowId=rowIdForRow(model.rowNo),rowSelected=activeStructureSelection?.type==='row'&&(activeStructureSelection.id?String(activeStructureSelection.id)===rowId:Number(activeStructureSelection.row)===Number(model.rowNo)),rowActive=rowSelected||model.items.some(([f])=>f.key===activeFieldKey),rowOpen=layoutRowState.has(rowId)?layoutRowState.get(rowId):(rowActive||(sectionOpen&&group.rows.length===1));", "row state by ID")
replace_once("rowGroup.dataset.rowNo=String(model.rowNo);", "rowGroup.dataset.rowNo=String(model.rowNo);rowGroup.dataset.rowId=rowId;", "row DOM ID")
replace_once("const rowDragHandle=rowHead.querySelector('.df-row-drag-handle');rowDragHandle?.addEventListener('pointerdown',e=>structureQueue(e,rowDragHandle,'row',model.rowNo,rowTitle));rowDragHandle?.addEventListener('click',e=>e.stopPropagation());rowHead.addEventListener('pointerdown',e=>{if(e.target.closest('button,a,input,select,textarea,label,.df-layout-row-chevron,.df-layout-structure-handle'))return;structureQueue(e,rowHead,'row',model.rowNo,rowTitle);});", "const rowDragHandle=rowHead.querySelector('.df-row-drag-handle');rowDragHandle?.addEventListener('pointerdown',e=>structureQueue(e,rowDragHandle,'row',rowId,rowTitle));rowDragHandle?.addEventListener('click',e=>e.stopPropagation());rowHead.addEventListener('pointerdown',e=>{if(e.target.closest('button,a,input,select,textarea,label,.df-layout-row-chevron,.df-layout-structure-handle'))return;structureQueue(e,rowHead,'row',rowId,rowTitle);});", "row structural drag stable ID")
replace_once("const toggleRow=()=>{layoutRowState.set(model.rowNo,!rowGroup.classList.contains('is-open'));renderLayoutCanvas();};", "const toggleRow=()=>{layoutRowState.set(rowId,!rowGroup.classList.contains('is-open'));renderLayoutCanvas();};", "toggle row by ID")

# Empty logical rows are part of layout groups, not inferred only from fields.
replace_once("const rows=[...new Set(selected.map(f=>Number(f.config.layout.row||1)))].sort((a,b)=>a-b).map(rowNo=>({rowNo,items:fieldsInRow(rowNo)}));", "const rows=logicalRowNumbers().map(rowNo=>({rowNo,items:fieldsInRow(rowNo)}));", "layoutGroups logical rows")

# History keeps the structural row selection identity across undo/redo.
replace_once("function captureHistoryState(){return {selected:clone(selected),statuses:clone(statuses),columns:clone(columns),builderConfig:clone(builderConfig),emailConfig:clone(emailConfig),additionalEmails:clone(additionalEmails),integrations:clone(integrations),activeFieldKey,form:simpleFormState()};}", "function captureHistoryState(){return {selected:clone(selected),statuses:clone(statuses),columns:clone(columns),builderConfig:clone(builderConfig),emailConfig:clone(emailConfig),additionalEmails:clone(additionalEmails),integrations:clone(integrations),activeFieldKey,activeStructureSelection:clone(activeStructureSelection),form:simpleFormState()};}", "history capture row selection")
replace_once("activeFieldKey=s.activeFieldKey;renderSelected();", "activeFieldKey=s.activeFieldKey;activeStructureSelection=s.activeStructureSelection||null;renderSelected();", "history restore row selection")

# Clean duplicated historical comment while touching the drag engine.
s=s.replace("/* Forms 1.3.49: intelligent field drag & drop./* Forms 1.3.49: intelligent field drag & drop. No external dependency. */","/* Forms 1.3.50: intelligent field drag & drop. No external dependency. */",1)

# Runtime version.
s=s.replace("version:'1.3.49'","version:'1.3.50'")
s=s.replace('version: "1.3.49"','version: "1.3.50"')
p.write_text(s,encoding='utf-8')
PY

# Atomic Builder save: form + field replacement must commit together or rollback together.
python3 - "$C" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
start_anchor="        if ($id > 0) {\n            $db->updateObject('#__decaroforms_forms', $row, 'id');"
end_anchor="\n        if ($isAjax) {"
a=s.find(start_anchor)
if a<0: raise SystemExit('1.3.50 BuilderController write block start missing')
b=s.find(end_anchor,a)
if b<0: raise SystemExit('1.3.50 BuilderController write block end missing')
body=s[a:b]
if '$db->transactionStart();' in body: raise SystemExit('1.3.50 transaction already present in save block')
indented='\n'.join('    '+line if line else line for line in body.splitlines())
wrapped="""        try {\n            $db->transactionStart();\n%s\n            $db->transactionCommit();\n        } catch (Throwable $e) {\n            try { $db->transactionRollback(); } catch (Throwable $rollbackError) {}\n            $message = 'Il salvataggio non è stato completato. Nessun dato parziale è stato conservato.';\n            if ($isAjax) {\n                echo new JsonResponse(['code' => 'save_failed'], $message, true);\n                $app->close();\n                return;\n            }\n            $app->enqueueMessage($message, 'error');\n            $app->redirect(Route::_('index.php?option=com_decaroforms&view=builder&id=' . $id, false));\n            return;\n        }\n""" % indented
s=s[:a]+wrapped+s[b:]
p.write_text(s,encoding='utf-8')
PY

# Version all unpacked textual package files.
find "$TMP/component" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.js' -o -name '*.json' \) -print0 | xargs -0 sed -i 's/1\.3\.49/1.3.50/g'
find "$TMP/outer" -maxdepth 1 -type f -name '*.xml' -print0 | xargs -0 sed -i 's/1\.3\.49/1.3.50/g'

# Syntax checks.
php -l "$B"
php -l "$C"
python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
js='\n'.join(m.group(1) for m in re.finditer(r'<script(?:\s[^>]*)?>(.*?)</script>',s,re.S|re.I))
js=re.sub(r'<\?(?:php|=).*?\?>','null',js,flags=re.S|re.I)
Path('/tmp/forms-1350-builder.js').write_text(js,encoding='utf-8')
PY
node --check /tmp/forms-1350-builder.js

# Structural regression guards.
grep -q "function newRowId" "$B"
grep -q "function logicalRowNumbers" "$B"
grep -q "rowGroup.dataset.rowId=rowId" "$B"
grep -q "targetRowId" "$B"
grep -q "data-slot-target-key" "$B"
grep -q "slot.dataset.slotTargetKey" "$B"
grep -q "layoutRowState.set(rowId" "$B"
grep -q "activeStructureSelection={type:'row',id:" "$B"
grep -q "const rows=logicalRowNumbers().map" "$B"
grep -q "version:'1.3.50'" "$B"
grep -q "transactionStart" "$C"
grep -q "transactionCommit" "$C"
grep -q "transactionRollback" "$C"

# Ensure the old mutable-row state patterns do not remain in active render/drag logic.
! grep -q "layoutRowState.set(model.rowNo" "$B"
! grep -q "structureQueue(e,rowDragHandle,'row',model.rowNo" "$B"

# Rebuild inner component and outer package.
rm -f "$TMP/outer/com_decaroforms_$OLD.zip"
(
 cd "$TMP/component"
 zip -qr "$TMP/outer/com_decaroforms_$NEW.zip" .
)
for f in "$TMP/outer"/*"$OLD"*.zip; do
 [ -e "$f" ] || continue
 mv "$f" "${f//$OLD/$NEW}"
done
(
 cd "$TMP/outer"
 zip -qr "$TARGET" .
)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

# Update server feed.
FEED="$ROOT/updates/pkg_decaroforms.xml"
python3 - "$FEED" "$NEW" "$SHA" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]);v=sys.argv[2];sha=sys.argv[3];s=p.read_text(encoding='utf-8')
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
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8')
if '<version>1.3.50</version>' not in s:
 entry='''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>1.3.50</version>\n\t\t<note>Builder core: introdotta identità stabile per le Righe separata dalla posizione numerica; metadata, selezione e stato accordion seguono la Riga durante rinumerazioni, drag, duplicazione, eliminazione e spostamenti tra Sezioni. Le Righe vuote restano persistenti. Gli slot VUOTO diventano destinazioni reali: il secondo campo consuma correttamente lo spazio 50/50. Salvataggio Builder reso atomico tramite transazione database.</note>\n\t</changelog>'''
 pos=s.find('>')+1
 s=s[:pos]+entry+s[pos:]
 p.write_text(s,encoding='utf-8')
PY
fi

cat > "$TARGET_DIR/README.md" <<EOF
# Forms $NEW

Builder core refactor:
- stable logical Row identity independent from numeric position;
- Row title/description/accordion/selection follow the Row during reorder;
- empty Rows persist and can be selected/deleted/duplicated;
- smart empty slots are real drop targets and are consumed into 50/50 layouts;
- Section duplication generates fresh Row identities;
- Builder form + field replacement save is atomic through a database transaction;
- PHP and extracted JavaScript syntax checks passed during build.

SHA256: $SHA
EOF

echo "Built $TARGET"
echo "SHA256 $SHA"
