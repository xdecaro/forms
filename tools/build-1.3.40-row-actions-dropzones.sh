#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.39"
NEW="1.3.40"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1340-smart.js /tmp/forms-1340-layout.js' EXIT
mkdir -p "$TMP/outer" "$TMP/component" "$TARGET_DIR"
unzip -q "$BASE" -d "$TMP/outer"
COMP_OLD="$TMP/outer/com_decaroforms_$OLD.zip"
test -f "$COMP_OLD"
unzip -q "$COMP_OLD" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
test -f "$B"

python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')

# ---------------------------------------------------------------------------
# 1) Field drag: distinguish joining an existing row from creating a new row.
# ---------------------------------------------------------------------------
old="layoutCanvas?.querySelectorAll('.df-smart-placeholder,.df-smart-newrow-preview').forEach(el=>el.remove());"
new="layoutCanvas?.querySelectorAll('.df-smart-placeholder,.df-smart-newrow-preview,.df-smart-row-join-preview').forEach(el=>el.remove());"
if old not in s: raise SystemExit('1.3.40: smart preview cleanup anchor missing')
s=s.replace(old,new,1)
old="layoutCanvas?.querySelectorAll('.df-smart-target-left,.df-smart-target-right,.df-smart-row-target-before,.df-smart-row-target-after').forEach(el=>el.classList.remove('df-smart-target-left','df-smart-target-right','df-smart-row-target-before','df-smart-row-target-after'));"
new="layoutCanvas?.querySelectorAll('.df-smart-target-left,.df-smart-target-right,.df-smart-row-target-before,.df-smart-row-target-after,.df-smart-row-join-target').forEach(el=>el.classList.remove('df-smart-target-left','df-smart-target-right','df-smart-row-target-before','df-smart-row-target-after','df-smart-row-join-target'));"
if old not in s: raise SystemExit('1.3.40: smart target cleanup anchor missing')
s=s.replace(old,new,1)

# Add an explicit preview state for dropping into an existing row.
needle=" }else if(spec.kind==='newrow'){\n  const row=layoutCanvas?.querySelector(`.df-layout-row[data-row=\"${Number(spec.row)}\"]`),group=row?.closest('.df-layout-row-group');"
join=""" }else if(spec.kind==='joinrow'){
  const row=layoutCanvas?.querySelector(`.df-layout-row[data-row=\"${Number(spec.row)}\"]`),group=row?.closest('.df-layout-row-group');if(group&&row){const source=smartFieldByKey(smartDrag.fieldKey),same=Number(source?.config?.layout?.row||0)===Number(spec.row),items=fieldsInRow(Number(spec.row)).map(([f])=>f).filter(f=>f!==source),nextCount=items.length+(same?0:1),ph=document.createElement('div'),title=rowMeta(Number(spec.row)).title||`Riga ${Number(spec.row)}`;ph.className='df-smart-row-join-preview';ph.innerHTML=`<span class=\"df-smart-row-join-label\">AGGIUNGI A ${esc(title).toUpperCase()}</span><span class=\"df-smart-row-join-field\">${esc(source?.label||'Campo')}</span>`;group.classList.add('df-smart-row-join-target');group.querySelector('.df-layout-row-head')?.after(ph);smartSetGrid(row,smartAutoWidths(Math.max(1,nextCount)));}
 }else if(spec.kind==='newrow'){
  const row=layoutCanvas?.querySelector(`.df-layout-row[data-row=\"${Number(spec.row)}\"]`),group=row?.closest('.df-layout-row-group');"""
if needle not in s: raise SystemExit('1.3.40: smartRenderPreview newrow anchor missing')
s=s.replace(needle,join,1)

