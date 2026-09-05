#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.34"
NEW="1.3.35"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1335-check.js /tmp/forms-1335-layout-test.js' EXIT
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

# Builder helper text: explain the new direct manipulation model, no extra controls.
s=s.replace('Trascina i campi per cambiare ordine o riga. La linea blu appare nel punto di rilascio.',
            'Trascina sopra, sotto, a sinistra o a destra: il Builder mostra subito dove finirà il campo.')

# Automatic row distribution used only when the number of fields changes through drag/drop.
old="function distributeRow(row){const items=fieldsInRow(row),n=items.length;if(!n)return;const base=Math.floor(100/n),extra=100-base*n;items.forEach(([f],i)=>{f.config.layout.width=base+(i<extra?1:0);f.config.layout.col=i+1;});}"
new="function smartAutoWidths(n){n=Math.max(1,Number(n)||1);if(n===1)return[100];if(n===2)return[50,50];if(n===3)return[33,33,34];if(n===4)return[25,25,25,25];const base=Math.floor(100/n),extra=100-base*n;return Array.from({length:n},(_,i)=>base+(i>=n-extra?1:0));}\nfunction distributeRow(row){const items=fieldsInRow(row),n=items.length;if(!n)return;const widths=smartAutoWidths(n);items.forEach(([f],i)=>{f.config.layout.width=widths[i]??100;f.config.layout.col=i+1;});}"
if old not in s: raise SystemExit('1.3.35: distributeRow anchor missing')
s=s.replace(old,new,1)

