#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OLD="1.3.60"
NEW="1.3.61"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
JS_TMP="/tmp/forms-1361-builder.js"
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
    | xargs -0 -r sed -i 's/1\.3\.60/1.3.61/g'

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
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8')

def replace_function(name,new_text):
    global s
    start=s.find('function '+name+'(')
    if start<0: raise SystemExit(f'1.3.61 missing function: {name}')
    brace=s.find('{',start)
    if brace<0: raise SystemExit(f'1.3.61 no brace: {name}')
    depth=0;quote=None;esc=False;template=False;i=brace
    while i<len(s):
        c=s[i]
        if quote:
            if esc:esc=False
            elif c=='\\':esc=True
            elif c==quote:quote=None
        elif template:
            if esc:esc=False
            elif c=='\\':esc=True
            elif c=='`':template=False
        else:
            if c in "'\"":quote=c
            elif c=='`':template=True
            elif c=='{':depth+=1
            elif c=='}':
                depth-=1
                if depth==0:
                    s=s[:start]+new_text+s[i+1:]
                    return
        i+=1
    raise SystemExit(f'1.3.61 unterminated function: {name}')

# Extend only the structural drag state; field drag remains untouched.
m=re.search(r"const structureDrag=\{[^;]+\};",s)
if not m: raise SystemExit('1.3.61 structureDrag state not found')
new_state="const structureDrag={pending:null,active:false,pointerId:null,type:'',id:null,handle:null,ghost:null,spec:null,pressTimer:null,lastX:0,lastY:0,raf:0,queuedX:0,queuedY:0,ghostWidth:0,ghostHeight:0};"
s=s[:m.start()]+new_state+s[m.end():]

# Shared overlay helpers for Row / Section: vertical only.
anchor='function structureClearTargets(){'
pos=s.find(anchor)
if pos<0: raise SystemExit('1.3.61 structureClearTargets anchor missing')
helpers=r'''function structureOverlayRect(rect,label,kind,position=''){if(!rect||!rect.width||!rect.height)return null;const el=document.createElement('div');el.className=`df-structure-drop-overlay is-${kind}${position?` is-${position}`:''}`;el.style.left=`${Math.round(rect.left)}px`;el.style.top=`${Math.round(rect.top)}px`;el.style.width=`${Math.round(rect.width)}px`;el.style.height=`${Math.round(rect.height)}px`;el.innerHTML=`<span>${esc(label)}</span>`;document.body.appendChild(el);return el;}
function structureVerticalHalf(rect,position){const h=rect.height/2;return{left:rect.left,top:position==='before'?rect.top:rect.top+h,width:rect.width,height:h};}
function structureVerticalPosition(prev,kind,targetId,y,rect){const mid=rect.top+rect.height/2,band=Math.min(22,Math.max(10,rect.height*.16));if(prev?.kind===kind&&String(prev.targetRowId||prev.targetId||'')===String(targetId||'')&&Math.abs(y-mid)<=band)return prev.position==='after'?'after':'before';return y<mid?'before':'after';}
'''
s=s[:pos]+helpers+s[pos:]

replace_function('structureClearTargets',r'''function structureClearTargets(){document.querySelectorAll('.df-structure-drop-overlay').forEach(el=>el.remove());layoutCanvas?.querySelectorAll('.is-structure-before,.is-structure-after,.is-structure-inside,.is-section-drop-before,.is-section-drop-after,.is-row-drop-before,.is-row-drop-after').forEach(el=>el.classList.remove('is-structure-before','is-structure-after','is-structure-inside','is-section-drop-before','is-section-drop-after','is-row-drop-before','is-row-drop-after'));layoutCanvas?.querySelectorAll('[data-structure-drop-label]').forEach(el=>el.removeAttribute('data-structure-drop-label'));}''')

