#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.40"
NEW="1.3.41"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1341-smart.js /tmp/forms-1341-layout.js /tmp/forms-1341-tests.js' EXIT
mkdir -p "$TMP/outer" "$TMP/component" "$TARGET_DIR"
unzip -q "$BASE" -d "$TMP/outer"
COMP_OLD="$TMP/outer/com_decaroforms_$OLD.zip"
test -f "$COMP_OLD"
unzip -q "$COMP_OLD" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
test -f "$B"

python3 - "$B" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')

def replace_between(start,end,new,label):
    global s
    a=s.find(start)
    if a<0: raise SystemExit(f'1.3.41: {label} start missing')
    b=s.find(end,a)
    if b<0: raise SystemExit(f'1.3.41: {label} end missing')
    s=s[:a]+new+s[b:]

# ---------------------------------------------------------------------------
# Logical row != visual line.
# A logical row can contain 100% / 100% / (50% + 50%) etc.
# Visual lines are deterministic from ordered widths and require no DB change.
# ---------------------------------------------------------------------------
helpers=r'''function fieldsInRow(row){return selected.map((f,i)=>[f,i]).filter(([f])=>Number(f.config?.layout?.row||1)===Number(row)).sort(([a],[b])=>(a.config.layout.col||1)-(b.config.layout.col||1));}
function smartAutoWidths(n){n=Math.max(1,Number(n)||1);if(n===1)return[100];if(n===2)return[50,50];if(n===3)return[33,33,34];if(n===4)return[25,25,25,25];const base=Math.floor(100/n),extra=100-base*n;return Array.from({length:n},(_,i)=>base+(i>=n-extra?1:0));}
function visualLinesForItems(items){const lines=[];let line=[],total=0;(Array.isArray(items)?items:[]).forEach(entry=>{const f=entry?.[0],w=Math.max(1,Math.min(100,Number(f?.config?.layout?.width||100)));if(line.length&&total+w>101){lines.push(line);line=[];total=0;}line.push(entry);total+=w;if(total>=99){lines.push(line);line=[];total=0;}});if(line.length)lines.push(line);return lines;}
function visualLinesInRow(row){return visualLinesForItems(fieldsInRow(row));}
function visualLineForField(field){if(!field)return[];const row=Number(field.config?.layout?.row||1);return visualLinesInRow(row).find(line=>line.some(([f])=>f===field))||[];}
function setLogicalRowOrder(row,fields){(Array.isArray(fields)?fields:[]).forEach((f,i)=>{defaultFieldConfig(f);f.config.layout.row=Number(row);f.config.layout.col=i+1;});}
function normalizeVisualLines(row){const items=fieldsInRow(row);if(!items.length)return;const lines=visualLinesForItems(items);lines.forEach(line=>{if(!line.length)return;if(line.length===1){line[0][0].config.layout.width=100;return;}const widths=line.map(([f])=>Number(f.config?.layout?.width||0)),total=widths.reduce((a,b)=>a+b,0),valid=total>=99&&total<=101&&widths.every(w=>Number.isFinite(w)&&w>0&&w<100);if(!valid){const auto=smartAutoWidths(line.length);line.forEach(([f],i)=>f.config.layout.width=auto[i]??100);}});fieldsInRow(row).forEach(([f],i)=>f.config.layout.col=i+1);}
function distributeRow(row){normalizeVisualLines(row);}
function smartFitRow(row){normalizeVisualLines(row);}
'''
replace_between('function fieldsInRow(row){','function rowMeta(',helpers,'row/visual-line helpers')

# Normalize logical row numbers but never collapse all fields of a logical row into one line.
new_normalize=r'''function normalizeLayoutRows(){builderConfig=builderConfig&&typeof builderConfig==='object'?builderConfig:{};builderConfig.layout=builderConfig.layout&&typeof builderConfig.layout==='object'?builderConfig.layout:{};const oldMeta=builderConfig.layout.row_meta&&typeof builderConfig.layout.row_meta==='object'?builderConfig.layout.row_meta:{};const rows=[...new Set(selected.map(f=>Number(f.config?.layout?.row||1)))].sort((a,b)=>a-b);const map=new Map(rows.map((r,i)=>[r,i+1])),nextMeta={};rows.forEach(r=>{const nr=map.get(r);if(oldMeta[r])nextMeta[nr]=oldMeta[r];});builderConfig.layout.row_meta=nextMeta;selected.forEach(f=>{defaultFieldConfig(f);f.config.layout.row=map.get(Number(f.config.layout.row||1))||1;});for(const row of [...new Set(selected.map(f=>Number(f.config.layout.row||1)))]){selected.filter(f=>Number(f.config.layout.row||1)===Number(row)).sort((a,b)=>(a.config.layout.col||1)-(b.config.layout.col||1)).forEach((f,i)=>f.config.layout.col=i+1);normalizeVisualLines(row);}}
'''
replace_between('function normalizeLayoutRows(){','function sortSelectedByLayout(',new_normalize,'normalizeLayoutRows')

