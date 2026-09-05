#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.35"
NEW="1.3.36"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1336-structure-drag.js' EXIT
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

# Insert structural drag engine before layoutGroups().
anchor='function layoutGroups(){'
if anchor not in s: raise SystemExit('1.3.36: layoutGroups anchor missing')
engine=r'''
/* Forms 1.3.36: drag whole sections and rows as structural blocks. */
const structureDrag={pending:null,active:false,pointerId:null,type:'',id:null,handle:null,ghost:null,spec:null,pressTimer:null,lastX:0,lastY:0};
let structureSuppressClickUntil=0;
function structureRowBlocks(){
 normalizeLayoutRows();
 const meta=builderConfig?.layout?.row_meta&&typeof builderConfig.layout.row_meta==='object'?builderConfig.layout.row_meta:{};
 return [...new Set(selected.map(f=>Number(f.config?.layout?.row||1)))].sort((a,b)=>a-b).map(rowNo=>{const fields=fieldsInRow(rowNo).map(([f])=>f);return{rowNo,fields,meta:meta[String(rowNo)]?clone(meta[String(rowNo)]):null,sectionKey:fields.find(isLayoutSectionField)?.key||null};});
}
function structureApplyBlocks(blocks){
 builderConfig=builderConfig&&typeof builderConfig==='object'?builderConfig:{};builderConfig.layout=builderConfig.layout&&typeof builderConfig.layout==='object'?builderConfig.layout:{};
 const nextMeta={},ordered=[];
 blocks.forEach((block,bi)=>{const row=bi+1;if(block.meta&&typeof block.meta==='object'&&(block.meta.title||block.meta.description))nextMeta[String(row)]=clone(block.meta);block.fields.forEach((f,ci)=>{defaultFieldConfig(f);f.config.layout={...(f.config.layout||{}),row,col:ci+1};ordered.push(f);});});
 builderConfig.layout.row_meta=nextMeta;selected.splice(0,selected.length,...ordered);sortSelectedByLayout();
}
function structureSectionRange(blocks,sectionId){
 if(sectionId==='general'){const end=blocks.findIndex(b=>b.sectionKey);return{start:0,end:end<0?blocks.length:end};}
 const key=String(sectionId||'').replace(/^section:/,'');const start=blocks.findIndex(b=>b.sectionKey===key);if(start<0)return null;let end=blocks.length;for(let i=start+1;i<blocks.length;i++){if(blocks[i].sectionKey){end=i;break;}}return{start,end};
}
function structureMoveSection(sourceId,targetId,position){
 if(!sourceId||sourceId==='general'||sourceId===targetId)return false;let blocks=structureRowBlocks(),src=structureSectionRange(blocks,sourceId);if(!src||src.start>=src.end)return false;const moved=blocks.splice(src.start,src.end-src.start);let target=structureSectionRange(blocks,targetId);let at;
 if(targetId==='general'){target=structureSectionRange(blocks,'general');at=position==='before'?0:(target?.end??0);}else if(target){at=position==='before'?target.start:target.end;}else at=blocks.length;
 blocks.splice(Math.max(0,Math.min(blocks.length,at)),0,...moved);structureApplyBlocks(blocks);const key=String(sourceId).replace(/^section:/,'');activeStructureSelection=null;activeFieldKey=key;layoutSectionState.set('section:'+key,true);return true;
}
function structureMoveRow(sourceRow,spec){
 sourceRow=Number(sourceRow);let blocks=structureRowBlocks(),si=blocks.findIndex(b=>Number(b.rowNo)===sourceRow);if(si<0||blocks[si].sectionKey)return false;const moved=blocks.splice(si,1)[0],anchorKey=moved.fields[0]?.key||'';let at=blocks.length;
 if(spec.kind==='row'){const ti=blocks.findIndex(b=>Number(b.rowNo)===Number(spec.targetRow));if(ti<0)return false;at=ti+(spec.position==='after'?1:0);}else if(spec.kind==='section'){const range=structureSectionRange(blocks,spec.sectionId);if(spec.sectionId==='general')at=range?.end??0;else at=range?range.start+1:blocks.length;}else return false;
 blocks.splice(Math.max(0,Math.min(blocks.length,at)),0,moved);structureApplyBlocks(blocks);const field=anchorKey?selected.find(f=>f.key===anchorKey):null,newRow=Number(field?.config?.layout?.row||1);activeFieldKey=field?.key||activeFieldKey;activeStructureSelection={type:'row',row:newRow};layoutRowState.set(newRow,true);return true;
}
function structureClearTargets(){layoutCanvas?.querySelectorAll('.is-structure-before,.is-structure-after,.is-structure-inside').forEach(el=>el.classList.remove('is-structure-before','is-structure-after','is-structure-inside'));}
function structureSpecKey(spec){return spec?JSON.stringify(spec):'';}
function structureRenderTarget(spec){if(structureSpecKey(spec)===structureSpecKey(structureDrag.spec))return;structureClearTargets();structureDrag.spec=spec;if(!spec)return;if(spec.kind==='sectionMove'){const head=layoutCanvas?.querySelector(`.df-layout-section-group[data-section-id="${CSS.escape(spec.targetId)}"] > .df-layout-section-head`);head?.classList.add(spec.position==='before'?'is-structure-before':'is-structure-after');}else if(spec.kind==='row'){const head=layoutCanvas?.querySelector(`.df-layout-row-group[data-row-no="${Number(spec.targetRow)}"] > .df-layout-row-head`);head?.classList.add(spec.position==='before'?'is-structure-before':'is-structure-after');}else if(spec.kind==='section'){const head=layoutCanvas?.querySelector(`.df-layout-section-group[data-section-id="${CSS.escape(spec.sectionId)}"] > .df-layout-section-head`);head?.classList.add('is-structure-inside');}}
function structureGhost(label,type,x,y){const g=document.createElement('div');g.className='df-structure-drag-ghost';g.innerHTML=`<span class="df-layout-structure-handle">☰</span><strong>${esc(label)}</strong><span>${type==='section'?'Sezione':'Riga'}</span>`;document.body.appendChild(g);structureDrag.ghost=g;structurePositionGhost(x,y);}
function structurePositionGhost(x,y){const g=structureDrag.ghost;if(!g)return;g.style.left=`${Math.min(window.innerWidth-g.offsetWidth-8,Math.max(8,x+14))}px`;g.style.top=`${Math.min(window.innerHeight-g.offsetHeight-8,Math.max(8,y+14))}px`;}
function structureFindTarget(x,y){const stack=document.elementsFromPoint?document.elementsFromPoint(x,y):[];
 if(structureDrag.type==='section'){
  const head=stack.find(el=>el?.classList?.contains('df-layout-section-head'));if(!head)return null;const wrap=head.closest('.df-layout-section-group'),targetId=wrap?.dataset.sectionId;if(!targetId||targetId===structureDrag.id)return null;const r=head.getBoundingClientRect();return{kind:'sectionMove',targetId,position:y<r.top+r.height/2?'before':'after'};
 }
 if(structureDrag.type==='row'){
  const rowHead=stack.find(el=>el?.classList?.contains('df-layout-row-head'));if(rowHead){const group=rowHead.closest('.df-layout-row-group'),targetRow=Number(group?.dataset.rowNo||0);if(targetRow&&targetRow!==Number(structureDrag.id)){const r=rowHead.getBoundingClientRect();return{kind:'row',targetRow,position:y<r.top+r.height/2?'before':'after'};}}
  const secHead=stack.find(el=>el?.classList?.contains('df-layout-section-head'));if(secHead){const wrap=secHead.closest('.df-layout-section-group'),sectionId=wrap?.dataset.sectionId;if(sectionId)return{kind:'section',sectionId};}
 }
 return null;
}
function structureBegin(){const q=structureDrag.pending;if(!q||structureDrag.active||!q.handle?.isConnected)return;structureDrag.active=true;structureDrag.pointerId=q.pointerId;structureDrag.type=q.type;structureDrag.id=q.id;structureDrag.handle=q.handle;structureDrag.lastX=q.x;structureDrag.lastY=q.y;structureDrag.pending=null;clearTimeout(structureDrag.pressTimer);structureDrag.pressTimer=null;structureGhost(q.label,q.type,q.x,q.y);document.body.classList.add('df-structure-drag-active');q.handle.closest(q.type==='section'?'.df-layout-section-group':'.df-layout-row-group')?.classList.add('is-structure-source');if(q.pointerType!=='mouse'&&navigator.vibrate)try{navigator.vibrate(10);}catch{}}
function structureQueue(e,handle,type,id,label){if(e.button!=null&&e.button!==0)return;e.stopPropagation();const q={pointerId:e.pointerId,pointerType:e.pointerType||'mouse',type,id,handle,label,x:e.clientX,y:e.clientY};structureDrag.pending=q;structureDrag.lastX=e.clientX;structureDrag.lastY=e.clientY;clearTimeout(structureDrag.pressTimer);if(q.pointerType!=='mouse')structureDrag.pressTimer=setTimeout(()=>{if(structureDrag.pending===q)structureBegin();},220);}
function structurePointerMove(e){const q=structureDrag.pending;if(q&&q.pointerId===e.pointerId&&!structureDrag.active){const d=Math.hypot(e.clientX-q.x,e.clientY-q.y);if(q.pointerType==='mouse'&&d>4)structureBegin();else if(q.pointerType!=='mouse'&&d>10){clearTimeout(structureDrag.pressTimer);structureDrag.pressTimer=null;structureDrag.pending=null;}return;}if(!structureDrag.active||e.pointerId!==structureDrag.pointerId)return;e.preventDefault();structureDrag.lastX=e.clientX;structureDrag.lastY=e.clientY;structurePositionGhost(e.clientX,e.clientY);structureRenderTarget(structureFindTarget(e.clientX,e.clientY));}
function structureFinish(e,cancel=false){if(structureDrag.pending&&e.pointerId===structureDrag.pending.pointerId){clearTimeout(structureDrag.pressTimer);structureDrag.pending=null;}if(!structureDrag.active||e.pointerId!==structureDrag.pointerId)return;const type=structureDrag.type,id=structureDrag.id,spec=structureDrag.spec;structureDrag.ghost?.remove();structureDrag.ghost=null;structureClearTargets();layoutCanvas?.querySelectorAll('.is-structure-source').forEach(el=>el.classList.remove('is-structure-source'));document.body.classList.remove('df-structure-drag-active');structureDrag.active=false;structureDrag.pointerId=null;structureDrag.type='';structureDrag.id=null;structureDrag.spec=null;structureSuppressClickUntil=Date.now()+260;if(cancel||!spec)return;let changed=false;if(type==='section'&&spec.kind==='sectionMove')changed=structureMoveSection(id,spec.targetId,spec.position);if(type==='row'&&(spec.kind==='row'||spec.kind==='section'))changed=structureMoveRow(id,spec);if(changed){sync();renderSelected();renderLayoutCanvas();clearTimeout(historyTimer);pushHistory();}}
document.addEventListener('pointermove',structurePointerMove,{passive:false});document.addEventListener('pointerup',e=>structureFinish(e,false));document.addEventListener('pointercancel',e=>structureFinish(e,true));
/* End Forms 1.3.36 structure drag. */
'''
s=s.replace(anchor,engine+'\n'+anchor,1)