# Center of a field/row now means "join this row"; only the top/bottom bands create rows.
pat=r"function smartClassifyCard\(card,x,y\)\{.*?\n\}\nfunction smartNearestCardInRow"
m=re.search(pat,s,re.S)
if not m: raise SystemExit('1.3.40: smartClassifyCard block missing')
new_block=r'''function smartClassifyCard(card,x,y){if(!card||card.dataset.fieldKey===smartDrag.fieldKey)return null;const target=smartFieldByKey(card.dataset.fieldKey),source=smartFieldByKey(smartDrag.fieldKey);if(!target||!source)return null;const r=card.getBoundingClientRect(),rx=(x-r.left)/Math.max(1,r.width),ry=(y-r.top)/Math.max(1,r.height),targetRow=Number(target.config?.layout?.row||1),sourceRow=Number(source.config?.layout?.row||1),count=fieldsInRow(targetRow).length+(sourceRow===targetRow?0:1),canSide=count<=4,canJoin=sourceRow!==targetRow&&count<=4;
 if(canSide&&rx<=.28)return{kind:'beside',targetKey:target.key,position:'before'};
 if(canSide&&rx>=.72)return{kind:'beside',targetKey:target.key,position:'after'};
 if(ry<=.22)return{kind:'newrow',row:targetRow,position:'before'};
 if(ry>=.78)return{kind:'newrow',row:targetRow,position:'after'};
 if(canJoin)return{kind:'joinrow',row:targetRow};
 return{kind:'newrow',row:targetRow,position:ry<.5?'before':'after'};
}
function smartNearestCardInRow'''
s=s[:m.start()]+new_block+s[m.end():]

pat=r"function smartFindDropSpec\(x,y\)\{.*?\n return null;\n\}"
m=re.search(pat,s,re.S)
if not m: raise SystemExit('1.3.40: smartFindDropSpec block missing')
new_find=r'''function smartFindDropSpec(x,y){const stack=document.elementsFromPoint?document.elementsFromPoint(x,y):[];let card=stack.find(el=>el?.classList?.contains('df-layout-card')&&!el.classList.contains('df-smart-source-hidden'));if(card)return smartClassifyCard(card,x,y);
 const source=smartFieldByKey(smartDrag.fieldKey),sourceRow=Number(source?.config?.layout?.row||0);
 const row=stack.map(el=>el?.closest?.('.df-layout-row')).find(Boolean);if(row){const rowNo=Number(row.dataset.row||1),rr=row.getBoundingClientRect(),band=Math.min(18,Math.max(9,rr.height*.20)),count=fieldsInRow(rowNo).length+(sourceRow===rowNo?0:1);if(y<=rr.top+band)return{kind:'newrow',row:rowNo,position:'before'};if(y>=rr.bottom-band)return{kind:'newrow',row:rowNo,position:'after'};card=smartNearestCardInRow(row,x,y);if(card){const spec=smartClassifyCard(card,x,y);if(spec?.kind==='beside'||spec?.kind==='joinrow')return spec;}if(sourceRow!==rowNo&&count<=4)return{kind:'joinrow',row:rowNo};return{kind:'newrow',row:rowNo,position:y<rr.top+rr.height/2?'before':'after'};}
 const group=stack.map(el=>el?.closest?.('.df-layout-row-group')).find(Boolean);if(group){const rowEl=group.querySelector('.df-layout-row'),rowNo=Number(rowEl?.dataset.row||group.dataset.rowNo||1),gr=group.getBoundingClientRect(),band=Math.min(20,Math.max(12,gr.height*.14)),count=fieldsInRow(rowNo).length+(sourceRow===rowNo?0:1);if(y<=gr.top+band)return{kind:'newrow',row:rowNo,position:'before'};if(y>=gr.bottom-band)return{kind:'newrow',row:rowNo,position:'after'};if(sourceRow!==rowNo&&count<=4)return{kind:'joinrow',row:rowNo};if(rowEl)return{kind:'newrow',row:rowNo,position:y<gr.top+gr.height/2?'before':'after'};}
 if(layoutNewRow){const r=layoutNewRow.getBoundingClientRect();if(x>=r.left&&x<=r.right&&y>=r.top-20&&y<=r.bottom+30)return{kind:'append'};}
 const groups=[...(layoutCanvas?.querySelectorAll('.df-layout-row-group')||[])].filter(g=>!g.classList.contains('df-smart-source-row-empty'));let nearest=null,dist=Infinity;for(const g of groups){const r=g.getBoundingClientRect(),d=y<r.top?r.top-y:y>r.bottom?y-r.bottom:0;if(d<dist){dist=d;nearest=g;}}if(nearest&&dist<48){const rowEl=nearest.querySelector('.df-layout-row'),r=nearest.getBoundingClientRect();if(rowEl)return{kind:'newrow',row:Number(rowEl.dataset.row||1),position:y<r.top+r.height/2?'before':'after'};}
 return null;
}'''
s=s[:m.start()]+new_find+s[m.end():]

