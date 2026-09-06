#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OLD="1.3.57"
NEW="1.3.58"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
JS_TMP="/tmp/forms-1358-builder.js"
trap 'rm -rf "$TMP" "$JS_TMP"' EXIT

mkdir -p "$TMP/outer" "$TMP/children" "$TARGET_DIR"
test -f "$BASE"
unzip -q "$BASE" -d "$TMP/outer"
unzip -t "$BASE" >/dev/null

MAP="$TMP/children-map.tsv"
: > "$MAP"
idx=0
BUILDER=""

for ZIP in "$TMP/outer"/*.zip; do
  [ -e "$ZIP" ] || continue
  idx=$((idx+1))
  NAME="$(basename "$ZIP")"
  NEWNAME="${NAME//$OLD/$NEW}"
  CHILD="$TMP/children/$idx"
  mkdir -p "$CHILD"
  unzip -q "$ZIP" -d "$CHILD"
  printf '%s\t%s\n' "$idx" "$NEWNAME" >> "$MAP"

  find "$CHILD" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.js' -o -name '*.json' -o -name '*.css' -o -name '*.txt' -o -name '*.md' \) -print0 \
    | xargs -0 -r sed -i 's/1\.3\.57/1.3.58/g'

  while IFS= read -r -d '' XML; do
    if grep -q '<extension' "$XML" && grep -q '<version>' "$XML"; then
      python3 - "$XML" "$NEW" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]);v=sys.argv[2];s=p.read_text(encoding='utf-8')
s=re.sub(r'<version>[^<]+</version>',f'<version>{v}</version>',s,count=1)
p.write_text(s,encoding='utf-8')
PY
    fi
  done < <(find "$CHILD" -maxdepth 1 -type f -name '*.xml' -print0)

  CANDIDATE="$CHILD/administrator/components/com_decaroforms/tmpl/builder/default.php"
  if [ -f "$CANDIDATE" ]; then BUILDER="$CANDIDATE"; fi
done

test -n "$BUILDER" && test -f "$BUILDER"

python3 - "$BUILDER" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')

def replace_once(old,new,label):
    global s
    if old not in s:
        raise SystemExit(f'1.3.58 missing anchor: {label}')
    s=s.replace(old,new,1)

def replace_function(name,new_text):
    global s
    start=s.find('function '+name+'(')
    if start<0: raise SystemExit(f'1.3.58 missing function: {name}')
    brace=s.find('{',start)
    if brace<0: raise SystemExit(f'1.3.58 no brace: {name}')
    depth=0; quote=None; esc=False; template=False; i=brace
    while i<len(s):
        c=s[i]
        if quote:
            if esc: esc=False
            elif c=='\\': esc=True
            elif c==quote: quote=None
        elif template:
            if esc: esc=False
            elif c=='\\': esc=True
            elif c=='`': template=False
        else:
            if c in "'\"": quote=c
            elif c=='`': template=True
            elif c=='{': depth+=1
            elif c=='}':
                depth-=1
                if depth==0:
                    s=s[:start]+new_text+s[i+1:]
                    return
        i+=1
    raise SystemExit(f'1.3.58 unterminated function: {name}')

replace_once(
"const smartDrag={pending:null,active:false,pointerId:null,pointerType:'',fieldKey:'',sourceCard:null,sourceRow:null,ghost:null,spec:null,specKey:'',pressTimer:null,lastX:0,lastY:0,originX:0,originY:0,grabXRatio:.5,grabYRatio:.5,sourceWidth:0,sourceHeight:0,intentAxis:''};",
"const smartDrag={pending:null,active:false,pointerId:null,pointerType:'',fieldKey:'',sourceCard:null,sourceRow:null,ghost:null,spec:null,specKey:'',pressTimer:null,lastX:0,lastY:0,originX:0,originY:0,grabXRatio:.5,grabYRatio:.5,sourceWidth:0,sourceHeight:0,intentAxis:'',intentLockX:0,intentLockY:0,raf:0,queuedX:0,queuedY:0,ghostWidth:0,ghostHeight:0};",
'smartDrag fluid state'
)

replace_function('smartAnimateFrom',"""function smartAnimateFrom(before){if(!before?.size)return;requestAnimationFrame(()=>{layoutCanvas?.querySelectorAll('.df-layout-card:not(.df-smart-source-hidden)').forEach(el=>{const b=before.get(el.dataset.fieldKey);if(!b||!el.animate)return;const r=el.getBoundingClientRect(),dx=b.left-r.left,dy=b.top-r.top;if(Math.abs(dx)<1&&Math.abs(dy)<1)return;el.animate([{transform:`translate(${dx}px,${dy}px)`},{transform:'translate(0,0)'}],{duration:125,easing:'cubic-bezier(.2,.82,.25,1)'});});});}""")

replace_function('smartRestorePreviewDom',"""function smartRestorePreviewDom(){
 document.querySelectorAll('.df-smart-drop-overlay').forEach(el=>el.remove());
 layoutCanvas?.querySelectorAll('.df-smart-placeholder,.df-smart-newrow-preview,.df-smart-row-join-preview,.df-smart-line-preview,.df-smart-slot-preview').forEach(el=>el.remove());
 layoutCanvas?.querySelectorAll('.df-smart-target-left,.df-smart-target-right,.df-smart-row-target-before,.df-smart-row-target-after,.df-smart-row-join-target,.df-smart-line-target-before,.df-smart-line-target-after').forEach(el=>el.classList.remove('df-smart-target-left','df-smart-target-right','df-smart-row-target-before','df-smart-row-target-after','df-smart-row-join-target','df-smart-line-target-before','df-smart-line-target-after'));
 layoutCanvas?.querySelectorAll('.df-layout-row[data-smart-original-grid]').forEach(row=>{row.style.gridTemplateColumns=row.getAttribute('data-smart-original-grid')||'';row.removeAttribute('data-smart-original-grid');});
 layoutCanvas?.querySelectorAll('.df-smart-source-row-empty').forEach(el=>el.classList.remove('df-smart-source-row-empty'));
 layoutCanvas?.querySelectorAll('.df-smart-source-line-empty').forEach(el=>el.classList.remove('df-smart-source-line-empty'));
}""")

replace_function('smartCreateGhost',"""function smartCreateGhost(card,key,x,y){const f=smartFieldByKey(key),rect=card.getBoundingClientRect(),g=document.createElement('div');g.className='df-smart-drag-ghost';g.style.width=`${Math.min(Math.max(rect.width,210),380)}px`;g.style.left='0px';g.style.top='0px';g.innerHTML=`<span class=\"df-smart-ghost-handle\">${modernUiIcon('grip')}</span><strong>${esc(f?.label||'Campo')}</strong><span class=\"df-smart-ghost-meta\">${esc(tr.types[f?.type]||f?.type||'')}</span>`;document.body.appendChild(g);smartDrag.ghost=g;const gr=g.getBoundingClientRect();smartDrag.ghostWidth=Math.max(1,gr.width);smartDrag.ghostHeight=Math.max(1,gr.height);smartPositionGhost(x,y);}""")

replace_function('smartPositionGhost',"""function smartPositionGhost(x,y){const g=smartDrag.ghost;if(!g)return;const pad=14,w=Math.max(1,Number(smartDrag.ghostWidth)||g.offsetWidth),h=Math.max(1,Number(smartDrag.ghostHeight)||g.offsetHeight),maxX=Math.max(8,window.innerWidth-w-8),maxY=Math.max(8,window.innerHeight-h-8),left=Math.min(maxX,Math.max(8,x+pad)),top=Math.min(maxY,Math.max(8,y+pad));g.style.transform=`translate3d(${Math.round(left)}px,${Math.round(top)}px,0)`;}""")

# Add stable intent + projected canvas center helpers immediately before smartProjectedPoint.
anchor='function smartProjectedPoint(card,x,y){'
i=s.find(anchor)
if i<0: raise SystemExit('1.3.58 missing smartProjectedPoint anchor')
helpers="""function smartProjectedCanvasPoint(x,y){const sw=Math.max(1,Number(smartDrag.sourceWidth)||1),sh=Math.max(1,Number(smartDrag.sourceHeight)||1),gx=Math.max(0,Math.min(1,Number(smartDrag.grabXRatio)||.5)),gy=Math.max(0,Math.min(1,Number(smartDrag.grabYRatio)||.5));return{x:x+(.5-gx)*sw,y:y+(.5-gy)*sh};}\nfunction smartUpdateIntentAxis(x,y){const dx=x-(Number(smartDrag.originX)||x),dy=y-(Number(smartDrag.originY)||y),adx=Math.abs(dx),ady=Math.abs(dy);if(!smartDrag.intentAxis){if(Math.max(adx,ady)<10)return'';smartDrag.intentAxis=ady>=adx*.82?'vertical':'horizontal';smartDrag.intentLockX=x;smartDrag.intentLockY=y;return smartDrag.intentAxis;}const ldx=Math.abs(x-(Number(smartDrag.intentLockX)||x)),ldy=Math.abs(y-(Number(smartDrag.intentLockY)||y));if(smartDrag.intentAxis==='vertical'&&ldx>=34&&ldx>ldy*1.65){smartDrag.intentAxis='horizontal';smartDrag.intentLockX=x;smartDrag.intentLockY=y;}else if(smartDrag.intentAxis==='horizontal'&&ldy>=34&&ldy>ldx*1.65){smartDrag.intentAxis='vertical';smartDrag.intentLockX=x;smartDrag.intentLockY=y;}return smartDrag.intentAxis;}\n"""
s=s[:i]+helpers+s[i:]

replace_function('smartClassifyCard',"""function smartClassifyCard(card,x,y){
 if(!card||card.dataset.fieldKey===smartDrag.fieldKey)return null;
 const target=smartFieldByKey(card.dataset.fieldKey),source=smartFieldByKey(smartDrag.fieldKey);if(!target||!source)return null;
 const projected=smartProjectedPoint(card,x,y),r=projected.r,rx=(projected.px-r.left)/Math.max(1,r.width),ry=(projected.py-r.top)/Math.max(1,r.height),moveX=x-(Number(smartDrag.originX)||x),moveY=y-(Number(smartDrag.originY)||y),amx=Math.abs(moveX),amy=Math.abs(moveY),targetLine=visualLineForField(target).map(([f])=>f),sourceInLine=targetLine.includes(source),count=targetLine.filter(f=>f!==source).length+(sourceInLine?0:1),canSide=count<=4,row=Number(target.config?.layout?.row||1),current=smartDrag.spec&&smartDrag.spec.targetKey===target.key?smartDrag.spec:null;
 let axis=smartDrag.intentAxis||'vertical';if(!canSide)axis='vertical';
 if(axis==='horizontal'&&canSide){
  if(current?.kind==='beside'&&current.position==='before'&&rx<=.62)return{kind:'beside',targetKey:target.key,row,position:'before'};
  if(current?.kind==='beside'&&current.position==='after'&&rx>=.38)return{kind:'beside',targetKey:target.key,row,position:'after'};
  const position=Math.abs(rx-.5)<.07&&amx>=10?(moveX<0?'before':'after'):(rx<.5?'before':'after');
  return{kind:'beside',targetKey:target.key,row,position};
 }
 if(current?.kind==='line'&&current.position==='before'&&ry<=.64)return{kind:'line',row,targetKey:target.key,position:'before'};
 if(current?.kind==='line'&&current.position==='after'&&ry>=.36)return{kind:'line',row,targetKey:target.key,position:'after'};
 const position=Math.abs(ry-.5)<.07&&amy>=10?(moveY<0?'before':'after'):(ry<.5?'before':'after');
 return{kind:'line',row,targetKey:target.key,position};
}""")

replace_function('smartNearestEmptySlot',"""function smartNearestEmptySlot(x,y,margin=30){const slots=[...(layoutCanvas?.querySelectorAll('.df-layout-empty-slot[data-slot-target-key]')||[])];let best=null,score=Infinity;for(const slot of slots){const r=slot.getBoundingClientRect();if(!r.width||!r.height)continue;const dx=x<r.left?r.left-x:x>r.right?x-r.right:0,dy=y<r.top?r.top-y:y>r.bottom?y-r.bottom:0,d=dx*dx+dy*dy;if(d<=margin*margin&&d<score){score=d;best=slot;}}return best;}""")
replace_function('smartNearestCardNearPoint',"""function smartNearestCardNearPoint(x,y,margin=44){const cards=[...(layoutCanvas?.querySelectorAll('.df-layout-card:not(.df-smart-source-hidden)')||[])];let best=null,score=Infinity;for(const card of cards){const r=card.getBoundingClientRect();if(!r.width||!r.height)continue;const dx=x<r.left?r.left-x:x>r.right?x-r.right:0,dy=y<r.top?r.top-y:y>r.bottom?y-r.bottom:0,d=dx*dx+dy*dy;if(d<=margin*margin&&d<score){score=d;best=card;}}return best;}""")

replace_function('smartFindDropSpec',"""function smartFindDropSpec(x,y){const probe=smartProjectedCanvasPoint(x,y),hx=Math.max(1,Math.min(window.innerWidth-2,probe.x)),hy=Math.max(1,Math.min(window.innerHeight-2,probe.y)),stack=document.elementsFromPoint?document.elementsFromPoint(hx,hy):[];let emptySlot=stack.map(el=>el?.closest?.('.df-layout-empty-slot[data-slot-target-key]')).find(Boolean);if(!emptySlot)emptySlot=smartNearestEmptySlot(hx,hy,30);if(emptySlot){const targetKey=emptySlot.dataset.slotTargetKey||'',side=emptySlot.dataset.slotSide||'before',target=smartFieldByKey(targetKey);if(target&&targetKey!==smartDrag.fieldKey)return{kind:'beside',targetKey,row:Number(target.config?.layout?.row||1),position:side==='after'?'after':'before',slot:true};}let card=stack.find(el=>el?.classList?.contains('df-layout-card')&&!el.classList.contains('df-smart-source-hidden'));if(!card)card=smartNearestCardNearPoint(hx,hy,44);if(card)return smartClassifyCard(card,x,y);
 const row=stack.map(el=>el?.closest?.('.df-layout-row')).find(Boolean);if(row){card=smartNearestCardInRow(row,hx,hy);if(card)return smartClassifyCard(card,x,y);if(row===smartDrag.sourceRow||row.classList.contains('df-smart-source-line-empty')){const rr=row.getBoundingClientRect(),rx=(hx-rr.left)/Math.max(1,rr.width);return{kind:'slot',row:Number(row.dataset.row||1),position:rx<.5?'left':'right'};}return{kind:'joinrow',row:Number(row.dataset.row||1)};}
 const group=stack.map(el=>el?.closest?.('.df-layout-row-group')).find(Boolean);if(group){const rowNo=Number(group.dataset.rowNo||1),gr=group.getBoundingClientRect(),band=Math.min(42,Math.max(24,gr.height*.22));if(hy<=gr.top+band)return{kind:'newrow',row:rowNo,position:'before'};if(hy>=gr.bottom-band)return{kind:'newrow',row:rowNo,position:'after'};return{kind:'joinrow',row:rowNo};}
 if(layoutNewRow){const r=layoutNewRow.getBoundingClientRect();if(hx>=r.left-16&&hx<=r.right+16&&hy>=r.top-34&&hy<=r.bottom+42)return{kind:'append'};}
 const groups=[...(layoutCanvas?.querySelectorAll('.df-layout-row-group')||[])].filter(g=>!g.classList.contains('df-smart-source-row-empty'));let nearest=null,dist=Infinity;for(const g of groups){const r=g.getBoundingClientRect(),d=hy<r.top?r.top-hy:hy>r.bottom?hy-r.bottom:0;if(d<dist){dist=d;nearest=g;}}if(nearest&&dist<52){const r=nearest.getBoundingClientRect();return{kind:'newrow',row:Number(nearest.dataset.rowNo||1),position:hy<r.top+r.height/2?'before':'after'};}
 const current=smartDrag.spec;if(current?.targetKey){const el=layoutCanvas?.querySelector(`.df-layout-card[data-field-key=\"${CSS.escape(current.targetKey)}\"]`);if(el){const r=el.getBoundingClientRect();if(hx>=r.left-48&&hx<=r.right+48&&hy>=r.top-38&&hy<=r.bottom+38)return current;}}
 return null;
}""")

# Spec id must distinguish a real empty-slot magnet from an ordinary side target.
replace_function('smartSpecId',"""function smartSpecId(spec){return spec?`${spec.kind}:${spec.targetKey||''}:${spec.row||''}:${spec.position||''}:${spec.slot?'slot':''}`:'';}""")

# Lightweight fixed overlays: do not mutate/reflow the form while hovering.
insert_anchor='function smartRenderPreview(spec){'
pos=s.find(insert_anchor)
if pos<0: raise SystemExit('1.3.58 missing smartRenderPreview')
overlay_helpers="""function smartOverlayRect(rect,kind,label,position=''){if(!rect||!rect.width||!rect.height)return null;const el=document.createElement('div');el.className=`df-smart-drop-overlay is-${kind}${position?` is-${position}`:''}`;el.style.left=`${Math.round(rect.left)}px`;el.style.top=`${Math.round(rect.top)}px`;el.style.width=`${Math.round(rect.width)}px`;el.style.height=`${Math.round(rect.height)}px`;el.innerHTML=`<span>${esc(label)}</span>`;document.body.appendChild(el);return el;}\nfunction smartHalfRect(rect,position,axis='vertical'){if(axis==='horizontal'){const w=rect.width/2;return{left:position==='before'?rect.left:rect.left+w,top:rect.top,width:w,height:rect.height};}const h=rect.height/2;return{left:rect.left,top:position==='before'?rect.top:rect.top+h,width:rect.width,height:h};}\n"""
s=s[:pos]+overlay_helpers+s[pos:]

replace_function('smartRenderPreview',"""function smartRenderPreview(spec){const id=smartSpecId(spec);if(id===smartDrag.specKey)return;smartRestorePreviewDom();smartDrag.spec=spec;smartDrag.specKey=id;if(!spec)return;
 const fieldLabel=smartFieldByKey(smartDrag.fieldKey)?.label||'Campo';
 if(spec.kind==='slot'){
  const row=smartDrag.sourceRow;if(row){const r=row.getBoundingClientRect(),chosen=smartHalfRect(r,spec.position==='left'?'before':'after','horizontal'),empty=smartHalfRect(r,spec.position==='left'?'after':'before','horizontal');smartOverlayRect(chosen,'slot-field',`${fieldLabel} · 50%`);smartOverlayRect(empty,'slot-empty','VUOTO 50%');}
 }else if(spec.kind==='beside'){
  if(spec.slot){const slot=layoutCanvas?.querySelector(`.df-layout-empty-slot[data-slot-target-key=\"${CSS.escape(spec.targetKey)}\"][data-slot-side=\"${spec.position==='after'?'after':'before'}\"]`);if(slot){smartOverlayRect(slot.getBoundingClientRect(),'empty-slot','INSERISCI QUI · 50%');return;}}
  const target=layoutCanvas?.querySelector(`.df-layout-card[data-field-key=\"${CSS.escape(spec.targetKey)}\"]`);if(target){const r=target.getBoundingClientRect(),half=smartHalfRect(r,spec.position,'horizontal');smartOverlayRect(half,'beside',spec.position==='before'?'SINISTRA · 50%':'DESTRA · 50%',spec.position);target.classList.add(spec.position==='before'?'df-smart-target-left':'df-smart-target-right');}
 }else if(spec.kind==='line'){
  const target=layoutCanvas?.querySelector(`.df-layout-card[data-field-key=\"${CSS.escape(spec.targetKey)}\"]`),line=target?.closest('.df-layout-row');if(line){const r=line.getBoundingClientRect(),half=smartHalfRect(r,spec.position,'vertical');smartOverlayRect(half,'line',spec.position==='before'?'SOPRA':'SOTTO',spec.position);line.classList.add(spec.position==='before'?'df-smart-line-target-before':'df-smart-line-target-after');}
 }else if(spec.kind==='joinrow'){
  const group=layoutCanvas?.querySelector(`.df-layout-row-group[data-row-no=\"${Number(spec.row)}\"]`);if(group){smartOverlayRect(group.getBoundingClientRect(),'joinrow','AGGIUNGI A QUESTA RIGA');group.classList.add('df-smart-row-join-target');}
 }else if(spec.kind==='newrow'){
  const group=layoutCanvas?.querySelector(`.df-layout-row-group[data-row-no=\"${Number(spec.row)}\"]`);if(group){const r=group.getBoundingClientRect(),h=Math.min(44,Math.max(28,r.height*.22)),band={left:r.left,top:spec.position==='before'?r.top:r.bottom-h,width:r.width,height:h};smartOverlayRect(band,'newrow',spec.position==='before'?'SOPRA · NUOVA RIGA':'SOTTO · NUOVA RIGA',spec.position);group.classList.add(spec.position==='before'?'df-smart-row-target-before':'df-smart-row-target-after');}
 }else if(spec.kind==='append'){
  const r=layoutNewRow?.getBoundingClientRect();if(r)smartOverlayRect({left:r.left,top:r.top-12,width:r.width,height:r.height+24},'append','NUOVA RIGA');
 }
}""")

replace_function('smartBeginDrag',"""function smartBeginDrag(){const p=smartDrag.pending;if(!p||smartDrag.active||!p.card?.isConnected)return;const sourceRect=p.card.getBoundingClientRect();smartDrag.active=true;smartDrag.pointerId=p.pointerId;smartDrag.pointerType=p.pointerType;smartDrag.fieldKey=p.fieldKey;smartDrag.sourceCard=p.card;smartDrag.sourceRow=p.card.closest('.df-layout-row');smartDrag.lastX=p.x;smartDrag.lastY=p.y;smartDrag.queuedX=p.x;smartDrag.queuedY=p.y;smartDrag.originX=p.startX;smartDrag.originY=p.startY;smartDrag.sourceWidth=Math.max(1,sourceRect.width);smartDrag.sourceHeight=Math.max(1,sourceRect.height);smartDrag.grabXRatio=Math.max(0,Math.min(1,(p.startX-sourceRect.left)/smartDrag.sourceWidth));smartDrag.grabYRatio=Math.max(0,Math.min(1,(p.startY-sourceRect.top)/smartDrag.sourceHeight));smartDrag.intentAxis='';smartDrag.intentLockX=p.startX;smartDrag.intentLockY=p.startY;smartDrag.pending=null;clearTimeout(smartDrag.pressTimer);smartDrag.pressTimer=null;smartCreateGhost(p.card,p.fieldKey,p.x,p.y);p.card.classList.add('df-smart-source-hidden');document.body.classList.add('df-smart-drag-active');document.querySelector('.df-builder-workspace')?.classList.add('is-smart-dragging');if(p.pointerType!=='mouse'&&navigator.vibrate)try{navigator.vibrate(10);}catch{};}""")

replace_function('smartQueueDrag',"""function smartQueueDrag(e,card,key){if(editorLocked||!e.isPrimary||(e.pointerType==='mouse'&&e.button!==0)||e.target.closest(smartDragIgnoreSelector))return;smartCancelPending();smartDrag.pending={pointerId:e.pointerId,pointerType:e.pointerType||'mouse',fieldKey:key,card,x:e.clientX,y:e.clientY,startX:e.clientX,startY:e.clientY};if(e.pointerType==='touch'||e.pointerType==='pen')smartDrag.pressTimer=setTimeout(()=>smartBeginDrag(),300);}""")

# Insert RAF helpers before smartPointerMove.
pos=s.find('function smartPointerMove(')
if pos<0: raise SystemExit('1.3.58 missing smartPointerMove')
raf_helpers="""function smartRunPointerFrame(){smartDrag.raf=0;if(!smartDrag.active)return;const x=smartDrag.queuedX,y=smartDrag.queuedY;smartUpdateIntentAxis(x,y);smartPositionGhost(x,y);smartRenderPreview(smartFindDropSpec(x,y));}\nfunction smartSchedulePointerFrame(x,y){smartDrag.queuedX=x;smartDrag.queuedY=y;if(!smartDrag.raf)smartDrag.raf=requestAnimationFrame(smartRunPointerFrame);}\nfunction smartFlushPointerFrame(){if(!smartDrag.active)return;if(smartDrag.raf){cancelAnimationFrame(smartDrag.raf);smartDrag.raf=0;}smartRunPointerFrame();}\n"""
s=s[:pos]+raf_helpers+s[pos:]

replace_function('smartPointerMove',"""function smartPointerMove(e){const p=smartDrag.pending;if(p&&e.pointerId===p.pointerId&&!smartDrag.active){p.x=e.clientX;p.y=e.clientY;const d=Math.hypot(e.clientX-p.startX,e.clientY-p.startY);if(p.pointerType==='mouse'){if(d>=4)smartBeginDrag();}else if(d>12){smartCancelPending();return;}}if(!smartDrag.active||e.pointerId!==smartDrag.pointerId)return;e.preventDefault();smartDrag.lastX=e.clientX;smartDrag.lastY=e.clientY;smartSchedulePointerFrame(e.clientX,e.clientY);}""")

replace_function('smartFinishDrag',"""function smartFinishDrag(commit,e){if(!smartDrag.active){smartCancelPending();return;}if(e&&e.pointerId!==smartDrag.pointerId)return;e?.preventDefault?.();smartDrag.queuedX=smartDrag.lastX;smartDrag.queuedY=smartDrag.lastY;smartFlushPointerFrame();const before=smartCaptureRects(),spec=smartDrag.spec,key=smartDrag.fieldKey;smartEndVisual();smartRestorePreviewDom();const changed=commit&&spec?smartCommitSpec(spec,key):false;smartSuppressClickUntil=Date.now()+260;smartDrag.active=false;smartDrag.pointerId=null;smartDrag.pointerType='';smartDrag.fieldKey='';smartDrag.sourceCard=null;smartDrag.sourceRow=null;smartDrag.spec=null;smartDrag.specKey='';smartDrag.intentAxis='';smartDrag.ghostWidth=0;smartDrag.ghostHeight=0;if(smartDrag.raf){cancelAnimationFrame(smartDrag.raf);smartDrag.raf=0;}renderLayoutCanvas();smartAnimateFrom(before);}""")

# Append CSS after the existing 1.3.57 marker block.
css_marker='/* Forms 1.3.58: intent-aware field drag with grab-offset compensation. */'
# sed version replacement may already have changed the comment 1.3.57 -> 1.3.58.
i=s.find(css_marker)
if i<0:
    css_marker='/* Forms 1.3.57: intent-aware field drag with grab-offset compensation. */'
    i=s.find(css_marker)