# Invalid/incomplete visual lines are repaired independently, not by logical row total.
a=s.find('function repairInvalidRows(){')
if a<0: raise SystemExit('1.3.41: repairInvalidRows missing')
b=s.find('repairInvalidRows();',a)
if b<0: raise SystemExit('1.3.41: repairInvalidRows invocation missing')
b+=len('repairInvalidRows();')
s=s[:a]+"function repairInvalidRows(){[...new Set(selected.map(f=>Number(f.config?.layout?.row||1)))].forEach(row=>normalizeVisualLines(row));}\nrepairInvalidRows();"+s[b:]

# Width changes affect only the visual line where the field lives.
new_width=r'''function setFieldWidth(index,width){if(index==null||!selected[index])return;const field=selected[index],row=Number(field.config.layout.row||1),line=visualLineForField(field),members=line.map(([f])=>f);width=Math.max(10,Math.min(100,Number(width)||100));if(members.length<=1){field.config.layout.width=100;}else if(width===100){members.forEach(f=>f.config.layout.width=100);}else{field.config.layout.width=width;const others=members.filter(f=>f!==field),remaining=100-width,base=Math.floor(remaining/Math.max(1,others.length)),extra=remaining-base*Math.max(1,others.length);others.forEach((f,i)=>f.config.layout.width=Math.max(1,base+(i<extra?1:0)));}normalizeVisualLines(row);sync();renderSelected();renderLayoutCanvas();}
'''
replace_between('function setFieldWidth(index,width){','function selectField(',new_width,'setFieldWidth')

# Removing a field first closes only its old visual line, avoiding accidental merging with the next line.
new_remove=r'''function removeCanvasField(index){if(index==null||!selected[index])return;const field=selected[index],old=field.key,oldRow=Number(field.config.layout.row||1),line=visualLineForField(field),rest=line.map(([f])=>f).filter(f=>f!==field);if(rest.length){const auto=smartAutoWidths(rest.length);rest.forEach((f,i)=>f.config.layout.width=auto[i]??100);}selected.splice(index,1);openFieldKeys.delete(old);activeFieldKey=selected[Math.min(index,selected.length-1)]?.key||null;normalizeLayoutRows();if(selected.some(f=>Number(f.config?.layout?.row||1)===oldRow))normalizeVisualLines(oldRow);renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();sync();}
'''
replace_between('function removeCanvasField(index){','function moveFieldToRow(',new_remove,'removeCanvasField')

# Center-drop into an existing logical row = a new 100% visual line in that row.
new_move_to_row=r'''function moveFieldToRow(index,row,targetIndex=null){if(index==null||!selected[index])return;const field=selected[index],oldRow=Number(field.config.layout.row||1),sourceLine=visualLineForField(field),sourceRest=sourceLine.map(([f])=>f).filter(f=>f!==field);if(sourceRest.length){const auto=smartAutoWidths(sourceRest.length);sourceRest.forEach((f,i)=>f.config.layout.width=auto[i]??100);}selected.splice(index,1);row=Math.max(1,Number(row)||1);const targetItems=fieldsInRow(row).map(([f])=>f).filter(f=>f!==field);field.config.layout={...(field.config.layout||{}),row,col:targetItems.length+1,width:100};targetItems.push(field);setLogicalRowOrder(row,targetItems);selected.push(field);normalizeLayoutRows();sortSelectedByLayout();if(selected.some(f=>Number(f.config?.layout?.row||1)===oldRow))normalizeVisualLines(oldRow);normalizeVisualLines(Number(field.config.layout.row||row));activeFieldKey=field.key;sync();renderSelected();renderLayoutCanvas();}
'''
replace_between('function moveFieldToRow(index,row,targetIndex=null){','function moveFieldBeside(',new_move_to_row,'moveFieldToRow')

# Keep legacy HTML5 path aligned with the smart pointer drag rules.
legacy_moves=r'''function moveFieldBeside(index,targetIndex,position='after'){if(smartMoveBeside(index,targetIndex,position)){sortSelectedByLayout();sync();renderSelected();renderLayoutCanvas();}}
function moveFieldToNewRowAfter(index,afterRow){if(index==null||!selected[index])return;if(smartMoveNewRow(index,Number(afterRow),'after')){sortSelectedByLayout();sync();renderSelected();renderLayoutCanvas();}}

'''
replace_between('function moveFieldBeside(index,targetIndex,position=\'after\'){','/* Forms 1.3.40: intelligent field drag & drop.',legacy_moves+'/* Forms 1.3.40: intelligent field drag & drop.','legacy move functions')