move_anchor='function smartMoveNewRow(index,targetRow,position=\'after\'){'
if move_anchor not in s: raise SystemExit('1.3.40: smartMoveNewRow anchor missing')
move_existing=r'''function smartMoveToExistingRow(index,targetRow){if(index<0||!selected[index])return false;targetRow=Math.max(1,Number(targetRow)||1);const field=selected[index],oldRow=Number(field.config?.layout?.row||1),same=oldRow===targetRow,targetItems=fieldsInRow(targetRow).map(([f])=>f).filter(f=>f!==field);if(same||targetItems.length>=4)return false;const oldNeighbors=fieldsInRow(oldRow).map(([f])=>f).filter(f=>f!==field);selected.splice(index,1);field.config.layout={...(field.config.layout||{}),row:targetRow,col:targetItems.length+1,width:100};selected.push(field);normalizeLayoutRows();sortSelectedByLayout();if(oldNeighbors.length)smartFitRow(Number(oldNeighbors[0].config.layout.row||1));smartFitRow(Number(field.config.layout.row||targetRow));activeStructureSelection=null;activeFieldKey=field.key;return true;}
'''
s=s.replace(move_anchor,move_existing+move_anchor,1)
old="if(spec.kind==='beside'){const ti=smartFieldIndex(spec.targetKey);changed=smartMoveBeside(index,ti,spec.position);}else if(spec.kind==='newrow')changed=smartMoveNewRow(index,Number(spec.row),spec.position);"
new="if(spec.kind==='beside'){const ti=smartFieldIndex(spec.targetKey);changed=smartMoveBeside(index,ti,spec.position);}else if(spec.kind==='joinrow')changed=smartMoveToExistingRow(index,Number(spec.row));else if(spec.kind==='newrow')changed=smartMoveNewRow(index,Number(spec.row),spec.position);"
if old not in s: raise SystemExit('1.3.40: smartCommitSpec anchor missing')
s=s.replace(old,new,1)