# Insert the lightweight pointer-based smart drag engine before section/row rendering.
anchor="const layoutSectionState=new Map(),layoutRowState=new Map();"
if anchor not in s: raise SystemExit('1.3.35: layoutSectionState anchor missing')
engine=r'''
/* Forms 1.3.35: intelligent field drag & drop. No external dependency. */
const smartDrag={pending:null,active:false,pointerId:null,pointerType:'',fieldKey:'',sourceCard:null,sourceRow:null,ghost:null,spec:null,specKey:'',pressTimer:null,lastX:0,lastY:0};
let smartSuppressClickUntil=0;
const smartDragIgnoreSelector='button,select,input,textarea,a,label,[contenteditable="true"],summary,details';
function smartFieldIndex(key){return selected.findIndex(f=>f.key===key);}
function smartFieldByKey(key){const i=smartFieldIndex(key);return i>=0?selected[i]:null;}
function smartSpecId(spec){return spec?`${spec.kind}:${spec.targetKey||''}:${spec.row||''}:${spec.position||''}`:'';}
function smartCaptureRects(){const map=new Map();layoutCanvas?.querySelectorAll('.df-layout-card:not(.df-smart-source-hidden)').forEach(el=>{const r=el.getBoundingClientRect();if(r.width&&r.height)map.set(el.dataset.fieldKey,{left:r.left,top:r.top});});return map;}
function smartAnimateFrom(before){if(!before?.size)return;requestAnimationFrame(()=>{layoutCanvas?.querySelectorAll('.df-layout-card:not(.df-smart-source-hidden)').forEach(el=>{const b=before.get(el.dataset.fieldKey);if(!b||!el.animate)return;const r=el.getBoundingClientRect(),dx=b.left-r.left,dy=b.top-r.top;if(Math.abs(dx)<1&&Math.abs(dy)<1)return;el.animate([{transform:`translate(${dx}px,${dy}px)`},{transform:'translate(0,0)'}],{duration:175,easing:'cubic-bezier(.2,.75,.25,1)'});});});}
function smartRememberGrid(row){if(row&&!row.hasAttribute('data-smart-original-grid'))row.setAttribute('data-smart-original-grid',row.style.gridTemplateColumns||'');}
function smartSetGrid(row,widths){if(!row)return;smartRememberGrid(row);const vals=(Array.isArray(widths)&&widths.length?widths:[100]);row.style.gridTemplateColumns=vals.map(v=>`${Math.max(1,Number(v)||1)}fr`).join(' ');}
function smartRestorePreviewDom(){
 layoutCanvas?.querySelectorAll('.df-smart-placeholder,.df-smart-newrow-preview').forEach(el=>el.remove());
 layoutCanvas?.querySelectorAll('.df-smart-target-left,.df-smart-target-right,.df-smart-row-target-before,.df-smart-row-target-after').forEach(el=>el.classList.remove('df-smart-target-left','df-smart-target-right','df-smart-row-target-before','df-smart-row-target-after'));
 layoutCanvas?.querySelectorAll('.df-layout-row[data-smart-original-grid]').forEach(row=>{row.style.gridTemplateColumns=row.getAttribute('data-smart-original-grid')||'';row.removeAttribute('data-smart-original-grid');});
 layoutCanvas?.querySelectorAll('.df-smart-source-row-empty').forEach(el=>el.classList.remove('df-smart-source-row-empty'));
 if(smartDrag.active)smartReflowSourceRow();
}
function smartReflowSourceRow(){const row=smartDrag.sourceRow;if(!row?.isConnected)return;const visible=[...row.querySelectorAll('.df-layout-card:not(.df-smart-source-hidden)')];const group=row.closest('.df-layout-row-group');if(!visible.length){group?.classList.add('df-smart-source-row-empty');return;}group?.classList.remove('df-smart-source-row-empty');smartSetGrid(row,smartAutoWidths(visible.length));}
function smartCreateGhost(card,key,x,y){const f=smartFieldByKey(key),rect=card.getBoundingClientRect(),g=document.createElement('div');g.className='df-smart-drag-ghost';g.style.width=`${Math.min(Math.max(rect.width,210),380)}px`;g.innerHTML=`<span class="df-smart-ghost-handle">☰</span><strong>${esc(f?.label||'Campo')}</strong><span class="df-smart-ghost-meta">${esc(tr.types[f?.type]||f?.type||'')}</span>`;document.body.appendChild(g);smartDrag.ghost=g;smartPositionGhost(x,y);}
function smartPositionGhost(x,y){const g=smartDrag.ghost;if(!g)return;const pad=14,maxX=Math.max(8,window.innerWidth-g.offsetWidth-8),maxY=Math.max(8,window.innerHeight-g.offsetHeight-8);g.style.left=`${Math.min(maxX,Math.max(8,x+pad))}px`;g.style.top=`${Math.min(maxY,Math.max(8,y+pad))}px`;}
function smartPreviewBesideWidths(spec){const target=smartFieldByKey(spec.targetKey),source=smartFieldByKey(smartDrag.fieldKey);if(!target||!source)return[100];const row=Number(target.config?.layout?.row||1),same=Number(source.config?.layout?.row||1)===row,items=fieldsInRow(row).map(([f])=>f).filter(f=>f!==source),pos=Math.max(0,items.indexOf(target)+(spec.position==='after'?1:0));items.splice(pos,0,source);return same?items.map(f=>Math.max(1,Number(f.config?.layout?.width||100))):smartAutoWidths(items.length);}
function smartRenderPreview(spec){const id=smartSpecId(spec);if(id===smartDrag.specKey)return;const before=smartCaptureRects();smartRestorePreviewDom();smartDrag.spec=spec;smartDrag.specKey=id;if(!spec){smartAnimateFrom(before);return;}
 if(spec.kind==='beside'){
  const target=layoutCanvas?.querySelector(`.df-layout-card[data-field-key="${CSS.escape(spec.targetKey)}"]`);if(target){const row=target.closest('.df-layout-row'),ph=document.createElement('div');ph.className='df-smart-placeholder '+(spec.position==='before'?'is-left':'is-right');ph.innerHTML=`<span>${spec.position==='before'?'SINISTRA':'DESTRA'}</span>`;if(spec.position==='before')target.before(ph);else target.after(ph);target.classList.add(spec.position==='before'?'df-smart-target-left':'df-smart-target-right');smartSetGrid(row,smartPreviewBesideWidths(spec));}
 }else if(spec.kind==='newrow'){
  const row=layoutCanvas?.querySelector(`.df-layout-row[data-row="${Number(spec.row)}"]`),group=row?.closest('.df-layout-row-group');if(group){const ph=document.createElement('div');ph.className='df-smart-newrow-preview';ph.innerHTML=`<span class="df-smart-newrow-label">${spec.position==='before'?'SOPRA':'SOTTO'} · NUOVA RIGA</span><span class="df-smart-newrow-field">${esc(smartFieldByKey(smartDrag.fieldKey)?.label||'Campo')} · 100%</span>`;if(spec.position==='before')group.before(ph);else group.after(ph);group.classList.add(spec.position==='before'?'df-smart-row-target-before':'df-smart-row-target-after');}
 }else if(spec.kind==='append'){
  const ph=document.createElement('div');ph.className='df-smart-newrow-preview is-append';ph.innerHTML=`<span class="df-smart-newrow-label">NUOVA RIGA</span><span class="df-smart-newrow-field">${esc(smartFieldByKey(smartDrag.fieldKey)?.label||'Campo')} · 100%</span>`;layoutCanvas?.appendChild(ph);
 }
 smartAnimateFrom(before);
}
function smartClassifyCard(card,x,y){if(!card||card.dataset.fieldKey===smartDrag.fieldKey)return null;const target=smartFieldByKey(card.dataset.fieldKey),source=smartFieldByKey(smartDrag.fieldKey);if(!target||!source)return null;const r=card.getBoundingClientRect(),rx=(x-r.left)/Math.max(1,r.width),ry=(y-r.top)/Math.max(1,r.height),targetRow=Number(target.config?.layout?.row||1),sourceRow=Number(source.config?.layout?.row||1),count=fieldsInRow(targetRow).length+(sourceRow===targetRow?0:1),canSide=count<=4;
 if(canSide&&rx<=.28)return{kind:'beside',targetKey:target.key,position:'before'};
 if(canSide&&rx>=.72)return{kind:'beside',targetKey:target.key,position:'after'};
 return{kind:'newrow',row:targetRow,position:ry<.5?'before':'after'};
}
function smartNearestCardInRow(row,x,y){const cards=[...row.querySelectorAll('.df-layout-card:not(.df-smart-source-hidden)')];if(!cards.length)return null;let best=null,score=Infinity;for(const card of cards){const r=card.getBoundingClientRect(),cx=Math.max(r.left,Math.min(x,r.right)),cy=Math.max(r.top,Math.min(y,r.bottom)),d=(x-cx)**2+(y-cy)**2;if(d<score){score=d;best=card;}}return best;}
function smartFindDropSpec(x,y){const stack=document.elementsFromPoint?document.elementsFromPoint(x,y):[];let card=stack.find(el=>el?.classList?.contains('df-layout-card')&&!el.classList.contains('df-smart-source-hidden'));if(card)return smartClassifyCard(card,x,y);
 const row=stack.map(el=>el?.closest?.('.df-layout-row')).find(Boolean);if(row){card=smartNearestCardInRow(row,x,y);if(card)return smartClassifyCard(card,x,y);const rr=row.getBoundingClientRect();return{kind:'newrow',row:Number(row.dataset.row||1),position:y<rr.top+rr.height/2?'before':'after'};}
 const group=stack.map(el=>el?.closest?.('.df-layout-row-group')).find(Boolean);if(group){const rowEl=group.querySelector('.df-layout-row'),gr=group.getBoundingClientRect();if(rowEl)return{kind:'newrow',row:Number(rowEl.dataset.row||1),position:y<gr.top+gr.height/2?'before':'after'};}
 if(layoutNewRow){const r=layoutNewRow.getBoundingClientRect();if(x>=r.left&&x<=r.right&&y>=r.top-20&&y<=r.bottom+30)return{kind:'append'};}
 const groups=[...(layoutCanvas?.querySelectorAll('.df-layout-row-group')||[])].filter(g=>!g.classList.contains('df-smart-source-row-empty'));let nearest=null,dist=Infinity;for(const g of groups){const r=g.getBoundingClientRect(),d=y<r.top?r.top-y:y>r.bottom?y-r.bottom:0;if(d<dist){dist=d;nearest=g;}}if(nearest&&dist<48){const rowEl=nearest.querySelector('.df-layout-row'),r=nearest.getBoundingClientRect();if(rowEl)return{kind:'newrow',row:Number(rowEl.dataset.row||1),position:y<r.top+r.height/2?'before':'after'};}
 return null;
}
function smartShiftRowMeta(insertRow){builderConfig=builderConfig&&typeof builderConfig==='object'?builderConfig:{};builderConfig.layout=builderConfig.layout&&typeof builderConfig.layout==='object'?builderConfig.layout:{};const meta=builderConfig.layout.row_meta&&typeof builderConfig.layout.row_meta==='object'?builderConfig.layout.row_meta:{},next={};Object.keys(meta).forEach(k=>{const n=Number(k);next[String(Number.isFinite(n)&&n>=insertRow?n+1:n)]=meta[k];});builderConfig.layout.row_meta=next;}
function smartMoveBeside(index,targetIndex,position='after'){if(index<0||targetIndex<0||!selected[index]||!selected[targetIndex]||index===targetIndex)return false;const field=selected[index],target=selected[targetIndex],oldRow=Number(field.config?.layout?.row||1),targetRow=Number(target.config?.layout?.row||1),same=oldRow===targetRow,targetItems=fieldsInRow(targetRow).map(([f])=>f);if(!same&&targetItems.length>=4)return smartMoveNewRow(index,targetRow,'after');const oldNeighbors=fieldsInRow(oldRow).map(([f])=>f).filter(f=>f!==field),items=targetItems.filter(f=>f!==field),at=Math.max(0,items.indexOf(target)+(position==='after'?1:0));items.splice(at,0,field);items.forEach((f,i)=>{defaultFieldConfig(f);f.config.layout.row=targetRow;f.config.layout.col=i+1;});normalizeLayoutRows();sortSelectedByLayout();if(!same){if(oldNeighbors.length)distributeRow(Number(oldNeighbors[0].config.layout.row||1));distributeRow(Number(field.config.layout.row||1));}activeStructureSelection=null;activeFieldKey=field.key;return true;}
function smartMoveNewRow(index,targetRow,position='after'){if(index<0||!selected[index])return false;const field=selected[index],oldRow=Number(field.config?.layout?.row||1),oldItems=fieldsInRow(oldRow).map(([f])=>f),oldNeighbors=oldItems.filter(f=>f!==field);if(oldRow===Number(targetRow)&&oldItems.length===1)return false;const insertRow=Math.max(1,Number(targetRow)+(position==='after'?1:0));smartShiftRowMeta(insertRow);selected.forEach(f=>{defaultFieldConfig(f);if(f!==field&&Number(f.config.layout.row||1)>=insertRow)f.config.layout.row=Number(f.config.layout.row)+1;});field.config.layout={...(field.config.layout||{}),row:insertRow,col:1,width:100};normalizeLayoutRows();sortSelectedByLayout();if(oldNeighbors.length)distributeRow(Number(oldNeighbors[0].config.layout.row||1));distributeRow(Number(field.config.layout.row||1));activeStructureSelection=null;activeFieldKey=field.key;return true;}
function smartCommitSpec(spec,key){const index=smartFieldIndex(key);if(index<0||!spec)return false;let changed=false;if(spec.kind==='beside'){const ti=smartFieldIndex(spec.targetKey);changed=smartMoveBeside(index,ti,spec.position);}else if(spec.kind==='newrow')changed=smartMoveNewRow(index,Number(spec.row),spec.position);else if(spec.kind==='append'){const max=Math.max(1,...selected.map(f=>Number(f.config?.layout?.row||1)));changed=smartMoveNewRow(index,max,'after');}if(changed){sortSelectedByLayout();sync();renderSelected();clearTimeout(historyTimer);pushHistory();}return changed;}
function smartEndVisual(){clearTimeout(smartDrag.pressTimer);smartDrag.pressTimer=null;smartDrag.ghost?.remove();smartDrag.ghost=null;document.body.classList.remove('df-smart-drag-active');document.querySelector('.df-builder-workspace')?.classList.remove('is-smart-dragging');}
function smartBeginDrag(){const p=smartDrag.pending;if(!p||smartDrag.active||!p.card?.isConnected)return;smartDrag.active=true;smartDrag.pointerId=p.pointerId;smartDrag.pointerType=p.pointerType;smartDrag.fieldKey=p.fieldKey;smartDrag.sourceCard=p.card;smartDrag.sourceRow=p.card.closest('.df-layout-row');smartDrag.lastX=p.x;smartDrag.lastY=p.y;smartDrag.pending=null;clearTimeout(smartDrag.pressTimer);smartDrag.pressTimer=null;const before=smartCaptureRects();smartCreateGhost(p.card,p.fieldKey,p.x,p.y);p.card.classList.add('df-smart-source-hidden');document.body.classList.add('df-smart-drag-active');document.querySelector('.df-builder-workspace')?.classList.add('is-smart-dragging');smartReflowSourceRow();smartAnimateFrom(before);if(p.pointerType!=='mouse'&&navigator.vibrate)try{navigator.vibrate(12);}catch{};}
function smartCancelPending(){clearTimeout(smartDrag.pressTimer);smartDrag.pressTimer=null;smartDrag.pending=null;}
function smartQueueDrag(e,card,key){if(editorLocked||!e.isPrimary||(e.pointerType==='mouse'&&e.button!==0)||e.target.closest(smartDragIgnoreSelector))return;smartCancelPending();smartDrag.pending={pointerId:e.pointerId,pointerType:e.pointerType||'mouse',fieldKey:key,card,x:e.clientX,y:e.clientY,startX:e.clientX,startY:e.clientY};if(e.pointerType==='touch'||e.pointerType==='pen')smartDrag.pressTimer=setTimeout(()=>smartBeginDrag(),420);}
function smartPointerMove(e){const p=smartDrag.pending;if(p&&e.pointerId===p.pointerId&&!smartDrag.active){p.x=e.clientX;p.y=e.clientY;const d=Math.hypot(e.clientX-p.startX,e.clientY-p.startY);if(p.pointerType==='mouse'){if(d>=5)smartBeginDrag();}else if(d>10){smartCancelPending();return;}}if(!smartDrag.active||e.pointerId!==smartDrag.pointerId)return;e.preventDefault();smartDrag.lastX=e.clientX;smartDrag.lastY=e.clientY;smartPositionGhost(e.clientX,e.clientY);smartRenderPreview(smartFindDropSpec(e.clientX,e.clientY));}
function smartFinishDrag(commit,e){if(!smartDrag.active){smartCancelPending();return;}if(e&&e.pointerId!==smartDrag.pointerId)return;e?.preventDefault?.();const before=smartCaptureRects(),spec=smartDrag.spec,key=smartDrag.fieldKey;smartEndVisual();smartRestorePreviewDom();const changed=commit&&spec?smartCommitSpec(spec,key):false;smartSuppressClickUntil=Date.now()+320;smartDrag.active=false;smartDrag.pointerId=null;smartDrag.pointerType='';smartDrag.fieldKey='';smartDrag.sourceCard=null;smartDrag.sourceRow=null;smartDrag.spec=null;smartDrag.specKey='';if(!changed)renderLayoutCanvas();else renderLayoutCanvas();smartAnimateFrom(before);}
function smartPointerUp(e){if(smartDrag.active)smartFinishDrag(true,e);else if(smartDrag.pending&&e.pointerId===smartDrag.pending.pointerId)smartCancelPending();}
function smartPointerCancel(e){if(smartDrag.active)smartFinishDrag(false,e);else if(smartDrag.pending&&e.pointerId===smartDrag.pending.pointerId)smartCancelPending();}
window.addEventListener('pointermove',smartPointerMove,{passive:false});window.addEventListener('pointerup',smartPointerUp,{passive:false});window.addEventListener('pointercancel',smartPointerCancel,{passive:false});document.addEventListener('touchmove',e=>{if(smartDrag.active)e.preventDefault();},{passive:false});window.addEventListener('keydown',e=>{if(e.key==='Escape'&&smartDrag.active)smartFinishDrag(false);});
/* End Forms 1.3.35 intelligent field drag & drop. */
'''
s=s.replace(anchor,engine+'\n'+anchor,1)

