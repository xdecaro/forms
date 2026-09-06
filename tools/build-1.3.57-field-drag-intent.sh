#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OLD="1.3.56"
NEW="1.3.57"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
JS_TMP="/tmp/forms-1357-builder.js"
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
    | xargs -0 -r sed -i 's/1\.3\.56/1.3.57/g'

  # All child extension manifests must expose the package release version.
  while IFS= read -r -d '' XML; do
    if grep -q '<extension' "$XML" && grep -q '<version>' "$XML"; then
      python3 - "$XML" "$NEW" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); v=sys.argv[2]; s=p.read_text(encoding='utf-8')
s=re.sub(r'<version>[^<]+</version>', f'<version>{v}</version>', s, count=1)
p.write_text(s, encoding='utf-8')
PY
    fi
  done < <(find "$CHILD" -maxdepth 1 -type f -name '*.xml' -print0)

  CANDIDATE="$CHILD/administrator/components/com_decaroforms/tmpl/builder/default.php"
  if [ -f "$CANDIDATE" ]; then BUILDER="$CANDIDATE"; fi
done

test -n "$BUILDER" && test -f "$BUILDER"

python3 - "$BUILDER" <<'PY'
from pathlib import Path
import sys

p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')

def replace_between(start,end,replacement,label):
    global s
    a=s.find(start)
    if a<0: raise SystemExit(f'1.3.57 missing start anchor: {label}')
    b=s.find(end,a)
    if b<0: raise SystemExit(f'1.3.57 missing end anchor: {label}')
    s=s[:a]+replacement+s[b:]

def replace_once(old,new,label):
    global s
    if old not in s: raise SystemExit(f'1.3.57 missing anchor: {label}')
    s=s.replace(old,new,1)

replace_once(
"const smartDrag={pending:null,active:false,pointerId:null,pointerType:'',fieldKey:'',sourceCard:null,sourceRow:null,ghost:null,spec:null,specKey:'',pressTimer:null,lastX:0,lastY:0};",
"const smartDrag={pending:null,active:false,pointerId:null,pointerType:'',fieldKey:'',sourceCard:null,sourceRow:null,ghost:null,spec:null,specKey:'',pressTimer:null,lastX:0,lastY:0,originX:0,originY:0,grabXRatio:.5,grabYRatio:.5,sourceWidth:0,sourceHeight:0,intentAxis:''};",
'smartDrag intent state'
)