# Add from library: append to the selected logical row as its own 100% visual line.
new_add=r'''function add(item){
 const x=defaultFieldConfig(clone(item));x.key=uniqueKey(x.key);x.options=Array.isArray(x.options)?x.options:[];
 const structural=['heading','fieldset','separator'].includes(String(x.type||''));let preferredRow=null;
 if(activeStructureSelection?.type==='row')preferredRow=Math.max(1,Number(activeStructureSelection.row)||1);
 else if(activeFieldKey){const ai=selected.findIndex(f=>f.key===activeFieldKey);if(ai>=0)preferredRow=Number(selected[ai].config?.layout?.row||1);}
 const currentItems=preferredRow!=null?fieldsInRow(preferredRow):[],rowHasStructure=currentItems.some(([f])=>['heading','fieldset','separator'].includes(String(f.type||''))),canUseLogicalRow=preferredRow!=null&&!structural&&!rowHasStructure;
 if(canUseLogicalRow){x.config.layout={row:preferredRow,col:currentItems.length+1,width:100};selected.push(x);normalizeLayoutRows();sortSelectedByLayout();normalizeVisualLines(Number(x.config.layout.row||preferredRow));}
 else if(preferredRow!=null){const insertRow=preferredRow+1;smartShiftRowMeta(insertRow);selected.forEach(f=>{defaultFieldConfig(f);if(Number(f.config.layout.row||1)>=insertRow)f.config.layout.row=Number(f.config.layout.row)+1;});x.config.layout={row:insertRow,col:1,width:100};selected.push(x);normalizeLayoutRows();sortSelectedByLayout();}
 else{const maxRow=Math.max(0,...selected.map(f=>Number(f.config?.layout?.row||0)));x.config.layout={row:maxRow+1,col:1,width:100};selected.push(x);normalizeLayoutRows();sortSelectedByLayout();}
 activeStructureSelection=null;activeFieldKey=x.key;openFieldKeys.clear();openFieldKeys.add(x.key);renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();sync();const selectedSection=[...document.querySelectorAll('[data-accordion]')][2];if(selectedSection){selectedSection.classList.add('is-open');selectedSection.querySelector('.df-section-toggle')?.setAttribute('aria-expanded','true');}setTimeout(()=>{sel.querySelector('.df-selected-item.is-open')?.scrollIntoView({behavior:'smooth',block:'nearest'});},100);
}

'''
replace_between('function add(item){','/* Forms 1.3.40: AI mode selector',new_add+'/* Forms 1.3.40: AI mode selector','add field behavior')