# Replace the old native HTML5 card drag controls with the smart pointer engine.
start=s.find('function renderLayoutFieldCard(f,i,rowNo,row){')
end=s.find('function layoutGroups(){',start)
if start<0 or end<0: raise SystemExit('1.3.35: renderLayoutFieldCard block missing')
newcard=r'''function renderLayoutFieldCard(f,i,rowNo,row){
 const card=document.createElement('div');card.className='df-layout-card'+(f.key===activeFieldKey?' is-active':'');card.dataset.fieldKey=f.key;card.draggable=false;card.style.width='100%';const required=f.required?'<span class="df-required-badge">Obbligatorio</span>':'';
 card.innerHTML=`<span class="df-layout-handle" title="Trascina campo" aria-hidden="true">☰</span><strong>${esc(f.label)}</strong><span class="df-layout-meta"><span class="df-layout-type">${esc(tr.types[f.type]||f.type)}</span>${required}<select aria-label="Larghezza campo">${widthChoices(f.config.layout.width||100)}</select><span class="df-layout-actions"><button type="button" data-canvas-edit class="df-icon-only" title="Modifica campo" aria-label="Modifica campo">${uiIcon('edit')}</button><button type="button" data-canvas-duplicate class="df-icon-only" title="Duplica campo" aria-label="Duplica campo">${uiIcon('copy')}</button><button type="button" data-canvas-remove class="df-canvas-remove df-icon-only" title="Elimina campo" aria-label="Elimina campo">${uiIcon('trash')}</button></span></span>`;
 card.addEventListener('pointerdown',e=>smartQueueDrag(e,card,f.key));
 card.addEventListener('click',e=>{if(Date.now()<smartSuppressClickUntil||e.target.closest('button,select,input,textarea,a,label'))return;selectField(i);});
 card.querySelector('select').onchange=e=>setFieldWidth(i,Number(e.target.value));card.querySelector('[data-canvas-edit]').onclick=()=>selectField(i);card.querySelector('[data-canvas-duplicate]').onclick=()=>duplicateField(i);card.querySelector('[data-canvas-remove]').onclick=()=>confirmDelete(`il campo “${f.label||'Campo'}”`,()=>removeCanvasField(i));row.appendChild(card);
}
'''
s=s[:start]+newcard+s[end:]