replace_between(
    'function smartClassifyCard(card,x,y){',
    'function smartNearestCardInRow(',
'''function smartProjectedPoint(card,x,y){
 const r=card.getBoundingClientRect(),sw=Math.max(1,Number(smartDrag.sourceWidth)||r.width),sh=Math.max(1,Number(smartDrag.sourceHeight)||r.height),gx=Math.max(0,Math.min(1,Number(smartDrag.grabXRatio)||.5)),gy=Math.max(0,Math.min(1,Number(smartDrag.grabYRatio)||.5));
 return{r,px:x+(.5-gx)*sw,py:y+(.5-gy)*sh};
}
function smartClassifyCard(card,x,y){
 if(!card||card.dataset.fieldKey===smartDrag.fieldKey)return null;
 const target=smartFieldByKey(card.dataset.fieldKey),source=smartFieldByKey(smartDrag.fieldKey);if(!target||!source)return null;
 const projected=smartProjectedPoint(card,x,y),r=projected.r,rx=(projected.px-r.left)/Math.max(1,r.width),ry=(projected.py-r.top)/Math.max(1,r.height),dxn=rx-.5,dyn=ry-.5,adx=Math.abs(dxn),ady=Math.abs(dyn),moveX=x-(Number(smartDrag.originX)||x),moveY=y-(Number(smartDrag.originY)||y),amx=Math.abs(moveX),amy=Math.abs(moveY),targetLine=visualLineForField(target).map(([f])=>f),sourceInLine=targetLine.includes(source),count=targetLine.filter(f=>f!==source).length+(sourceInLine?0:1),canSide=count<=4,row=Number(target.config?.layout?.row||1),current=smartDrag.spec&&smartDrag.spec.targetKey===target.key?smartDrag.spec:null;
 let axis='vertical';
 if(canSide){
  if(current?.kind==='line'&&adx<=ady*1.45+.06)axis='vertical';
  else if(current?.kind==='beside'&&ady<=adx*1.45+.06)axis='horizontal';
  else if(Math.max(adx,ady)<.13){axis=(amx>=24&&amx>amy*1.25)?'horizontal':'vertical';}
  else axis=(ady*1.12>=adx)?'vertical':'horizontal';
 }
 smartDrag.intentAxis=axis;
 if(axis==='horizontal'&&canSide){
  if(current?.kind==='beside'&&current.position==='before'&&rx<=.58)return{kind:'beside',targetKey:target.key,row,position:'before'};
  if(current?.kind==='beside'&&current.position==='after'&&rx>=.42)return{kind:'beside',targetKey:target.key,row,position:'after'};
  const position=Math.abs(dxn)<.055&&amx>=12?(moveX<0?'before':'after'):(rx<.5?'before':'after');
  return{kind:'beside',targetKey:target.key,row,position};
 }
 if(current?.kind==='line'&&current.position==='before'&&ry<=.58)return{kind:'line',row,targetKey:target.key,position:'before'};
 if(current?.kind==='line'&&current.position==='after'&&ry>=.42)return{kind:'line',row,targetKey:target.key,position:'after'};
 const position=Math.abs(dyn)<.055&&amy>=12?(moveY<0?'before':'after'):(ry<.5?'before':'after');
 return{kind:'line',row,targetKey:target.key,position};
}
''',
    'intent-aware smartClassifyCard'
)

replace_between(
    'function smartBeginDrag(){',
    'function smartCancelPending(){',
'''function smartBeginDrag(){const p=smartDrag.pending;if(!p||smartDrag.active||!p.card?.isConnected)return;const sourceRect=p.card.getBoundingClientRect();smartDrag.active=true;smartDrag.pointerId=p.pointerId;smartDrag.pointerType=p.pointerType;smartDrag.fieldKey=p.fieldKey;smartDrag.sourceCard=p.card;smartDrag.sourceRow=p.card.closest('.df-layout-row');smartDrag.lastX=p.x;smartDrag.lastY=p.y;smartDrag.originX=p.startX;smartDrag.originY=p.startY;smartDrag.sourceWidth=Math.max(1,sourceRect.width);smartDrag.sourceHeight=Math.max(1,sourceRect.height);smartDrag.grabXRatio=Math.max(0,Math.min(1,(p.startX-sourceRect.left)/smartDrag.sourceWidth));smartDrag.grabYRatio=Math.max(0,Math.min(1,(p.startY-sourceRect.top)/smartDrag.sourceHeight));smartDrag.intentAxis='';smartDrag.pending=null;clearTimeout(smartDrag.pressTimer);smartDrag.pressTimer=null;const before=smartCaptureRects();smartCreateGhost(p.card,p.fieldKey,p.x,p.y);p.card.classList.add('df-smart-source-hidden');document.body.classList.add('df-smart-drag-active');document.querySelector('.df-builder-workspace')?.classList.add('is-smart-dragging');smartReflowSourceRow();smartAnimateFrom(before);if(p.pointerType!=='mouse'&&navigator.vibrate)try{navigator.vibrate(12);}catch{};}
''',
    'smartBeginDrag grab offset capture'
)

replace_once(
"ph.innerHTML=`<span class=\"df-smart-line-label\">AGGIUNGI A ${esc(title).toUpperCase()} · ${spec.position==='before'?'SOPRA':'SOTTO'}</span><span class=\"df-smart-line-field\">${esc(smartFieldByKey(smartDrag.fieldKey)?.label||'Campo')} · 100%</span>`;",
"ph.innerHTML=`<span class=\"df-smart-line-label\">${spec.position==='before'?'SOPRA':'SOTTO'} · ${esc(title).toUpperCase()}</span><span class=\"df-smart-line-field\">${esc(smartFieldByKey(smartDrag.fieldKey)?.label||'Campo')} · 100%</span>`;",
'direction-first line preview'
)