# ---------------------------------------------------------------------------
# Smart drag: side = same visual line; center = same logical row, new 100% line;
# row-group edge/gap = new logical row.
# ---------------------------------------------------------------------------
smart_preview=r'''function smartPreviewBesideWidths(spec){const target=smartFieldByKey(spec.targetKey),source=smartFieldByKey(smartDrag.fieldKey);if(!target||!source)return[100];const line=visualLineForField(target).map(([f])=>f).filter(f=>f!==source),pos=Math.max(0,line.indexOf(target)+(spec.position==='after'?1:0));line.splice(pos,0,source);return smartAutoWidths(line.length);}
function smartRenderPreview(spec){const id=smartSpecId(spec);if(id===smartDrag.specKey)return;const before=smartCaptureRects();smartRestorePreviewDom();smartDrag.spec=spec;smartDrag.specKey=id;if(!spec){smartAnimateFrom(before);return;}
 if(spec.kind==='beside'){
  const target=layoutCanvas?.querySelector(`.df-layout-card[data-field-key="${CSS.escape(spec.targetKey)}"]`);if(target){const row=target.closest('.df-layout-row'),ph=document.createElement('div');ph.className='df-smart-placeholder '+(spec.position==='before'?'is-left':'is-right');ph.innerHTML=`<span>${spec.position==='before'?'SINISTRA':'DESTRA'}</span>`;if(spec.position==='before')target.before(ph);else target.after(ph);target.classList.add(spec.position==='before'?'df-smart-target-left':'df-smart-target-right');smartSetGrid(row,smartPreviewBesideWidths(spec));}
 }else if(spec.kind==='joinrow'){
  const group=layoutCanvas?.querySelector(`.df-layout-row-group[data-row-no="${Number(spec.row)}"]`);if(group){const ph=document.createElement('div'),title=rowMeta(Number(spec.row)).title||`Riga ${Number(spec.row)}`;ph.className='df-smart-row-join-preview';ph.innerHTML=`<span class="df-smart-row-join-label">AGGIUNGI A ${esc(title).toUpperCase()}</span><span class="df-smart-row-join-field">${esc(smartFieldByKey(smartDrag.fieldKey)?.label||'Campo')} · 100%</span>`;group.classList.add('df-smart-row-join-target');(group.querySelector('.df-layout-row-body')||group).appendChild(ph);}
 }else if(spec.kind==='newrow'){
  const group=layoutCanvas?.querySelector(`.df-layout-row-group[data-row-no="${Number(spec.row)}"]`);if(group){const ph=document.createElement('div');ph.className='df-smart-newrow-preview';ph.innerHTML=`<span class="df-smart-newrow-label">${spec.position==='before'?'SOPRA':'SOTTO'} · NUOVA RIGA</span><span class="df-smart-newrow-field">${esc(smartFieldByKey(smartDrag.fieldKey)?.label||'Campo')} · 100%</span>`;if(spec.position==='before')group.before(ph);else group.after(ph);group.classList.add(spec.position==='before'?'df-smart-row-target-before':'df-smart-row-target-after');}
 }else if(spec.kind==='append'){
  const ph=document.createElement('div');ph.className='df-smart-newrow-preview is-append';ph.innerHTML=`<span class="df-smart-newrow-label">NUOVA RIGA</span><span class="df-smart-newrow-field">${esc(smartFieldByKey(smartDrag.fieldKey)?.label||'Campo')} · 100%</span>`;layoutCanvas?.appendChild(ph);
 }
 smartAnimateFrom(before);
}
function smartClassifyCard(card,x,y){if(!card||card.dataset.fieldKey===smartDrag.fieldKey)return null;const target=smartFieldByKey(card.dataset.fieldKey),source=smartFieldByKey(smartDrag.fieldKey);if(!target||!source)return null;const r=card.getBoundingClientRect(),rx=(x-r.left)/Math.max(1,r.width),targetLine=visualLineForField(target).map(([f])=>f),sourceInLine=targetLine.includes(source),count=targetLine.filter(f=>f!==source).length+(sourceInLine?0:1),canSide=count<=4;
 if(canSide&&rx<=.28)return{kind:'beside',targetKey:target.key,row:Number(target.config?.layout?.row||1),position:'before'};
 if(canSide&&rx>=.72)return{kind:'beside',targetKey:target.key,row:Number(target.config?.layout?.row||1),position:'after'};
 return{kind:'joinrow',row:Number(target.config?.layout?.row||1),targetKey:target.key};
}
function smartNearestCardInRow(row,x,y){const cards=[...row.querySelectorAll('.df-layout-card:not(.df-smart-source-hidden)')];if(!cards.length)return null;let best=null,score=Infinity;for(const card of cards){const r=card.getBoundingClientRect(),cx=Math.max(r.left,Math.min(x,r.right)),cy=Math.max(r.top,Math.min(y,r.bottom)),d=(x-cx)**2+(y-cy)**2;if(d<score){score=d;best=card;}}return best;}
function smartFindDropSpec(x,y){const stack=document.elementsFromPoint?document.elementsFromPoint(x,y):[];let card=stack.find(el=>el?.classList?.contains('df-layout-card')&&!el.classList.contains('df-smart-source-hidden'));if(card)return smartClassifyCard(card,x,y);
 const row=stack.map(el=>el?.closest?.('.df-layout-row')).find(Boolean);if(row){card=smartNearestCardInRow(row,x,y);if(card)return smartClassifyCard(card,x,y);return{kind:'joinrow',row:Number(row.dataset.row||1)};}
 const group=stack.map(el=>el?.closest?.('.df-layout-row-group')).find(Boolean);if(group){const rowNo=Number(group.dataset.rowNo||1),gr=group.getBoundingClientRect(),band=Math.min(18,Math.max(10,gr.height*.10));if(y<=gr.top+band)return{kind:'newrow',row:rowNo,position:'before'};if(y>=gr.bottom-band)return{kind:'newrow',row:rowNo,position:'after'};return{kind:'joinrow',row:rowNo};}
 if(layoutNewRow){const r=layoutNewRow.getBoundingClientRect();if(x>=r.left&&x<=r.right&&y>=r.top-20&&y<=r.bottom+30)return{kind:'append'};}
 const groups=[...(layoutCanvas?.querySelectorAll('.df-layout-row-group')||[])].filter(g=>!g.classList.contains('df-smart-source-row-empty'));let nearest=null,dist=Infinity;for(const g of groups){const r=g.getBoundingClientRect(),d=y<r.top?r.top-y:y>r.bottom?y-r.bottom:0;if(d<dist){dist=d;nearest=g;}}if(nearest&&dist<32){const r=nearest.getBoundingClientRect();return{kind:'newrow',row:Number(nearest.dataset.rowNo||1),position:y<r.top+r.height/2?'before':'after'};}
 return null;
}
'''
replace_between('function smartPreviewBesideWidths(','function smartShiftRowMeta(',smart_preview,'smart preview/drop classification')