# ---------------------------------------------------------------------------
# 2) Whole-row actions: edit, duplicate and delete with confirmation.
# ---------------------------------------------------------------------------
helper_anchor='function renderRowSettings(rowNo){'
if helper_anchor not in s: raise SystemExit('1.3.40: renderRowSettings anchor missing')
helpers=r'''function duplicateLayoutRow(rowNo){rowNo=Math.max(1,Number(rowNo)||1);const items=fieldsInRow(rowNo).map(([f])=>f);if(!items.length)return;const originalMeta=clone(rowMeta(rowNo)),insertRow=rowNo+1;smartShiftRowMeta(insertRow);selected.forEach(f=>{defaultFieldConfig(f);if(Number(f.config.layout.row||1)>=insertRow)f.config.layout.row=Number(f.config.layout.row)+1;});const copies=items.map((f,i)=>{const c=clone(f);c.key=uniqueKey(c.key);defaultFieldConfig(c);c.config.layout={...(c.config.layout||{}),row:insertRow,col:i+1,width:Number(f.config?.layout?.width||100)};return c;});selected.push(...copies);builderConfig.layout.row_meta=builderConfig.layout.row_meta&&typeof builderConfig.layout.row_meta==='object'?builderConfig.layout.row_meta:{};if(originalMeta.title||originalMeta.description)builderConfig.layout.row_meta[String(insertRow)]={title:originalMeta.title?`${originalMeta.title} copia`:'',description:originalMeta.description||''};normalizeLayoutRows();sortSelectedByLayout();smartFitRow(Number(copies[0]?.config?.layout?.row||insertRow));activeFieldKey=copies[0]?.key||activeFieldKey;activeStructureSelection={type:'row',row:Number(copies[0]?.config?.layout?.row||insertRow)};renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();sync();clearTimeout(historyTimer);pushHistory();}
function requestRemoveLayoutRow(rowNo){rowNo=Math.max(1,Number(rowNo)||1);const items=fieldsInRow(rowNo).map(([f])=>f),count=items.length;if(!count)return;const meta=rowMeta(rowNo),title=meta.title||`${structureUi.row} ${rowNo}`;confirmDelete(`la riga “${title}” con ${count} camp${count===1?'o':'i'}`,()=>{const refs=new Set(items);for(let i=selected.length-1;i>=0;i--){if(refs.has(selected[i]))selected.splice(i,1);}if(builderConfig?.layout?.row_meta)delete builderConfig.layout.row_meta[String(rowNo)];activeStructureSelection=null;activeFieldKey=selected[0]?.key||null;normalizeLayoutRows();repairInvalidRows();renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();renderAdditional();sync();clearTimeout(historyTimer);pushHistory();});}
'''
s=s.replace(helper_anchor,helpers+helper_anchor,1)

# Row settings panel gets the same lightweight UI actions.
pat=r"function renderRowSettings\(rowNo\)\{.*?\}\nfunction selectRowSettings"
m=re.search(pat,s,re.S)
if not m: raise SystemExit('1.3.40: renderRowSettings block missing')
new_row_settings=r'''function renderRowSettings(rowNo){const meta=rowMeta(rowNo);sel.innerHTML='';const d=document.createElement('div');d.className='df-selected-item is-open df-structure-settings';d.innerHTML=`<div class="df-selected-top"><div class="df-field-toggle-main"><strong>${esc(structureUi.rowSettings)}</strong><span class="df-field-summary"><span class="df-summary-chip">${esc(structureUi.row)} ${rowNo}</span></span></div><div class="df-mini-actions"><button type="button" data-row-copy class="df-icon-only" title="Duplica riga" aria-label="Duplica riga">${modernUiIcon('copy')}</button><button type="button" data-row-remove class="df-icon-only df-row-remove" title="Elimina riga" aria-label="Elimina riga">${modernUiIcon('trash')}</button></div></div><div class="df-selected-config-wrap"><div class="df-selected-config-inner"><div class="df-selected-config"><details class="full df-main-settings" open><summary>${esc(structureUi.rowSettings)}</summary><div class="df-main-settings-body"><div class="df-main-settings-grid"><div class="full"><label>${esc(structureUi.title)}</label><input data-row-title value="${esc(meta.title||'')}" placeholder="${esc(structureUi.row)} ${rowNo}"></div><div class="full"><label>${esc(structureUi.description)}</label><textarea class="df-options" data-row-description>${esc(meta.description||'')}</textarea></div><div class="full df-note">Titolo e descrizione della riga servono per organizzare più velocemente il Builder e non vengono inviati come dati del modulo.</div></div></div></details></div></div></div>`;d.querySelector('[data-row-title]').oninput=e=>{meta.title=e.target.value;sync();renderLayoutCanvas();};d.querySelector('[data-row-description]').oninput=e=>{meta.description=e.target.value;sync();renderLayoutCanvas();};d.querySelector('[data-row-copy]').onclick=()=>duplicateLayoutRow(rowNo);d.querySelector('[data-row-remove]').onclick=()=>requestRemoveLayoutRow(rowNo);sel.appendChild(d);sync();}
function selectRowSettings'''
s=s[:m.start()]+new_row_settings+s[m.end():]