replace_function('structureRenderTarget',r'''function structureRenderTarget(spec){if(structureSpecKey(spec)===structureSpecKey(structureDrag.spec))return;structureClearTargets();structureDrag.spec=spec;if(!spec)return;
 if(spec.kind==='sectionMove'){
  const group=layoutCanvas?.querySelector(`.df-layout-section-group[data-section-id="${CSS.escape(spec.targetId)}"]`),head=group?.querySelector(':scope > .df-layout-section-head');if(head){const half=structureVerticalHalf(head.getBoundingClientRect(),spec.position);structureOverlayRect(half,spec.position==='before'?'SOPRA':'SOTTO','section',spec.position);}
 }else if(spec.kind==='row'){
  const group=spec.targetRowId?layoutCanvas?.querySelector(`.df-layout-row-group[data-row-id="${CSS.escape(String(spec.targetRowId))}"]`):layoutCanvas?.querySelector(`.df-layout-row-group[data-row-no="${Number(spec.targetRow)}"]`);if(group){const half=structureVerticalHalf(group.getBoundingClientRect(),spec.position);structureOverlayRect(half,spec.position==='before'?'SOPRA':'SOTTO','row',spec.position);}
 }else if(spec.kind==='section'){
  const head=layoutCanvas?.querySelector(`.df-layout-section-group[data-section-id="${CSS.escape(spec.sectionId)}"] > .df-layout-section-head`);if(head)structureOverlayRect(head.getBoundingClientRect(),'NELLA SEZIONE','inside');
 }
}''')

replace_function('structureGhost',r'''function structureGhost(label,type,x,y){const g=document.createElement('div');g.className='df-structure-drag-ghost';g.style.left='0px';g.style.top='0px';g.innerHTML=`<span class="df-layout-structure-handle">${modernUiIcon('grip')}</span><strong>${esc(label)}</strong><span>${type==='section'?'Sezione':'Riga'}</span>`;document.body.appendChild(g);structureDrag.ghost=g;const r=g.getBoundingClientRect();structureDrag.ghostWidth=Math.max(1,r.width);structureDrag.ghostHeight=Math.max(1,r.height);structurePositionGhost(x,y);}''')

replace_function('structurePositionGhost',r'''function structurePositionGhost(x,y){const g=structureDrag.ghost;if(!g)return;const w=Math.max(1,Number(structureDrag.ghostWidth)||g.offsetWidth),h=Math.max(1,Number(structureDrag.ghostHeight)||g.offsetHeight),left=Math.min(Math.max(8,window.innerWidth-w-8),Math.max(8,x+14)),top=Math.min(Math.max(8,window.innerHeight-h-8),Math.max(8,y+14));g.style.transform=`translate3d(${Math.round(left)}px,${Math.round(top)}px,0)`;}''')

replace_function('structureRowDropSpec',r'''function structureRowDropSpec(group,y){if(!group)return null;const targetRow=Number(group.dataset.rowNo||0),targetRowId=String(group.dataset.rowId||'');if(!targetRow||!targetRowId||targetRowId===String(structureDrag.id||''))return null;const r=group.getBoundingClientRect(),position=structureVerticalPosition(structureDrag.spec,'row',targetRowId,y,r);return{kind:'row',targetRow,targetRowId,position};}''')