# Disable legacy guide visuals if any old markup survives elsewhere.
css=r'''
/* Forms 1.3.35: smart drag visual language. */
.df-layout-drop-guide{display:none!important}
.df-layout-card{position:relative;cursor:grab;user-select:none;transition:border-color .16s ease,box-shadow .16s ease,background .16s ease}.df-layout-card:active{cursor:grabbing}.df-layout-card .df-layout-meta,.df-layout-card button,.df-layout-card select{cursor:auto}.df-layout-handle{display:inline-flex;align-items:center;justify-content:center;min-width:24px;min-height:30px;font-size:18px;line-height:1;color:var(--bs-secondary-color,#667085);cursor:grab}.df-layout-card:hover .df-layout-handle{color:var(--df)}
.df-smart-source-hidden{display:none!important}.df-smart-source-row-empty{display:none!important}
.df-builder-workspace.is-smart-dragging .df-layout-card:not(.df-smart-source-hidden){transition:border-color .14s ease,box-shadow .14s ease,background .14s ease}.df-builder-workspace.is-smart-dragging .df-layout-card:not(.df-smart-source-hidden):hover{border-color:color-mix(in srgb,var(--df) 45%,var(--df-border))}
.df-smart-drag-ghost{position:fixed;z-index:2147483646;pointer-events:none;display:grid;grid-template-columns:auto minmax(0,1fr) auto;align-items:center;gap:9px;min-height:48px;padding:9px 11px;border:2px solid var(--df);border-radius:9px;background:var(--bs-body-bg,#fff);color:var(--bs-body-color,#1f2937);box-shadow:0 16px 42px rgba(0,0,0,.24);opacity:.96;transform:rotate(.5deg)}.df-smart-drag-ghost strong{white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.df-smart-ghost-handle{font-size:18px;color:var(--df)}.df-smart-ghost-meta{font-size:11px;font-weight:800;color:var(--bs-secondary-color,#667085)}
.df-smart-placeholder{min-height:48px;border:2px dashed var(--df);border-radius:8px;background:color-mix(in srgb,var(--df) 7%,var(--bs-body-bg,#fff));display:flex;align-items:center;justify-content:center;color:var(--df);font-size:10px;font-weight:900;letter-spacing:.04em;pointer-events:none;animation:dfSmartPulse .7s ease-in-out infinite alternate}.df-smart-target-left{box-shadow:inset 3px 0 0 var(--df)}.df-smart-target-right{box-shadow:inset -3px 0 0 var(--df)}
.df-smart-newrow-preview{display:flex;align-items:center;justify-content:space-between;gap:10px;min-height:52px;margin:7px 0;padding:9px 11px;border:2px dashed var(--df);border-radius:9px;background:color-mix(in srgb,var(--df) 6%,var(--bs-body-bg,#fff));color:var(--df);pointer-events:none}.df-smart-newrow-label{font-size:10px;font-weight:950;letter-spacing:.05em}.df-smart-newrow-field{min-width:0;max-width:70%;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:12px;font-weight:800;color:var(--bs-body-color,#1f2937)}.df-smart-row-target-before>.df-layout-row-head{box-shadow:inset 0 3px 0 var(--df)}.df-smart-row-target-after>.df-layout-row-head{box-shadow:inset 0 -3px 0 var(--df)}
body.df-smart-drag-active,body.df-smart-drag-active *{cursor:grabbing!important}body.df-smart-drag-active{user-select:none}
@keyframes dfSmartPulse{from{box-shadow:0 0 0 0 color-mix(in srgb,var(--df) 8%,transparent)}to{box-shadow:0 0 0 4px color-mix(in srgb,var(--df) 10%,transparent)}}
@media(max-width:820px){.df-layout-card{touch-action:pan-y}.df-layout-handle{min-width:32px;min-height:36px}.df-smart-drag-ghost{max-width:calc(100vw - 24px)}}
'''
if '</style>' not in s: raise SystemExit('1.3.35: style closing anchor missing')
s=s.replace('</style>',css+'</style>',1)