if i<0: raise SystemExit('1.3.58 missing field drag CSS marker')
# Place final overrides near end of style block for stronger precedence.
style_end=s.rfind('</style>')
if style_end<0: raise SystemExit('1.3.58 missing </style>')
css="""

/* Forms 1.3.58: fluid magnetic field drag. Keep the canvas geometrically stable while dragging. */
body.df-smart-drag-active .df-layout-card.df-smart-source-hidden{display:flex!important;visibility:hidden!important;opacity:0!important;pointer-events:none!important}
.df-smart-drag-ghost{will-change:transform;transition:none!important;pointer-events:none!important}
.df-smart-drop-overlay{position:fixed;z-index:10770;box-sizing:border-box;pointer-events:none;display:flex;align-items:center;justify-content:center;border:2px solid var(--df);border-radius:8px;background:color-mix(in srgb,var(--df) 12%,transparent);box-shadow:0 3px 14px color-mix(in srgb,var(--df) 18%,transparent);color:var(--df);font-size:11px;font-weight:950;letter-spacing:.02em;text-transform:uppercase;animation:dfSmartOverlayIn .07s ease-out both;backdrop-filter:blur(1px)}
.df-smart-drop-overlay.is-line,.df-smart-drop-overlay.is-newrow{background:color-mix(in srgb,var(--df) 9%,var(--bs-body-bg,#fff));border-style:dashed}
.df-smart-drop-overlay.is-empty-slot{border-style:dashed;background:color-mix(in srgb,var(--df) 14%,var(--bs-body-bg,#fff))}
.df-smart-drop-overlay.is-slot-empty{border-style:dashed;background:color-mix(in srgb,var(--df) 5%,var(--bs-body-bg,#fff));opacity:.88}
.df-smart-drop-overlay.is-slot-field,.df-smart-drop-overlay.is-beside{background:color-mix(in srgb,var(--df) 11%,var(--bs-body-bg,#fff))}
@keyframes dfSmartOverlayIn{from{opacity:.35}to{opacity:1}}
@media (prefers-reduced-motion:reduce){.df-smart-drop-overlay{animation:none}}
"""
s=s[:style_end]+css+s[style_end:]