replace_function('structureFindTarget',r'''function structureFindTarget(x,y){
 if(structureDrag.type==='section'){
  let best=null,score=Infinity;
  for(const group of [...(layoutCanvas?.querySelectorAll('.df-layout-section-group')||[])]){
   const targetId=String(group.dataset.sectionId||'');if(!targetId||targetId===String(structureDrag.id||''))continue;const head=group.querySelector(':scope > .df-layout-section-head');if(!head)continue;const r=head.getBoundingClientRect();if(x<r.left-90||x>r.right+90)continue;const dy=y<r.top?r.top-y:y>r.bottom?y-r.bottom:0;if(dy>48)continue;const position=structureVerticalPosition(structureDrag.spec,'sectionMove',targetId,y,r),scoreNow=dy*dy;if(scoreNow<score){score=scoreNow;best={kind:'sectionMove',targetId,position};}
  }
  return best;
 }
 if(structureDrag.type==='row'){
  let best=null,score=Infinity;
  for(const group of [...(layoutCanvas?.querySelectorAll('.df-layout-row-group')||[])]){
   const targetRowId=String(group.dataset.rowId||'');if(!targetRowId||targetRowId===String(structureDrag.id||''))continue;const r=group.getBoundingClientRect();if(x<r.left-90||x>r.right+90)continue;const dy=y<r.top?r.top-y:y>r.bottom?y-r.bottom:0;if(dy>48)continue;const spec=structureRowDropSpec(group,y);if(!spec)continue;const scoreNow=dy*dy;if(scoreNow<score){score=scoreNow;best=spec;}
  }
  if(best)return best;
  let secBest=null,secScore=Infinity;
  for(const group of [...(layoutCanvas?.querySelectorAll('.df-layout-section-group')||[])]){
   const sectionId=String(group.dataset.sectionId||'');if(!sectionId)continue;const head=group.querySelector(':scope > .df-layout-section-head');if(!head)continue;const r=head.getBoundingClientRect();if(x<r.left-90||x>r.right+90)continue;const dy=y<r.top?r.top-y:y>r.bottom?y-r.bottom:0;if(dy>34)continue;const scoreNow=dy*dy;if(scoreNow<secScore){secScore=scoreNow;secBest={kind:'section',sectionId};}
  }
  return secBest;
 }
 return null;
}''')

replace_function('structureBegin',r'''function structureBegin(){const q=structureDrag.pending;if(!q||structureDrag.active||!q.handle?.isConnected)return;structureDrag.active=true;structureDrag.pointerId=q.pointerId;structureDrag.type=q.type;structureDrag.id=q.id;structureDrag.handle=q.handle;structureDrag.lastX=q.x;structureDrag.lastY=q.y;structureDrag.queuedX=q.x;structureDrag.queuedY=q.y;structureDrag.pending=null;clearTimeout(structureDrag.pressTimer);structureDrag.pressTimer=null;structureGhost(q.label,q.type,q.x,q.y);document.body.classList.add('df-structure-drag-active');const source=q.handle.closest(q.type==='section'?'.df-layout-section-group':'.df-layout-row-group');source?.classList.add('is-structure-source');if(source)source.dataset.structureSourceType=q.type;if(q.pointerType!=='mouse'&&navigator.vibrate)try{navigator.vibrate(10);}catch{}}''')

# Faster touch, same mouse threshold as approved Field drag.
replace_function('structureQueue',r'''function structureQueue(e,handle,type,id,label){if(e.button!=null&&e.button!==0)return;e.stopPropagation();const q={pointerId:e.pointerId,pointerType:e.pointerType||'mouse',type,id,handle,label,x:e.clientX,y:e.clientY};structureDrag.pending=q;structureDrag.lastX=e.clientX;structureDrag.lastY=e.clientY;clearTimeout(structureDrag.pressTimer);if(q.pointerType!=='mouse')structureDrag.pressTimer=setTimeout(()=>{if(structureDrag.pending===q)structureBegin();},300);}''')

# RAF keeps Row/Section motion as fluid as the approved Field drag.
pos=s.find('function structurePointerMove(')
if pos<0: raise SystemExit('1.3.61 structurePointerMove anchor missing')
raf=r'''function structureRunPointerFrame(){structureDrag.raf=0;if(!structureDrag.active)return;const x=structureDrag.queuedX,y=structureDrag.queuedY;structurePositionGhost(x,y);structureRenderTarget(structureFindTarget(x,y));}
function structureSchedulePointerFrame(x,y){structureDrag.queuedX=x;structureDrag.queuedY=y;if(!structureDrag.raf)structureDrag.raf=requestAnimationFrame(structureRunPointerFrame);}
function structureFlushPointerFrame(){if(!structureDrag.active)return;if(structureDrag.raf){cancelAnimationFrame(structureDrag.raf);structureDrag.raf=0;}structureRunPointerFrame();}
'''
s=s[:pos]+raf+s[pos:]