# Section header: add drag handle for real sections and bind pointerdown.
old="const sectionDescription=group.sectionField?.[0]?.config?.content||'';head.innerHTML=`<span class=\"df-layout-section-chevron\">›</span><span class=\"df-layout-section-title\"><strong>${esc(group.title)}</strong>${sectionDescription?`<span class=\"df-layout-structure-description\">${esc(sectionDescription)}</span>`:''}<span class=\"df-layout-section-summary\">${count} ${esc(structureUi.fields)} · ${rowCount} ${esc(structureUi.rows)}</span></span>${sectionActions}`;"
new="const sectionDescription=group.sectionField?.[0]?.config?.content||'',sectionHandle=group.sectionField?`<span class=\"df-layout-structure-handle df-section-drag-handle\" role=\"button\" tabindex=\"0\" title=\"Trascina sezione\" aria-label=\"Trascina sezione\">☰</span>`:'';head.innerHTML=`${sectionHandle}<span class=\"df-layout-section-chevron\">›</span><span class=\"df-layout-section-title\"><strong>${esc(group.title)}</strong>${sectionDescription?`<span class=\"df-layout-structure-description\">${esc(sectionDescription)}</span>`:''}<span class=\"df-layout-section-summary\">${count} ${esc(structureUi.fields)} · ${rowCount} ${esc(structureUi.rows)}</span></span>${sectionActions}`;if(group.sectionField){const handle=head.querySelector('.df-section-drag-handle');handle?.addEventListener('pointerdown',e=>structureQueue(e,handle,'section',group.id,group.title));handle?.addEventListener('click',e=>{e.stopPropagation();});}"
if old not in s: raise SystemExit('1.3.36: section head anchor missing')
s=s.replace(old,new,1)