# Add actions to every real row header, matching section/field iconography.
old="rowHasSection=fieldsInRow(model.rowNo).some(([f])=>isLayoutSectionField(f)),rowHandle=rowHasSection?'':`<span class=\"df-layout-structure-handle df-row-drag-handle\" role=\"button\" tabindex=\"0\" title=\"Trascina riga\" aria-label=\"Trascina riga\">${modernUiIcon('grip')}</span>`;rowHead.innerHTML=`${rowHandle}<span class=\"df-layout-row-chevron\">›</span><span class=\"df-layout-row-label\">${esc(rowTitle)}</span>${meta.description?`<span class=\"df-layout-structure-description\">${esc(meta.description)}</span>`:''}<span class=\"df-layout-row-summary\">${model.items.length} ${esc(structureUi.fields)} · ${esc(widths)}</span>`;const rowDragHandle=rowHead.querySelector('.df-row-drag-handle');rowDragHandle?.addEventListener('pointerdown',e=>structureQueue(e,rowDragHandle,'row',model.rowNo,rowTitle));rowDragHandle?.addEventListener('click',e=>e.stopPropagation());const toggleRow=()=>{"
new="rowHasSection=fieldsInRow(model.rowNo).some(([f])=>isLayoutSectionField(f)),rowHandle=rowHasSection?'':`<span class=\"df-layout-structure-handle df-row-drag-handle\" role=\"button\" tabindex=\"0\" title=\"Trascina riga\" aria-label=\"Trascina riga\">${modernUiIcon('grip')}</span>`,rowActions=rowHasSection?'':`<span class=\"df-layout-row-actions\"><button type=\"button\" data-row-edit class=\"df-icon-only\" title=\"Modifica riga\" aria-label=\"Modifica riga\">${modernUiIcon('edit')}</button><button type=\"button\" data-row-copy class=\"df-icon-only\" title=\"Duplica riga\" aria-label=\"Duplica riga\">${modernUiIcon('copy')}</button><button type=\"button\" data-row-remove class=\"df-icon-only df-row-remove\" title=\"Elimina riga\" aria-label=\"Elimina riga\">${modernUiIcon('trash')}</button></span>`;rowHead.innerHTML=`${rowHandle}<span class=\"df-layout-row-chevron\">›</span><span class=\"df-layout-row-label\">${esc(rowTitle)}</span>${meta.description?`<span class=\"df-layout-structure-description\">${esc(meta.description)}</span>`:''}<span class=\"df-layout-row-summary\">${model.items.length} ${esc(structureUi.fields)} · ${esc(widths)}</span>${rowActions}`;const rowDragHandle=rowHead.querySelector('.df-row-drag-handle');rowDragHandle?.addEventListener('pointerdown',e=>structureQueue(e,rowDragHandle,'row',model.rowNo,rowTitle));rowDragHandle?.addEventListener('click',e=>e.stopPropagation());rowHead.querySelector('[data-row-edit]')?.addEventListener('click',e=>{e.stopPropagation();selectRowSettings(model.rowNo);});rowHead.querySelector('[data-row-copy]')?.addEventListener('click',e=>{e.stopPropagation();duplicateLayoutRow(model.rowNo);});rowHead.querySelector('[data-row-remove]')?.addEventListener('click',e=>{e.stopPropagation();requestRemoveLayoutRow(model.rowNo);});const toggleRow=()=>{"
if old not in s: raise SystemExit('1.3.40: row header actions anchor missing')
s=s.replace(old,new,1)
old="rowHead.onclick=e=>{if(Date.now()<structureSuppressClickUntil||e.target.closest('.df-layout-structure-handle'))return;if(e.target.closest('.df-layout-row-chevron'))toggleRow();else selectRowSettings(model.rowNo);};"
new="rowHead.onclick=e=>{if(Date.now()<structureSuppressClickUntil||e.target.closest('.df-layout-structure-handle')||e.target.closest('button'))return;if(e.target.closest('.df-layout-row-chevron'))toggleRow();else selectRowSettings(model.rowNo);};"
if old not in s: raise SystemExit('1.3.40: row click guard anchor missing')
s=s.replace(old,new,1)