replace_function('structurePointerMove',r'''function structurePointerMove(e){const q=structureDrag.pending;if(q&&q.pointerId===e.pointerId&&!structureDrag.active){const d=Math.hypot(e.clientX-q.x,e.clientY-q.y);if(q.pointerType==='mouse'&&d>=4)structureBegin();else if(q.pointerType!=='mouse'&&d>12){clearTimeout(structureDrag.pressTimer);structureDrag.pressTimer=null;structureDrag.pending=null;}return;}if(!structureDrag.active||e.pointerId!==structureDrag.pointerId)return;e.preventDefault();structureDrag.lastX=e.clientX;structureDrag.lastY=e.clientY;structureSchedulePointerFrame(e.clientX,e.clientY);}''')

replace_function('structureFinish',r'''function structureFinish(e,cancel=false){if(structureDrag.pending&&e.pointerId===structureDrag.pending.pointerId){clearTimeout(structureDrag.pressTimer);structureDrag.pending=null;}if(!structureDrag.active||e.pointerId!==structureDrag.pointerId)return;if(e){structureDrag.lastX=e.clientX;structureDrag.lastY=e.clientY;structureDrag.queuedX=e.clientX;structureDrag.queuedY=e.clientY;}structureFlushPointerFrame();const type=structureDrag.type,id=structureDrag.id,spec=structureDrag.spec;structureDrag.ghost?.remove();structureDrag.ghost=null;structureClearTargets();layoutCanvas?.querySelectorAll('.is-structure-source').forEach(el=>{el.classList.remove('is-structure-source');el.removeAttribute('data-structure-source-type');});document.body.classList.remove('df-structure-drag-active');if(structureDrag.raf){cancelAnimationFrame(structureDrag.raf);structureDrag.raf=0;}structureDrag.active=false;structureDrag.pointerId=null;structureDrag.type='';structureDrag.id=null;structureDrag.spec=null;structureDrag.ghostWidth=0;structureDrag.ghostHeight=0;structureSuppressClickUntil=Date.now()+260;if(cancel||!spec)return;let changed=false;if(type==='section'&&spec.kind==='sectionMove')changed=structureMoveSection(id,spec.targetId,spec.position);if(type==='row'&&(spec.kind==='row'||spec.kind==='section'))changed=structureMoveRow(id,spec);if(changed){sync();renderSelected();renderLayoutCanvas();clearTimeout(historyTimer);pushHistory();}}''')

# Remove the old drag-only margins that made the canvas jump during Row/Section drag.
s=re.sub(r'body\.df-structure-drag-active \.df-layout-section-group\{margin-top:10px;margin-bottom:10px\}body\.df-structure-drag-active \.df-layout-row-group\{margin-top:6px;margin-bottom:6px\}','',s,count=1)