# Runtime marker.
s=s.replace("window.dfBuilderRuntime={version:'1.3.34'","window.dfBuilderRuntime={version:'1.3.35'",1)

# Static guardrails.
checks=['function smartAutoWidths','function smartQueueDrag','function smartFindDropSpec','function smartMoveBeside','function smartMoveNewRow','df-smart-placeholder','SOPRA','SOTTO','SINISTRA','DESTRA','NUOVA RIGA',"version:'1.3.35'",'card.draggable=false','☰']
for c in checks:
    if c not in s: raise SystemExit('1.3.35 missing '+c)
p.write_text(s,encoding='utf-8')
PY

# Version metadata across component/subpackages.
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$TMP/component" || true)
php -l "$B" >/dev/null

# Syntax-check the substantial Builder JS region.
python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
a=s.index('function smartAutoWidths')
b=s.index('// Statuses and columns.',a)
js=s[a:b]
js=re.sub(r"<\?php.*?\?>","X",js,flags=re.S)
Path('/tmp/forms-1335-check.js').write_text(js,encoding='utf-8')
PY
node --check /tmp/forms-1335-check.js >/dev/null

# Small deterministic layout tests for the automatic distribution rules.
cat > /tmp/forms-1335-layout-test.js <<'JS'
function smartAutoWidths(n){n=Math.max(1,Number(n)||1);if(n===1)return[100];if(n===2)return[50,50];if(n===3)return[33,33,34];if(n===4)return[25,25,25,25];const base=Math.floor(100/n),extra=100-base*n;return Array.from({length:n},(_,i)=>base+(i>=n-extra?1:0));}
const expected={1:[100],2:[50,50],3:[33,33,34],4:[25,25,25,25]};for(const [n,w] of Object.entries(expected)){const got=smartAutoWidths(Number(n));if(JSON.stringify(got)!==JSON.stringify(w))throw new Error(`${n}: ${got}`);if(got.reduce((a,b)=>a+b,0)!==100)throw new Error(`sum ${n}`);}console.log('layout rules ok');
JS
node /tmp/forms-1335-layout-test.js >/dev/null