smart_moves=r'''function smartMoveBeside(index,targetIndex,position='after'){if(index<0||targetIndex<0||!selected[index]||!selected[targetIndex]||index===targetIndex)return false;const field=selected[index],target=selected[targetIndex],oldRow=Number(field.config?.layout?.row||1),targetRow=Number(target.config?.layout?.row||1),sourceLine=visualLineForField(field).map(([f])=>f),targetLine=visualLineForField(target).map(([f])=>f),sameLine=targetLine.includes(field),targetMembers=targetLine.filter(f=>f!==field);if(!sameLine&&targetMembers.length>=4)return smartMoveToExistingRow(index,targetRow,target.key);if(!sameLine){const sourceRest=sourceLine.filter(f=>f!==field);if(sourceRest.length){const auto=smartAutoWidths(sourceRest.length);sourceRest.forEach((f,i)=>f.config.layout.width=auto[i]??100);}}const rowItems=fieldsInRow(targetRow).map(([f])=>f).filter(f=>f!==field),at=Math.max(0,rowItems.indexOf(target)+(position==='after'?1:0));rowItems.splice(at,0,field);field.config.layout.row=targetRow;setLogicalRowOrder(targetRow,rowItems);const newTargetLine=rowItems.filter(f=>targetMembers.includes(f)||f===field),auto=smartAutoWidths(newTargetLine.length);newTargetLine.forEach((f,i)=>f.config.layout.width=auto[i]??100);normalizeLayoutRows();sortSelectedByLayout();if(selected.some(f=>Number(f.config?.layout?.row||1)===oldRow))normalizeVisualLines(oldRow);normalizeVisualLines(Number(field.config.layout.row||targetRow));activeStructureSelection=null;activeFieldKey=field.key;return true;}
function smartMoveToExistingRow(index,targetRow,targetKey=null){if(index<0||!selected[index])return false;targetRow=Math.max(1,Number(targetRow)||1);const field=selected[index],oldRow=Number(field.config?.layout?.row||1),sourceLine=visualLineForField(field).map(([f])=>f),sourceRest=sourceLine.filter(f=>f!==field);if(sourceRest.length){const auto=smartAutoWidths(sourceRest.length);sourceRest.forEach((f,i)=>f.config.layout.width=auto[i]??100);}const target=targetKey?selected.find(f=>f.key===targetKey):null,targetLine=target?visualLineForField(target).map(([f])=>f).filter(f=>f!==field):[];selected.splice(index,1);const targetItems=fieldsInRow(targetRow).map(([f])=>f).filter(f=>f!==field);let at=targetItems.length;if(targetLine.length){const last=targetLine[targetLine.length-1],li=targetItems.indexOf(last);if(li>=0)at=li+1;}field.config.layout={...(field.config.layout||{}),row:targetRow,col:at+1,width:100};targetItems.splice(at,0,field);setLogicalRowOrder(targetRow,targetItems);selected.push(field);normalizeLayoutRows();sortSelectedByLayout();if(selected.some(f=>Number(f.config?.layout?.row||1)===oldRow))normalizeVisualLines(oldRow);normalizeVisualLines(Number(field.config.layout.row||targetRow));activeStructureSelection=null;activeFieldKey=field.key;return true;}
function smartMoveNewRow(index,targetRow,position='after'){if(index<0||!selected[index])return false;const field=selected[index],oldRow=Number(field.config?.layout?.row||1),oldItems=fieldsInRow(oldRow).map(([f])=>f),sourceLine=visualLineForField(field).map(([f])=>f),sourceRest=sourceLine.filter(f=>f!==field);if(oldRow===Number(targetRow)&&oldItems.length===1)return false;if(sourceRest.length){const auto=smartAutoWidths(sourceRest.length);sourceRest.forEach((f,i)=>f.config.layout.width=auto[i]??100);}const insertRow=Math.max(1,Number(targetRow)+(position==='after'?1:0));smartShiftRowMeta(insertRow);selected.forEach(f=>{defaultFieldConfig(f);if(f!==field&&Number(f.config.layout.row||1)>=insertRow)f.config.layout.row=Number(f.config.layout.row)+1;});field.config.layout={...(field.config.layout||{}),row:insertRow,col:1,width:100};normalizeLayoutRows();sortSelectedByLayout();if(selected.some(f=>Number(f.config?.layout?.row||1)===oldRow))normalizeVisualLines(oldRow);normalizeVisualLines(Number(field.config.layout.row||1));activeStructureSelection=null;activeFieldKey=field.key;return true;}
function smartCommitSpec(spec,key){const index=smartFieldIndex(key);if(index<0||!spec)return false;let changed=false;if(spec.kind==='beside'){const ti=smartFieldIndex(spec.targetKey);changed=smartMoveBeside(index,ti,spec.position);}else if(spec.kind==='joinrow')changed=smartMoveToExistingRow(index,Number(spec.row),spec.targetKey||null);else if(spec.kind==='newrow')changed=smartMoveNewRow(index,Number(spec.row),spec.position);else if(spec.kind==='append'){const max=Math.max(1,...selected.map(f=>Number(f.config?.layout?.row||1)));changed=smartMoveNewRow(index,max,'after');}if(changed){sortSelectedByLayout();sync();renderSelected();clearTimeout(historyTimer);pushHistory();}return changed;}
'''
replace_between('function smartMoveBeside(','function smartEndVisual(',smart_moves,'smart move commit')