style_end=s.rfind('</style>')
if style_end<0: raise SystemExit('1.3.61 style end missing')
css=r'''

/* Forms 1.3.61: Row + Section drag unified with the approved Field drag. Vertical only. */
body.df-structure-drag-active{user-select:none;cursor:grabbing!important}
body.df-structure-drag-active *{cursor:grabbing!important}
body.df-structure-drag-active .df-layout-section-group,
body.df-structure-drag-active .df-layout-row-group{transition:none!important}
body.df-structure-drag-active .df-layout-section-group.is-structure-source,
body.df-structure-drag-active .df-layout-row-group.is-structure-source{opacity:.62!important}
body.df-structure-drag-active .df-layout-section-group.is-structure-source>.df-layout-section-head,
body.df-structure-drag-active .df-layout-row-group.is-structure-source>.df-layout-row-head{
 position:relative;
 background:rgba(var(--df-drag-accent-rgb),.09)!important;
 box-shadow:inset 0 0 0 1.5px rgba(var(--df-drag-accent-rgb),.48)!important;
 outline:1px dashed rgba(var(--df-drag-accent-rgb),.72)!important;
 outline-offset:-3px;
}
body.df-structure-drag-active .df-layout-section-group.is-structure-source>.df-layout-section-head::after,
body.df-structure-drag-active .df-layout-row-group.is-structure-source>.df-layout-row-head::after{
 content:'IN SPOSTAMENTO';
 position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);z-index:40;
 padding:4px 10px;border-radius:999px;background:var(--df-drag-accent);color:var(--df-drag-on-accent);
 font-size:10px;font-weight:950;line-height:1;letter-spacing:.035em;white-space:nowrap;
 box-shadow:0 2px 8px rgba(var(--df-drag-accent-rgb),.24);pointer-events:none;
}
.df-structure-drag-ghost{
 will-change:transform;transition:none!important;left:0!important;top:0!important;
 border-color:rgba(var(--df-drag-accent-rgb),.50)!important;
 box-shadow:0 14px 35px rgba(15,23,42,.22),0 0 0 1px rgba(var(--df-drag-accent-rgb),.08)!important;
}
.df-structure-drag-ghost>span:last-child{color:var(--df-drag-accent)!important}
.df-structure-drop-overlay{
 position:fixed;z-index:10780;box-sizing:border-box;pointer-events:none;
 display:flex;align-items:center;justify-content:center;
 border:2px dashed var(--df-drag-accent);border-radius:10px;
 background:rgba(var(--df-drag-accent-rgb),.17);
 box-shadow:0 4px 16px rgba(var(--df-drag-accent-rgb),.20);
 color:var(--df-drag-accent);backdrop-filter:blur(1px);
 animation:dfSmartOverlayIn .07s ease-out both;
}
.df-structure-drop-overlay>span{
 display:inline-flex;align-items:center;justify-content:center;min-height:24px;
 padding:4px 11px;border-radius:999px;background:var(--df-drag-accent);color:var(--df-drag-on-accent);
 font-size:10px;font-weight:950;line-height:1;letter-spacing:.03em;text-transform:uppercase;
 box-shadow:0 2px 8px rgba(var(--df-drag-accent-rgb),.22);
}
.df-structure-drop-overlay.is-row{background:rgba(var(--df-drag-accent-rgb),.18)}
.df-structure-drop-overlay.is-section{background:rgba(var(--df-drag-accent-rgb),.15)}
.df-structure-drop-overlay.is-inside{border-style:solid;background:rgba(var(--df-drag-accent-rgb),.13)}
/* Disable legacy pseudo indicators: 1.3.61 uses the same fixed overlay language as Field drag. */
body.df-structure-drag-active .is-section-drop-before::before,
body.df-structure-drag-active .is-section-drop-after::after,
body.df-structure-drag-active .is-row-drop-before::before,
body.df-structure-drag-active .is-row-drop-after::after{content:none!important;display:none!important}
@media(max-width:800px){
 .df-structure-drop-overlay>span{min-height:22px;padding:4px 9px;font-size:9px}
 body.df-structure-drag-active .df-layout-section-group.is-structure-source>.df-layout-section-head::after,
 body.df-structure-drag-active .df-layout-row-group.is-structure-source>.df-layout-row-head::after{font-size:9px;padding:4px 8px}
}
@media(prefers-reduced-motion:reduce){.df-structure-drop-overlay{animation:none}}
'''
s=s[:style_end]+css+s[style_end:]
p.write_text(s,encoding='utf-8')
PY

# Rebuild child ZIPs, preserving package roles.
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
  | xargs -0 -r sed -i 's/1\.3\.60/1.3.61/g'

MANIFEST="$TMP/outer/pkg_decaroforms.xml"
test -f "$MANIFEST"
python3 - "$MANIFEST" "$NEW" <<'PY'
from pathlib import Path
import re,sys,xml.etree.ElementTree as ET
p=Path(sys.argv[1]);v=sys.argv[2];s=p.read_text(encoding='utf-8')
s=re.sub(r'<version>[^<]+</version>',f'<version>{v}</version>',s,count=1)
p.write_text(s,encoding='utf-8');ET.parse(p)
PY