# Avoid selecting/toggling header immediately after a structural drag.
s=s.replace("head.addEventListener('click',e=>{if(e.target.closest('button'))return;", "head.addEventListener('click',e=>{if(Date.now()<structureSuppressClickUntil||e.target.closest('.df-layout-structure-handle'))return;if(e.target.closest('button'))return;",1)

# Row group gets stable row data attribute and row handle.
old="const rowSelected=activeStructureSelection?.type==='row'&&Number(activeStructureSelection.row)===Number(model.rowNo),rowActive=rowSelected||model.items.some(([f])=>f.key===activeFieldKey),rowOpen=layoutRowState.has(model.rowNo)?layoutRowState.get(model.rowNo):(rowActive||(sectionOpen&&group.rows.length===1));const rowGroup=document.createElement('div');rowGroup.className='df-layout-row-group'+(rowOpen?' is-open':'')+(rowSelected?' is-selected':'');const rowHead=document.createElement('div');"
new="const rowSelected=activeStructureSelection?.type==='row'&&Number(activeStructureSelection.row)===Number(model.rowNo),rowActive=rowSelected||model.items.some(([f])=>f.key===activeFieldKey),rowOpen=layoutRowState.has(model.rowNo)?layoutRowState.get(model.rowNo):(rowActive||(sectionOpen&&group.rows.length===1));const rowGroup=document.createElement('div');rowGroup.className='df-layout-row-group'+(rowOpen?' is-open':'')+(rowSelected?' is-selected':'');rowGroup.dataset.rowNo=String(model.rowNo);const rowHead=document.createElement('div');"
if old not in s: raise SystemExit('1.3.36: row group anchor missing')
s=s.replace(old,new,1)
old="const widths=model.items.map(([f])=>Number(f.config.layout.width||100)+'%').join(' + '),meta=rowMeta(model.rowNo),rowTitle=meta.title||`${structureUi.row} ${model.rowNo}`;rowHead.innerHTML=`<span class=\"df-layout-row-chevron\">›</span><span class=\"df-layout-row-label\">${esc(rowTitle)}</span>${meta.description?`<span class=\"df-layout-structure-description\">${esc(meta.description)}</span>`:''}<span class=\"df-layout-row-summary\">${model.items.length} ${esc(structureUi.fields)} · ${esc(widths)}</span>`;const toggleRow=()=>{"
new="const widths=model.items.map(([f])=>Number(f.config.layout.width||100)+'%').join(' + '),meta=rowMeta(model.rowNo),rowTitle=meta.title||`${structureUi.row} ${model.rowNo}`,rowHasSection=fieldsInRow(model.rowNo).some(([f])=>isLayoutSectionField(f)),rowHandle=rowHasSection?'':`<span class=\"df-layout-structure-handle df-row-drag-handle\" role=\"button\" tabindex=\"0\" title=\"Trascina riga\" aria-label=\"Trascina riga\">☰</span>`;rowHead.innerHTML=`${rowHandle}<span class=\"df-layout-row-chevron\">›</span><span class=\"df-layout-row-label\">${esc(rowTitle)}</span>${meta.description?`<span class=\"df-layout-structure-description\">${esc(meta.description)}</span>`:''}<span class=\"df-layout-row-summary\">${model.items.length} ${esc(structureUi.fields)} · ${esc(widths)}</span>`;const rowDragHandle=rowHead.querySelector('.df-row-drag-handle');rowDragHandle?.addEventListener('pointerdown',e=>structureQueue(e,rowDragHandle,'row',model.rowNo,rowTitle));rowDragHandle?.addEventListener('click',e=>e.stopPropagation());const toggleRow=()=>{"
if old not in s: raise SystemExit('1.3.36: row head anchor missing')
s=s.replace(old,new,1)
s=s.replace("rowHead.onclick=e=>{if(e.target.closest('.df-layout-row-chevron'))toggleRow();else selectRowSettings(model.rowNo);};", "rowHead.onclick=e=>{if(Date.now()<structureSuppressClickUntil||e.target.closest('.df-layout-structure-handle'))return;if(e.target.closest('.df-layout-row-chevron'))toggleRow();else selectRowSettings(model.rowNo);};",1)