css_anchor='''/* Forms 1.3.57: wider field drag hit zones; visual emphasis only. */'''
if css_anchor in s:
    s=s.replace(css_anchor,'/* Forms 1.3.57: intent-aware field drag with grab-offset compensation. */',1)
else:
    marker='''@media(max-width:800px){.df-smart-line-preview{margin:5px 2px}.df-smart-line-field{max-width:48%}}'''
    extra='''\n\n/* Forms 1.3.57: intent-aware field drag with grab-offset compensation. */\nbody.df-smart-drag-active .df-smart-line-label{font-weight:950}\n'''
    if marker not in s: raise SystemExit('1.3.57 missing CSS marker')
    s=s.replace(marker,marker+extra,1)

p.write_text(s,encoding='utf-8')
PY

# Rebuild children preserving their roles.
rm -f "$TMP/outer"/*.zip
while IFS=$'\t' read -r IDX NEWNAME; do
  CHILD="$TMP/children/$IDX"
  test -d "$CHILD"
  while IFS= read -r -d '' PHP; do php -l "$PHP" >/dev/null; done < <(find "$CHILD" -type f -name '*.php' -print0)
  (cd "$CHILD" && zip -qr "$TMP/outer/$NEWNAME" .)
done < "$MAP"

# Update outer text + package manifest.
find "$TMP/outer" -maxdepth 2 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.json' -o -name '*.txt' -o -name '*.md' \) -print0 \
  | xargs -0 -r sed -i 's/1\.3\.56/1.3.57/g'

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

test -f "$TMP/outer/com_decaroforms_1.3.57.zip"
test -f "$TMP/outer/plg_system_decaroforms_1.3.57.zip"
test -f "$TMP/outer/plg_editors-xtd_decaroforms_1.3.57.zip"
grep -q 'com_decaroforms_1.3.57.zip' "$MANIFEST"
grep -q 'plg_system_decaroforms_1.3.57.zip' "$MANIFEST"
grep -q 'plg_editors-xtd_decaroforms_1.3.57.zip' "$MANIFEST"
for C in "$TMP/outer"/*.zip; do unzip -t "$C" >/dev/null; done

# Syntax checks for the Builder.
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

grep -q "version:'1.3.57'" "$BUILDER"
grep -q 'function smartProjectedPoint' "$BUILDER"
grep -q 'grabXRatio' "$BUILDER"
grep -q "smartDrag.intentAxis=axis" "$BUILDER"
grep -q "SOPRA':'SOTTO'} · \${esc(title).toUpperCase()}" "$BUILDER"

# Geometry regression tests: grabbing from the left must not mean SINISTRA
# when the user is actually moving vertically.
python3 - <<'PY'
def classify(pointer_x,pointer_y,origin_x,origin_y,grab_x=.10,grab_y=.50,source_w=1000,source_h=60,target=(0,0,1000,60),current=None,can_side=True):
    l,t,w,h=target
    px=pointer_x+(.5-grab_x)*source_w
    py=pointer_y+(.5-grab_y)*source_h
    rx=(px-l)/w; ry=(py-t)/h
    dxn=rx-.5; dyn=ry-.5; adx=abs(dxn); ady=abs(dyn)
    mx=pointer_x-origin_x; my=pointer_y-origin_y; amx=abs(mx); amy=abs(my)
    axis='vertical'
    if can_side:
        if current and current[0]=='line' and adx<=ady*1.45+.06: axis='vertical'
        elif current and current[0]=='beside' and ady<=adx*1.45+.06: axis='horizontal'
        elif max(adx,ady)<.13: axis='horizontal' if (amx>=24 and amx>amy*1.25) else 'vertical'
        else: axis='vertical' if ady*1.12>=adx else 'horizontal'
    if axis=='horizontal' and can_side:
        pos=('before' if mx<0 else 'after') if abs(dxn)<.055 and amx>=12 else ('before' if rx<.5 else 'after')
        return ('beside',pos)
    pos=('before' if my<0 else 'after') if abs(dyn)<.055 and amy>=12 else ('before' if ry<.5 else 'after')
    return ('line',pos)

# Pointer stays near left because that is where the field was grabbed; vertical move still means SOPRA/SOTTO.
assert classify(100,15,100,120)==('line','before')
assert classify(100,45,100,-60)==('line','after')
# Horizontal deliberate movement produces same-line left/right.
assert classify(-180,30,100,30)==('beside','before')
assert classify(380,30,100,30)==('beside','after')
# Same behavior when grabbed near the right edge.
assert classify(900,15,900,120,grab_x=.90)==('line','before')
assert classify(900,45,900,-60,grab_x=.90)==('line','after')
PY

# Build outer package.
(
  cd "$TMP/outer"
  zip -qr "$TARGET" .
)
unzip -t "$TARGET" >/dev/null
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

# Update feed.
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

# Prepend changelog entry.
CHANGE="$ROOT/updates/changelog.xml"
python3 - "$CHANGE" <<'PY'
from pathlib import Path
import sys,xml.etree.ElementTree as ET
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8')
entry='''\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>1.3.57</version>\n\t\t<note>Builder drag Campi migliorato in base al test video: la destinazione non dipende più dal punto del campo da cui è stato afferrato il mouse. Il Builder compensa l'offset di presa e interpreta il movimento reale del campo: movimento verticale = SOPRA/SOTTO, movimento orizzontale = SINISTRA/DESTRA, con isteresi per evitare cambi involontari. L'anteprima mostra subito SOPRA/SOTTO come informazione principale. Restano invariati row_id, Righe/Sezioni, slot VUOTO 50%, visual line, larghezze, Undo/Redo e salvataggio atomico.</note>\n\t</changelog>\n'''
if '<version>1.3.57</version>' not in s:
    s=s.replace('<changelogs>\n','<changelogs>\n'+entry,1)
p.write_text(s,encoding='utf-8')
ET.parse(p)
PY

cat > "$TARGET_DIR/README.md" <<EOF
# Forms 1.3.57

Intent-aware field drag based on the 2026-09-06 Builder video review:
- compensates the exact point where the field was grabbed;
- vertical field movement resolves to SOPRA/SOTTO even when grabbed near the left or right edge;
- deliberate horizontal movement resolves to SINISTRA/DESTRA;
- hysteresis stabilizes the selected direction;
- SOPRA/SOTTO is shown first in the visual preview;
- preserves stable Row IDs, Sections, visual lines, VUOTO 50% slots, automatic/manual widths, Undo/Redo and atomic save;
- package contains component, system plugin and editors-xtd plugin as separate Joomla child ZIPs;
- component/package/plugin manifests aligned to 1.3.57.

SHA256: $SHA
EOF

# Final package/manifest checks.
grep -q '<version>1.3.57</version>' "$FEED"
grep -q "$SHA" "$FEED"
grep -q '<version>1.3.57</version>' "$CHANGE"

# Check each child extension manifest version after rebuilding.
VERIFY="$TMP/verify"
mkdir -p "$VERIFY"
for C in "$TMP/outer"/*.zip; do
  D="$VERIFY/$(basename "$C" .zip)"; mkdir -p "$D"; unzip -q "$C" -d "$D"
  while IFS= read -r -d '' XML; do
    if grep -q '<extension' "$XML" && grep -q '<version>' "$XML"; then grep -q '<version>1.3.57</version>' "$XML"; fi
  done < <(find "$D" -maxdepth 1 -type f -name '*.xml' -print0)
done

echo "Forms 1.3.57 built: $TARGET"
echo "SHA256: $SHA"