# During drag preview, only reflow the source VISUAL line (DOM row), which is already isolated in 1.3.41 renderer.
# The existing smartReflowSourceRow is therefore retained.

# ---------------------------------------------------------------------------
# Builder rendering: one logical-row accordion can contain multiple visual lines.
# ---------------------------------------------------------------------------
render_start=s.find('function renderLayoutCanvas(){')
if render_start<0: raise SystemExit('1.3.41: renderLayoutCanvas missing')
a=s.find('  group.rows.forEach((model,ri)=>{',render_start)
if a<0: raise SystemExit('1.3.41: row loop missing')
b=s.find('  wrap.append(head,body);',a)
if b<0: raise SystemExit('1.3.41: row loop end missing')
row_loop=r'''  group.rows.forEach((model,ri)=>{
   const rowSelected=activeStructureSelection?.type==='row'&&Number(activeStructureSelection.row)===Number(model.rowNo),rowActive=rowSelected||model.items.some(([f])=>f.key===activeFieldKey),rowOpen=layoutRowState.has(model.rowNo)?layoutRowState.get(model.rowNo):(rowActive||(sectionOpen&&group.rows.length===1));
   const rowGroup=document.createElement('div');rowGroup.className='df-layout-row-group'+(rowOpen?' is-open':'')+(rowSelected?' is-selected':'');rowGroup.dataset.rowNo=String(model.rowNo);
   const rowHead=document.createElement('div');rowHead.className='df-layout-row-head';rowHead.setAttribute('role','button');rowHead.tabIndex=0;
   const visualLines=visualLinesForItems(model.items),widths=visualLines.map(line=>line.map(([f])=>Number(f.config.layout.width||100)+'%').join(' + ')).join(' / '),meta=rowMeta(model.rowNo),rowTitle=meta.title||`${structureUi.row} ${model.rowNo}`,rowHasSection=fieldsInRow(model.rowNo).some(([f])=>isLayoutSectionField(f)),rowHandle=rowHasSection?'':`<span class="df-layout-structure-handle df-row-drag-handle" role="button" tabindex="0" title="Trascina riga" aria-label="Trascina riga">${modernUiIcon('grip')}</span>`,rowActions=rowHasSection?'':`<span class="df-layout-row-actions"><button type="button" data-row-edit class="df-icon-only" title="Modifica riga" aria-label="Modifica riga">${modernUiIcon('edit')}</button><button type="button" data-row-copy class="df-icon-only" title="Duplica riga" aria-label="Duplica riga">${modernUiIcon('copy')}</button><button type="button" data-row-remove class="df-icon-only df-row-remove" title="Elimina riga" aria-label="Elimina riga">${modernUiIcon('trash')}</button></span>`;
   rowHead.innerHTML=`${rowHandle}<span class="df-layout-row-chevron">›</span><span class="df-layout-row-label">${esc(rowTitle)}</span>${meta.description?`<span class="df-layout-structure-description">${esc(meta.description)}</span>`:''}<span class="df-layout-row-summary">${model.items.length} ${esc(structureUi.fields)} · ${esc(widths)}</span>${rowActions}`;
   const rowDragHandle=rowHead.querySelector('.df-row-drag-handle');rowDragHandle?.addEventListener('pointerdown',e=>structureQueue(e,rowDragHandle,'row',model.rowNo,rowTitle));rowDragHandle?.addEventListener('click',e=>e.stopPropagation());rowHead.querySelector('[data-row-edit]')?.addEventListener('click',e=>{e.stopPropagation();selectRowSettings(model.rowNo);});rowHead.querySelector('[data-row-copy]')?.addEventListener('click',e=>{e.stopPropagation();duplicateLayoutRow(model.rowNo);});rowHead.querySelector('[data-row-remove]')?.addEventListener('click',e=>{e.stopPropagation();requestRemoveLayoutRow(model.rowNo);});
   const toggleRow=()=>{layoutRowState.set(model.rowNo,!rowGroup.classList.contains('is-open'));renderLayoutCanvas();};rowHead.onclick=e=>{if(Date.now()<structureSuppressClickUntil||e.target.closest('.df-layout-structure-handle')||e.target.closest('button'))return;if(e.target.closest('.df-layout-row-chevron'))toggleRow();else selectRowSettings(model.rowNo);};rowHead.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();selectRowSettings(model.rowNo);}};
   rowHead.addEventListener('dragover',e=>{if(draggedFieldIndex==null)return;e.preventDefault();rowHead.classList.add('is-over');});rowHead.addEventListener('dragleave',()=>rowHead.classList.remove('is-over'));rowHead.addEventListener('drop',e=>{if(draggedFieldIndex==null)return;e.preventDefault();rowHead.classList.remove('is-over');moveFieldToRow(draggedFieldIndex,model.rowNo);});
   const rowBody=document.createElement('div');rowBody.className='df-layout-row-body';
   visualLines.forEach((line,lineIndex)=>{const row=document.createElement('div');row.className='df-layout-row';row.dataset.row=String(model.rowNo);row.dataset.line=String(lineIndex+1);row.style.gridTemplateColumns=line.map(([f])=>Math.max(10,Number(f.config.layout.width||100))+'fr').join(' ');line.forEach(([f,i])=>renderLayoutFieldCard(f,i,model.rowNo,row));row.addEventListener('dragover',e=>{if(e.target.closest('.df-layout-card'))return;e.preventDefault();row.classList.add('is-over');});row.addEventListener('dragleave',e=>{if(!row.contains(e.relatedTarget))row.classList.remove('is-over');});row.addEventListener('drop',e=>{if(e.target.closest('.df-layout-card'))return;e.preventDefault();row.classList.remove('is-over');moveFieldToRow(draggedFieldIndex,model.rowNo);});rowBody.appendChild(row);});
   rowGroup.append(rowHead,rowBody);body.appendChild(rowGroup);
  });
'''
s=s[:a]+row_loop+s[b:]