# ---------------------------------------------------------------------------
# 3) Structural drag: real, spaced drop zones between sections and rows.
# ---------------------------------------------------------------------------
old="function structureClearTargets(){layoutCanvas?.querySelectorAll('.is-structure-before,.is-structure-after,.is-structure-inside').forEach(el=>el.classList.remove('is-structure-before','is-structure-after','is-structure-inside'));}"
new="function structureClearTargets(){layoutCanvas?.querySelectorAll('.is-structure-before,.is-structure-after,.is-structure-inside,.is-section-drop-before,.is-section-drop-after,.is-row-drop-before,.is-row-drop-after').forEach(el=>el.classList.remove('is-structure-before','is-structure-after','is-structure-inside','is-section-drop-before','is-section-drop-after','is-row-drop-before','is-row-drop-after'));layoutCanvas?.querySelectorAll('[data-structure-drop-label]').forEach(el=>el.removeAttribute('data-structure-drop-label'));}"
if old not in s: raise SystemExit('1.3.40: structureClearTargets anchor missing')
s=s.replace(old,new,1)
old=re.search(r"function structureRenderTarget\(spec\)\{.*?\}\n\n",s,re.S)
if not old: raise SystemExit('1.3.40: structureRenderTarget block missing')
new_render=r'''function structureRenderTarget(spec){if(structureSpecKey(spec)===structureSpecKey(structureDrag.spec))return;structureClearTargets();structureDrag.spec=spec;if(!spec)return;if(spec.kind==='sectionMove'){const group=layoutCanvas?.querySelector(`.df-layout-section-group[data-section-id="${CSS.escape(spec.targetId)}"]`);if(group){group.classList.add(spec.position==='before'?'is-section-drop-before':'is-section-drop-after');group.dataset.structureDropLabel=spec.position==='before'?'SPOSTA QUI · SOPRA':'SPOSTA QUI · SOTTO';}}else if(spec.kind==='row'){const group=layoutCanvas?.querySelector(`.df-layout-row-group[data-row-no="${Number(spec.targetRow)}"]`);if(group){group.classList.add(spec.position==='before'?'is-row-drop-before':'is-row-drop-after');group.dataset.structureDropLabel=spec.position==='before'?'SPOSTA QUI · SOPRA':'SPOSTA QUI · SOTTO';}}else if(spec.kind==='section'){const head=layoutCanvas?.querySelector(`.df-layout-section-group[data-section-id="${CSS.escape(spec.sectionId)}"] > .df-layout-section-head`);head?.classList.add('is-structure-inside');}}

'''
s=s[:old.start()]+new_render+s[old.end():]