# CSS: same visual language as field drag, with precise before/after/inside indicators.
css=r'''
/* Forms 1.3.36: draggable section/row structure. */
.df-layout-structure-handle{display:inline-grid;place-items:center;flex:0 0 24px;width:24px;height:28px;border:0;background:transparent;color:var(--bs-secondary-color,#667085);font-size:15px;line-height:1;cursor:grab;user-select:none;touch-action:none;border-radius:5px}.df-layout-structure-handle:hover,.df-layout-structure-handle:focus-visible{color:#7c3aed;background:color-mix(in srgb,#7c3aed 8%,transparent);outline:none}.df-layout-structure-handle:active{cursor:grabbing}
body.df-structure-drag-active{user-select:none;cursor:grabbing!important}body.df-structure-drag-active *{cursor:grabbing!important}.df-layout-section-group.is-structure-source,.df-layout-row-group.is-structure-source{opacity:.38}
.df-layout-section-head,.df-layout-row-head{position:relative}.df-layout-section-head.is-structure-before::before,.df-layout-row-head.is-structure-before::before,.df-layout-section-head.is-structure-after::after,.df-layout-row-head.is-structure-after::after{content:"";position:absolute;left:8px;right:8px;height:3px;border-radius:999px;background:#7c3aed;z-index:8}.df-layout-section-head.is-structure-before::before,.df-layout-row-head.is-structure-before::before{top:-2px}.df-layout-section-head.is-structure-after::after,.df-layout-row-head.is-structure-after::after{bottom:-2px}.df-layout-section-head.is-structure-inside{box-shadow:inset 0 0 0 2px #7c3aed!important;background:color-mix(in srgb,#7c3aed 8%,var(--bs-body-bg,#fff))!important}
.df-structure-drag-ghost{position:fixed;z-index:2147483646;pointer-events:none;display:flex;align-items:center;gap:9px;max-width:360px;min-width:190px;padding:9px 12px;border:1px solid color-mix(in srgb,#7c3aed 55%,var(--df-border));border-radius:9px;background:var(--bs-body-bg,#fff);color:var(--bs-body-color,#1f2937);box-shadow:0 14px 35px rgba(15,23,42,.22);font-size:12px}.df-structure-drag-ghost strong{min-width:0;flex:1;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.df-structure-drag-ghost>span:last-child{font-size:10px;font-weight:800;color:#7c3aed;text-transform:uppercase;letter-spacing:.04em}
'''
if '</style>' not in s: raise SystemExit('1.3.36: style end missing')
s=s.replace('</style>',css+'</style>',1)