# Structural row moves must preserve the ordered width sequence; col remains global within logical row.
# Existing structureApplyBlocks already does exactly that, so no destructive width changes are added.

# Row duplicate preserves widths and order; smartFitRow is now visual-line aware.

# UI spacing for stacked internal lines and a clearer join-row preview.
css=r'''
/* Forms 1.3.41: logical rows can contain multiple visual lines. */
.df-builder-workspace .df-layout-row-body{display:flex;flex-direction:column;gap:6px;padding-top:1px;padding-bottom:1px}.df-builder-workspace .df-layout-row-body>.df-layout-row{width:100%;flex:0 0 auto}.df-builder-workspace .df-layout-row-body>.df-layout-row+.df-layout-row{margin-top:1px}.df-layout-row-summary{max-width:48%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.df-smart-row-join-preview{margin:6px 5px!important;min-height:42px!important}.df-smart-row-join-target>.df-layout-row-head{box-shadow:inset 3px 0 0 #7c3aed!important}
@media(max-width:800px){.df-builder-workspace .df-layout-row-body{gap:7px}.df-builder-workspace .df-layout-row{grid-template-columns:1fr!important}.df-layout-row-summary{max-width:42%}}
'''
if '</style>' not in s: raise SystemExit('1.3.41: style anchor missing')
s=s.replace('</style>',css+'</style>',1)

# Runtime marker and static checks.
s=s.replace("window.dfBuilderRuntime={version:'1.3.40'","window.dfBuilderRuntime={version:'1.3.41'",1)
checks=['function visualLinesForItems','function normalizeVisualLines','function smartMoveToExistingRow','data-line','AGGIUNGI A','100% / 100%',"version:'1.3.41'"]
# 100% / 100% is produced at runtime, not literal; check the separator expression instead.
checks.remove('100% / 100%');checks.append(".join(' / ')")
for c in checks:
    if c not in s: raise SystemExit('1.3.41 missing '+c)

p.write_text(s,encoding='utf-8')
PY

# Keep component metadata coherent.
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$TMP/component" || true)
php -l "$B" >/dev/null