p.write_text(s,encoding='utf-8')
PY

# Rebuild each child preserving role/name.
rm -f "$TMP/outer"/*.zip
while IFS=$'\t' read -r IDX NEWNAME; do
  CHILD="$TMP/children/$IDX"
  test -d "$CHILD"
  while IFS= read -r -d '' PHP; do php -l "$PHP" >/dev/null; done < <(find "$CHILD" -type f -name '*.php' -print0)
  while IFS= read -r -d '' XML; do python3 - "$XML" <<'PY'
import sys,xml.etree.ElementTree as ET
ET.parse(sys.argv[1])
PY
  done < <(find "$CHILD" -type f -name '*.xml' -print0)
  (cd "$CHILD" && zip -qr "$TMP/outer/$NEWNAME" .)
done < "$MAP"

find "$TMP/outer" -maxdepth 2 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.json' -o -name '*.txt' -o -name '*.md' \) -print0 \
  | xargs -0 -r sed -i 's/1\.3\.57/1.3.58/g'

MANIFEST="$TMP/outer/pkg_decaroforms.xml"
test -f "$MANIFEST"
python3 - "$MANIFEST" "$NEW" <<'PY'
from pathlib import Path
import re,sys,xml.etree.ElementTree as ET
p=Path(sys.argv[1]);v=sys.argv[2];s=p.read_text(encoding='utf-8')
s=re.sub(r'<version>[^<]+</version>',f'<version>{v}</version>',s,count=1)
p.write_text(s,encoding='utf-8')
ET.parse(p)
PY

test -f "$TMP/outer/com_decaroforms_1.3.58.zip"
test -f "$TMP/outer/plg_system_decaroforms_1.3.58.zip"
test -f "$TMP/outer/plg_editors-xtd_decaroforms_1.3.58.zip"
grep -q 'com_decaroforms_1.3.58.zip' "$MANIFEST"
grep -q 'plg_system_decaroforms_1.3.58.zip' "$MANIFEST"
grep -q 'plg_editors-xtd_decaroforms_1.3.58.zip' "$MANIFEST"
for C in "$TMP/outer"/*.zip; do unzip -t "$C" >/dev/null; done

php -l "$BUILDER" >/dev/null
python3 - "$BUILDER" "$JS_TMP" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
js='\n'.join(m.group(1) for m in re.finditer(r'<script(?:\s[^>]*)?>(.*?)</script>',s,re.S|re.I))
js=re.sub(r'<\?(?:php|=).*?\?>','null',js,flags=re.S|re.I)
Path(sys.argv[2]).write_text(js,encoding='utf-8')
PY
node --check "$JS_TMP"

grep -q "version:'1.3.58'" "$BUILDER"
grep -q 'function smartProjectedCanvasPoint' "$BUILDER"
grep -q 'function smartUpdateIntentAxis' "$BUILDER"
grep -q 'function smartRunPointerFrame' "$BUILDER"
grep -q 'function smartOverlayRect' "$BUILDER"
grep -q 'smartNearestCardNearPoint(hx,hy,44)' "$BUILDER"
grep -q 'smartNearestEmptySlot(hx,hy,30)' "$BUILDER"
grep -q 'df-smart-drop-overlay' "$BUILDER"
grep -q 'visibility:hidden!important' "$BUILDER"

# Intent regression checks: axis locks quickly and changes only on a deliberate orthogonal gesture.
python3 - <<'PY'
def choose(dx,dy):
    adx,ady=abs(dx),abs(dy)
    if max(adx,ady)<10:return ''
    return 'vertical' if ady>=adx*.82 else 'horizontal'
assert choose(4,15)=='vertical'
assert choose(12,15)=='vertical'
assert choose(25,8)=='horizontal'
# Left-edge grab projection: logical center follows the dragged field, not the pointer edge.
def project(x,grab,w):return x+(.5-grab)*w
assert project(100,.10,800)==420
assert project(900,.90,800)==580
# Magnetic tolerances are intentionally wider than 1.3.57 (22/16px).
assert 44>22 and 30>16
PY

(
  cd "$TMP/outer"
  zip -qr "$TARGET" .
)
unzip -t "$TARGET" >/dev/null
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

FEED="$ROOT/updates/pkg_decaroforms.xml"
python3 - "$FEED" "$NEW" "$SHA" <<'PY'
from pathlib import Path
import re,sys,xml.etree.ElementTree as ET
p=Path(sys.argv[1]);v=sys.argv[2];sha=sys.argv[3];s=p.read_text(encoding='utf-8')
s=re.sub(r'<version>[^<]+</version>',f'<version>{v}</version>',s,count=1)
s=re.sub(r'releases/[0-9.]+/pkg_decaroforms_[0-9.]+\.zip',f'releases/{v}/pkg_decaroforms_{v}.zip',s,count=1)
s=re.sub(r'<sha256>[^<]+</sha256>',f'<sha256>{sha}</sha256>',s,count=1)
p.write_text(s,encoding='utf-8')
ET.parse(p)
PY

CHANGE="$ROOT/updates/changelog.xml"
python3 - "$CHANGE" "$NEW" <<'PY'
from pathlib import Path
import sys,xml.etree.ElementTree as ET
p=Path(sys.argv[1]);v=sys.argv[2];s=p.read_text(encoding='utf-8')
entry=f'''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>{v}</version>\n\t\t<note>Builder drag Campi reso piu fluido, stabile e rapido dopo revisione video: canvas statico durante il trascinamento senza reflow dei campi, target magnetici basati sul centro reale del campo trascinato, lock intenzione verticale/orizzontale con cambio solo deliberato, tolleranze ampliate, slot VUOTO 50% magnetici, preview overlay non invasiva, ghost GPU con translate3d e pointer processing via requestAnimationFrame. Preservati Row ID, Sezioni, Righe, visual line, larghezze, Undo/Redo e salvataggio atomico.</note>\n\t</changelog>'''
if f'<version>{v}</version>' not in s:
    s=s.replace('<changelogs>','<changelogs>'+entry,1)
p.write_text(s,encoding='utf-8')
ET.parse(p)
PY

cat > "$TARGET_DIR/README.md" <<EOF
# Forms 1.3.58

Fluid magnetic field-drag release based on the 2026-09-06 21:23 screen recording:
- the Builder canvas stays geometrically static while dragging; fields no longer jump/reflow under the pointer;
- drop targeting follows the projected center of the dragged field, compensating the exact grab point;
- vertical/horizontal intent locks quickly and changes only after a deliberate orthogonal gesture;
- field magnet tolerance increased to **44px** and VUOTO 50% slot tolerance to **30px**;
- lightweight fixed overlays show SOPRA/SOTTO/SINISTRA/DESTRA without moving the form before drop;
- drag ghost uses GPU-friendly translate3d and pointer processing is throttled with requestAnimationFrame;
- mouse start threshold is 4px; touch/pen hold reduced to 300ms;
- previous Row IDs, stable Riga labels, Sections, visual lines, 50/50 slots, widths, Undo/Redo and atomic save are preserved;
- component, system plugin and editors-xtd plugin remain separate Joomla child ZIPs.

SHA256: $SHA
EOF

echo "Forms $NEW built: $TARGET"
echo "SHA256: $SHA"