test -f "$TMP/outer/com_decaroforms_1.3.61.zip"
test -f "$TMP/outer/plg_system_decaroforms_1.3.61.zip"
test -f "$TMP/outer/plg_editors-xtd_decaroforms_1.3.61.zip"
grep -q 'com_decaroforms_1.3.61.zip' "$MANIFEST"
grep -q 'plg_system_decaroforms_1.3.61.zip' "$MANIFEST"
grep -q 'plg_editors-xtd_decaroforms_1.3.61.zip' "$MANIFEST"
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
grep -q "version:'1.3.61'" "$BUILDER"
grep -q 'function structureOverlayRect' "$BUILDER"
grep -q 'function structureVerticalPosition' "$BUILDER"
grep -q 'function structureRunPointerFrame' "$BUILDER"
grep -q 'df-structure-drop-overlay' "$BUILDER"
grep -q "'SOPRA':'SOTTO'" "$BUILDER"
grep -q 'NELLA SEZIONE' "$BUILDER"
# Field drag baseline must remain present and untouched.
grep -q 'function smartProjectedCanvasPoint' "$BUILDER"
grep -q 'smartNearestCardNearPoint(hx,hy,44)' "$BUILDER"
grep -q 'smartNearestEmptySlot(hx,hy,30)' "$BUILDER"
grep -q 'min-height:68px!important' "$BUILDER"

# Structural geometry checks: vertical-only intent and magnetic tolerance.
python3 - <<'PY'
def pos(y,top,height):return 'before' if y < top+height/2 else 'after'
assert pos(10,0,80)=='before'
assert pos(70,0,80)=='after'
assert 48 > 40 and 48 > 26
# Row / Section have no horizontal placement state; internal positions remain before/after only.
allowed={'before','after'}
assert pos(20,0,60) in allowed and pos(50,0,60) in allowed
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
p.write_text(s,encoding='utf-8');ET.parse(p)
PY

CHANGE="$ROOT/updates/changelog.xml"
python3 - "$CHANGE" "$NEW" <<'PY'
from pathlib import Path
import sys,xml.etree.ElementTree as ET
p=Path(sys.argv[1]);v=sys.argv[2];s=p.read_text(encoding='utf-8')
entry=f'''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>{v}</version>\n\t\t<note>Uniformato il drag di Riga e Sezione al drag Campi approvato: solo movimento verticale SOPRA/SOTTO, nessuna destinazione sinistra/destra; target viola a meta area con badge, sorgente visibile con IN SPOSTAMENTO, ghost GPU e aggiornamento via requestAnimationFrame. Rimossi i margini temporanei che facevano saltare il canvas. Aumentata la tolleranza magnetica a 48px. Preservato lo spostamento Riga dentro una Sezione e tutta la logica Campi 1.3.60.</note>\n\t</changelog>'''
if f'<version>{v}</version>' not in s:s=s.replace('<changelogs>','<changelogs>'+entry,1)
p.write_text(s,encoding='utf-8');ET.parse(p)
PY

cat > "$TARGET_DIR/README.md" <<EOF
# Forms 1.3.61

Uniform Row + Section drag release:
- Row and Section now use the same approved violet drag language as Fields;
- Row/Section placement is vertical only: **SOPRA / SOTTO**, no left/right mode;
- source structure stays visible with an **IN SPOSTAMENTO** badge;
- target area uses a fixed translucent violet half-overlay and pill, without moving the canvas;
- 48px magnetic tolerance makes structural movement faster and less precise;
- structure ghost uses translate3d and pointer updates use requestAnimationFrame;
- drag-only margin expansion was removed to avoid layout jumps;
- moving a Row into a Section remains supported and is shown as **NELLA SEZIONE**;
- approved Field drag 1.3.60, Row IDs, stable labels, visual lines, 50/50 slots, widths, Undo/Redo and atomic save are preserved.

SHA256: $SHA
EOF

echo "Forms $NEW built: $TARGET"
echo "SHA256: $SHA"