s=s.replace("window.dfBuilderRuntime={version:'1.3.35'","window.dfBuilderRuntime={version:'1.3.36'",1)
checks=['function structureMoveSection','function structureMoveRow','function structureQueue','df-section-drag-handle','df-row-drag-handle','is-structure-inside',"version:'1.3.36'"]
for c in checks:
 if c not in s: raise SystemExit('1.3.36 missing '+c)
p.write_text(s,encoding='utf-8')
PY

# Version all text metadata in component and subpackages.
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$TMP/component" || true)
php -l "$B" >/dev/null

# Syntax-check the isolated structure-drag engine.
python3 - "$B" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
a=s.index('/* Forms 1.3.36: drag whole sections and rows as structural blocks. */')
b=s.index('/* End Forms 1.3.36 structure drag. */',a)+len('/* End Forms 1.3.36 structure drag. */')
Path('/tmp/forms-1336-structure-drag.js').write_text(s[a:b],encoding='utf-8')
PY
node --check /tmp/forms-1336-structure-drag.js >/dev/null

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
<changelogs><changelog><element>pkg_decaroforms</element><type>package</type><version>$NEW</version><feature>Struttura del modulo: le sezioni reali ora sono trascinabili come blocco completo con tutte le righe e i campi contenuti.</feature><feature>Le righe sono trascinabili come blocco mantenendo campi, ordine, larghezze, titolo e descrizione.</feature><feature>Una riga può essere trascinata direttamente sull'intestazione di un'altra sezione per spostarla dentro quella sezione.</feature><improvement>Indicatori viola Sopra/Sotto e evidenziazione della sezione di destinazione durante il trascinamento.</improvement><improvement>Supporto pointer per mouse, penna e touch con pressione lunga sui dispositivi touch.</improvement><note>La sezione Generale è implicita e resta fissa; le sezioni create nel Builder sono trascinabili dalla maniglia.</note><language>it-IT</language></changelog></changelogs>
EOF
rm -rf "$ROOT/releases/_upload"
echo "Built $TARGET"
echo "SHA256 $SHA"