rm -f "$COMP_OLD"
(cd "$TMP/component" && zip -qr "$TMP/outer/com_decaroforms_$NEW.zip" .)
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
<changelogs><changelog><element>pkg_decaroforms</element><type>package</type><version>$NEW</version><feature>Builder campi: drag &amp; drop intelligente con rilevamento automatico Sopra, Sotto, Sinistra, Destra e Nuova riga.</feature><feature>Stessa riga automatica con ridistribuzione 100%, 50/50, circa 33/33/33 e 25/25/25/25.</feature><feature>Rimozione da una riga: i campi rimasti si ridistribuiscono automaticamente.</feature><improvement>Anteprima visiva durante il trascinamento con placeholder e animazione degli altri campi.</improvement><improvement>Trascinamento avviabile da tutta la barra del campo, esclusi pulsanti, select, input e controlli.</improvement><improvement>Touch/tablet: pressione lunga prima di entrare in modalità trascinamento e feedback visivo.</improvement><note>Le larghezze manuali esistenti restano modificabili dopo il drop. Nessuna dipendenza drag &amp; drop esterna aggiunta.</note><language>it-IT</language></changelog></changelogs>
EOF
rm -rf "$ROOT/releases/_upload"
echo "Built $TARGET"
echo "SHA256 $SHA"