pat=r"function structureFindTarget\(x,y\)\{.*?\n\}\nfunction structureBegin"
m=re.search(pat,s,re.S)
if not m: raise SystemExit('1.3.40: structureFindTarget block missing')
new_target=r'''function structureFindTarget(x,y){const stack=document.elementsFromPoint?document.elementsFromPoint(x,y):[];
 if(structureDrag.type==='section'){
  const head=stack.find(el=>el?.classList?.contains('df-layout-section-head'));if(head){const wrap=head.closest('.df-layout-section-group'),targetId=wrap?.dataset.sectionId;if(targetId&&targetId!==structureDrag.id){const r=head.getBoundingClientRect();return{kind:'sectionMove',targetId,position:y<r.top+r.height/2?'before':'after'};}}
  let best=null,dist=Infinity;for(const group of [...(layoutCanvas?.querySelectorAll('.df-layout-section-group')||[])]){const targetId=group.dataset.sectionId;if(!targetId||targetId===structureDrag.id)continue;const r=group.getBoundingClientRect();let d=Infinity,position='before';if(y<r.top){d=r.top-y;position='before';}else if(y>r.bottom){d=y-r.bottom;position='after';}if(d<dist){dist=d;best={kind:'sectionMove',targetId,position};}}if(best&&dist<=26)return best;return null;
 }
 if(structureDrag.type==='row'){
  const rowHead=stack.find(el=>el?.classList?.contains('df-layout-row-head'));if(rowHead){const group=rowHead.closest('.df-layout-row-group'),targetRow=Number(group?.dataset.rowNo||0);if(targetRow&&targetRow!==Number(structureDrag.id)){const r=rowHead.getBoundingClientRect();return{kind:'row',targetRow,position:y<r.top+r.height/2?'before':'after'};}}
  let best=null,dist=Infinity;for(const group of [...(layoutCanvas?.querySelectorAll('.df-layout-row-group')||[])]){const targetRow=Number(group.dataset.rowNo||0);if(!targetRow||targetRow===Number(structureDrag.id))continue;const r=group.getBoundingClientRect();let d=Infinity,position='before';if(y<r.top){d=r.top-y;position='before';}else if(y>r.bottom){d=y-r.bottom;position='after';}if(d<dist){dist=d;best={kind:'row',targetRow,position};}}if(best&&dist<=18)return best;
  const secHead=stack.find(el=>el?.classList?.contains('df-layout-section-head'));if(secHead){const wrap=secHead.closest('.df-layout-section-group'),sectionId=wrap?.dataset.sectionId;if(sectionId)return{kind:'section',sectionId};}
 }
 return null;
}
function structureBegin'''
s=s[:m.start()]+new_target+s[m.end():]

# ---------------------------------------------------------------------------
# 4) Visual polish for drop zones and row action icons.
# ---------------------------------------------------------------------------
css=r'''
/* Forms 1.3.40: clearer row/section actions and drag targets. */
.df-layout-row-actions{display:inline-flex;align-items:center;gap:2px;margin-left:2px}.df-layout-row-actions .df-icon-only{width:30px;height:30px;min-width:30px}.df-row-remove:hover,.df-row-remove:focus-visible,[data-row-remove]:hover,[data-row-remove]:focus-visible{color:#dc3545!important;background:color-mix(in srgb,#dc3545 9%,transparent)!important}
.df-smart-row-join-target>.df-layout-row-head{box-shadow:inset 0 0 0 2px color-mix(in srgb,#7c3aed 80%,transparent)!important;background:color-mix(in srgb,#7c3aed 7%,var(--bs-body-bg,#fff))!important}.df-smart-row-join-preview{display:flex;align-items:center;justify-content:space-between;gap:10px;min-height:38px;margin:6px 8px;padding:7px 10px;border:1.5px dashed #7c3aed;border-radius:8px;background:color-mix(in srgb,#7c3aed 6%,var(--bs-body-bg,#fff));color:#6d28d9;pointer-events:none}.df-smart-row-join-label{font-size:10px;font-weight:950;letter-spacing:.045em}.df-smart-row-join-field{min-width:0;max-width:55%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:11px;font-weight:800;color:var(--bs-body-color,#1f2937)}
body.df-structure-drag-active .df-layout-section-group{margin-top:10px;margin-bottom:10px}body.df-structure-drag-active .df-layout-row-group{margin-top:6px;margin-bottom:6px}.df-layout-section-group,.df-layout-row-group{position:relative}.df-layout-section-group.is-section-drop-before::before,.df-layout-section-group.is-section-drop-after::after,.df-layout-row-group.is-row-drop-before::before,.df-layout-row-group.is-row-drop-after::after{content:attr(data-structure-drop-label);position:absolute;left:9px;right:9px;z-index:30;height:20px;display:flex;align-items:center;justify-content:center;border-top:2px solid #7c3aed;color:#6d28d9;font-size:9px;font-weight:950;letter-spacing:.055em;line-height:1;pointer-events:none;text-shadow:0 0 5px var(--bs-body-bg,#fff),0 0 5px var(--bs-body-bg,#fff)}.df-layout-section-group.is-section-drop-before::before{top:-17px}.df-layout-section-group.is-section-drop-after::after{bottom:-19px}.df-layout-row-group.is-row-drop-before::before{top:-11px;height:15px}.df-layout-row-group.is-row-drop-after::after{bottom:-13px;height:15px}
[data-bs-theme="dark"] .df-layout-section-group.is-section-drop-before::before,[data-bs-theme="dark"] .df-layout-section-group.is-section-drop-after::after,[data-bs-theme="dark"] .df-layout-row-group.is-row-drop-before::before,[data-bs-theme="dark"] .df-layout-row-group.is-row-drop-after::after{color:#c4b5fd;text-shadow:0 0 5px var(--bs-body-bg,#111827),0 0 5px var(--bs-body-bg,#111827)}
@media(max-width:820px){.df-layout-row-actions{gap:0}.df-layout-row-actions .df-icon-only{width:32px;height:32px;min-width:32px}.df-smart-row-join-preview{margin:6px 4px}}
'''
if '</style>' not in s: raise SystemExit('1.3.40: style anchor missing')
s=s.replace('</style>',css+'</style>',1)