# Syntax-check modified JS regions without executing browser APIs.
python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
a=s.index('function fieldsInRow(');b=s.index('const aiAllowedTypes=',a)
smart=re.sub(r"<\?php.*?\?>","null",s[a:b],flags=re.S)
Path('/tmp/forms-1341-smart.js').write_text(smart,encoding='utf-8')
a=s.index('function renderLayoutCanvas()');b=s.index('function renderColumns(',a)
layout=re.sub(r"<\?php.*?\?>","null",s[a:b],flags=re.S)
Path('/tmp/forms-1341-layout.js').write_text(layout,encoding='utf-8')
PY
node --check /tmp/forms-1341-smart.js >/dev/null
node --check /tmp/forms-1341-layout.js >/dev/null

# Pure layout regression tests for the new hierarchy.
cat > /tmp/forms-1341-tests.js <<'JS'
function visualLinesForItems(items){const lines=[];let line=[],total=0;(Array.isArray(items)?items:[]).forEach(entry=>{const f=entry?.[0],w=Math.max(1,Math.min(100,Number(f?.config?.layout?.width||100)));if(line.length&&total+w>101){lines.push(line);line=[];total=0;}line.push(entry);total+=w;if(total>=99){lines.push(line);line=[];total=0;}});if(line.length)lines.push(line);return lines;}
const mk=(...w)=>w.map((width,i)=>[{config:{layout:{width}},key:String(i)},i]);
const sig=x=>visualLinesForItems(x).map(line=>line.map(([f])=>f.config.layout.width).join('+')).join('/');
const cases=[
 [mk(100,100),'100/100'],
 [mk(50,50),'50+50'],
 [mk(100,50,50),'100/50+50'],
 [mk(75,25,100),'75+25/100'],
 [mk(33,33,34,100),'33+33+34/100']
];
for(const [input,expected] of cases){const got=sig(input);if(got!==expected)throw new Error(`${got} != ${expected}`);}
console.log('logical-row visual-line tests OK');
JS
node /tmp/forms-1341-tests.js >/dev/null

# Rebuild component ZIP.
rm -f "$COMP_OLD"
(cd "$TMP/component" && zip -qr "$TMP/outer/com_decaroforms_$NEW.zip" .)

# Rebuild all additional nested extension ZIPs, version-only. Frontend renderer already
# uses flex-wrap + each field width, so 100/100 and 50+50 work naturally without code changes.
for z in "$TMP/outer"/*_"$OLD".zip; do
  [ -e "$z" ] || continue
  work="$TMP/sub-$(basename "$z" .zip)"; mkdir -p "$work"; unzip -q "$z" -d "$work"
  while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$work" || true)
  newz="${z/$OLD/$NEW}"; rm -f "$newz"; (cd "$work" && zip -qr "$newz" .); rm -f "$z"
done
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -Il -- "$OLD" "$TMP/outer"/* 2>/dev/null || true)

rm -f "$TARGET"; (cd "$TMP/outer" && zip -qr "$TARGET" .); unzip -tq "$TARGET" >/dev/null
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update><name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description><element>pkg_decaroforms</element><type>package</type><client>site</client><version>$NEW</version><downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/$NEW/pkg_decaroforms_$NEW.zip</downloadurl></downloads><changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags><maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl><targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256></update></updates>
EOF
cat > "$ROOT/updates/changelog.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog><element>pkg_decaroforms</element><type>package</type><version>$NEW</version><fix>Corretto il modello del Builder: una Riga è ora un contenitore logico e può contenere più linee visuali.</fix><improvement>Due campi al 100% possono restare nella stessa Riga, uno sotto l'altro, senza creare nuove Righe.</improvement><improvement>Il trascinamento al centro di una Riga aggiunge il campo al 100% nella stessa Riga; solo il rilascio a sinistra/destra crea una linea condivisa 50+50, 33+33+34 o 25+25+25+25.</improvement><improvement>Cambiare un campo a 100% non sposta più gli altri campi in una nuova Riga logica.</improvement><improvement>La testata della Riga mostra le linee con separatore “/”, ad esempio 100% / 100% oppure 100% / 50% + 50%.</improvement><note>Nessuna migrazione database: il formato salvato row/col/width resta compatibile e il frontend continua a usare le larghezze esistenti.</note><note>Mantenute le funzioni della 1.3.40: azioni Riga/Sezione, drag strutturale, Importa con AI, HTML/ZIP, filtri e Undo/Redo.</note><language>it-IT</language></changelog></changelogs>
EOF
rm -rf "$ROOT/releases/_upload"
echo "Built $TARGET"
echo "SHA256 $SHA"