# Runtime marker, before the generic metadata replacement below.
s=s.replace("window.dfBuilderRuntime={version:'1.3.39'","window.dfBuilderRuntime={version:'1.3.40'",1)

checks=['kind:\'joinrow\'','function smartMoveToExistingRow','function duplicateLayoutRow','function requestRemoveLayoutRow','data-row-remove','is-section-drop-before','df-smart-row-join-preview',"version:'1.3.40'"]
for c in checks:
    if c not in s: raise SystemExit('1.3.40 missing '+c)
p.write_text(s,encoding='utf-8')
PY

# Keep all component/package version metadata coherent.
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$TMP/component" || true)
php -l "$B" >/dev/null

# Syntax-check the modified JS regions without executing browser code.
python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
a=s.index('const smartDrag=');b=s.index('const aiAllowedTypes=',a)
smart=re.sub(r"<\?php.*?\?>","null",s[a:b],flags=re.S)
Path('/tmp/forms-1340-smart.js').write_text(smart,encoding='utf-8')
a=s.index('function duplicateLayoutRow(');b=s.index('function renderColumns(',a)
layout=re.sub(r"<\?php.*?\?>","null",s[a:b],flags=re.S)
Path('/tmp/forms-1340-layout.js').write_text(layout,encoding='utf-8')
PY
node --check /tmp/forms-1340-smart.js >/dev/null
node --check /tmp/forms-1340-layout.js >/dev/null

# Rebuild component ZIP.
rm -f "$COMP_OLD"
(cd "$TMP/component" && zip -qr "$TMP/outer/com_decaroforms_$NEW.zip" .)

# Rebuild any additional nested extension ZIPs while preserving their content.
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
<changelogs><changelog><element>pkg_decaroforms</element><type>package</type><version>$NEW</version><feature>Drag campo: aggiunta una destinazione esplicita per inserire il campo in una riga esistente, distinta dalla creazione di una nuova riga.</feature><improvement>Il centro di una riga mostra “Aggiungi a Riga X”; le fasce superiore e inferiore restano dedicate a “Nuova riga”.</improvement><improvement>Righe: aggiunte azioni UI moderne Modifica, Duplica ed Elimina sia nell'intestazione sia nel pannello impostazioni.</improvement><improvement>L'eliminazione di una riga con campi richiede conferma prima di rimuovere la riga e i campi contenuti.</improvement><improvement>Drag sezione/riga: drop-zone più distanziate e leggibili con indicazione Sopra/Sotto, incluse light e dark mode.</improvement><improvement>Le icone restano borderless e coerenti con il Builder; Elimina usa stato rosso in hover/focus.</improvement><note>Mantenute tutte le funzioni della 1.3.39: importazione HTML/ZIP, sezioni, filtri Da controllare/Duplicati, drag intelligente e larghezze automatiche.</note><language>it-IT</language></changelog></changelogs>
EOF
rm -rf "$ROOT/releases/_upload"
echo "Built $TARGET"
echo "SHA256 $SHA"
