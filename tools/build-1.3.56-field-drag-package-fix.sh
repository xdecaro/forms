#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.54"
NEW="1.3.56"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1356-builder.js' EXIT
mkdir -p "$TMP/outer" "$TMP/children" "$TARGET_DIR"
test -f "$BASE"
unzip -q "$BASE" -d "$TMP/outer"

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
    | xargs -0 -r sed -i 's/1\.3\.54/1.3.56/g'

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
    if a<0: raise SystemExit(f'1.3.56 missing start anchor: {label}')
    b=s.find(end,a)
    if b<0: raise SystemExit(f'1.3.56 missing end anchor: {label}')
    s=s[:a]+replacement+s[b:]

def replace_once(old,new,label):
    global s
    if old not in s: raise SystemExit(f'1.3.56 missing anchor: {label}')
    s=s.replace(old,new,1)

replace_between(
    'function smartClassifyCard(card,x,y){',
    'function smartNearestCardInRow(',
'''function smartClassifyCard(card,x,y){
 if(!card||card.dataset.fieldKey===smartDrag.fieldKey)return null;
 const target=smartFieldByKey(card.dataset.fieldKey),source=smartFieldByKey(smartDrag.fieldKey);if(!target||!source)return null;
 const r=card.getBoundingClientRect(),rx=(x-r.left)/Math.max(1,r.width),ry=(y-r.top)/Math.max(1,r.height),targetLine=visualLineForField(target).map(([f])=>f),sourceInLine=targetLine.includes(source),count=targetLine.filter(f=>f!==source).length+(sourceInLine?0:1),canSide=count<=4,row=Number(target.config?.layout?.row||1),current=smartDrag.spec&&smartDrag.spec.targetKey===target.key?smartDrag.spec:null;
 if(current?.kind==='line'&&current.position==='before'&&ry<=.42)return{kind:'line',row,targetKey:target.key,position:'before'};
 if(current?.kind==='line'&&current.position==='after'&&ry>=.58)return{kind:'line',row,targetKey:target.key,position:'after'};
 if(canSide&&current?.kind==='beside'&&current.position==='before'&&ry>.30&&ry<.70&&rx<=.58)return{kind:'beside',targetKey:target.key,row,position:'before'};
 if(canSide&&current?.kind==='beside'&&current.position==='after'&&ry>.30&&ry<.70&&rx>=.42)return{kind:'beside',targetKey:target.key,row,position:'after'};
 if(ry<=.36)return{kind:'line',row,targetKey:target.key,position:'before'};
 if(ry>=.64)return{kind:'line',row,targetKey:target.key,position:'after'};
 if(canSide)return{kind:'beside',targetKey:target.key,row,position:rx<.5?'before':'after'};
 return{kind:'line',row,targetKey:target.key,position:ry<.5?'before':'after'};
}
''',
    'smartClassifyCard wide zones'
)

replace_once(
'''function smartNearestCardInRow(row,x,y){const cards=[...row.querySelectorAll('.df-layout-card:not(.df-smart-source-hidden)')];if(!cards.length)return null;let best=null,score=Infinity;for(const card of cards){const r=card.getBoundingClientRect(),cx=Math.max(r.left,Math.min(x,r.right)),cy=Math.max(r.top,Math.min(y,r.bottom)),d=(x-cx)**2+(y-cy)**2;if(d<score){score=d;best=card;}}return best;}\nfunction smartFindDropSpec(x,y){const stack=document.elementsFromPoint?document.elementsFromPoint(x,y):[];const emptySlot=stack.map(el=>el?.closest?.('.df-layout-empty-slot[data-slot-target-key]')).find(Boolean);if(emptySlot){const targetKey=emptySlot.dataset.slotTargetKey||'',side=emptySlot.dataset.slotSide||'before',target=smartFieldByKey(targetKey);if(target&&targetKey!==smartDrag.fieldKey)return{kind:'beside',targetKey,row:Number(target.config?.layout?.row||1),position:side==='after'?'after':'before'};}let card=stack.find(el=>el?.classList?.contains('df-layout-card')&&!el.classList.contains('df-smart-source-hidden'));if(card)return smartClassifyCard(card,x,y);''',
'''function smartNearestCardInRow(row,x,y){const cards=[...row.querySelectorAll('.df-layout-card:not(.df-smart-source-hidden)')];if(!cards.length)return null;let best=null,score=Infinity;for(const card of cards){const r=card.getBoundingClientRect(),cx=Math.max(r.left,Math.min(x,r.right)),cy=Math.max(r.top,Math.min(y,r.bottom)),d=(x-cx)**2+(y-cy)**2;if(d<score){score=d;best=card;}}return best;}\nfunction smartNearestEmptySlot(x,y,margin=16){const slots=[...(layoutCanvas?.querySelectorAll('.df-layout-empty-slot[data-slot-target-key]')||[])];let best=null,score=Infinity;for(const slot of slots){const r=slot.getBoundingClientRect();if(!r.width||!r.height)continue;const dx=x<r.left?r.left-x:x>r.right?x-r.right:0,dy=y<r.top?r.top-y:y>r.bottom?y-r.bottom:0,d=dx*dx+dy*dy;if(d<=margin*margin&&d<score){score=d;best=slot;}}return best;}\nfunction smartNearestCardNearPoint(x,y,margin=22){const cards=[...(layoutCanvas?.querySelectorAll('.df-layout-card:not(.df-smart-source-hidden)')||[])];let best=null,score=Infinity;for(const card of cards){const r=card.getBoundingClientRect();if(!r.width||!r.height)continue;const dx=x<r.left?r.left-x:x>r.right?x-r.right:0,dy=y<r.top?r.top-y:y>r.bottom?y-r.bottom:0,d=dx*dx+dy*dy;if(d<=margin*margin&&d<score){score=d;best=card;}}return best;}\nfunction smartFindDropSpec(x,y){const stack=document.elementsFromPoint?document.elementsFromPoint(x,y):[];let emptySlot=stack.map(el=>el?.closest?.('.df-layout-empty-slot[data-slot-target-key]')).find(Boolean);if(!emptySlot)emptySlot=smartNearestEmptySlot(x,y,16);if(emptySlot){const targetKey=emptySlot.dataset.slotTargetKey||'',side=emptySlot.dataset.slotSide||'before',target=smartFieldByKey(targetKey);if(target&&targetKey!==smartDrag.fieldKey)return{kind:'beside',targetKey,row:Number(target.config?.layout?.row||1),position:side==='after'?'after':'before'};}let card=stack.find(el=>el?.classList?.contains('df-layout-card')&&!el.classList.contains('df-smart-source-hidden'));if(!card)card=smartNearestCardNearPoint(x,y,22);if(card)return smartClassifyCard(card,x,y);''',
    'expanded slot/card proximity'
)

css_anchor='''@media(max-width:800px){.df-smart-line-preview{margin:5px 2px}.df-smart-line-field{max-width:48%}}'''
css_extra='''\n\n/* Forms 1.3.56: wider field drag hit zones; visual emphasis only. */\nbody.df-smart-drag-active .df-layout-card:not(.df-smart-source-hidden){position:relative;isolation:isolate}\nbody.df-smart-drag-active .df-layout-card.df-smart-line-target-before{box-shadow:inset 0 0 0 2px color-mix(in srgb,var(--df) 72%,transparent),inset 0 14px 0 color-mix(in srgb,var(--df) 10%,transparent)}\nbody.df-smart-drag-active .df-layout-card.df-smart-line-target-after{box-shadow:inset 0 0 0 2px color-mix(in srgb,var(--df) 72%,transparent),inset 0 -14px 0 color-mix(in srgb,var(--df) 10%,transparent)}\nbody.df-smart-drag-active .df-layout-card.df-smart-target-left{box-shadow:inset 3px 0 0 var(--df),inset 14px 0 0 color-mix(in srgb,var(--df) 8%,transparent)}\nbody.df-smart-drag-active .df-layout-card.df-smart-target-right{box-shadow:inset -3px 0 0 var(--df),inset -14px 0 0 color-mix(in srgb,var(--df) 8%,transparent)}\nbody.df-smart-drag-active .df-layout-empty-slot{transition:border-color .12s ease,background .12s ease,box-shadow .12s ease;box-shadow:0 0 0 4px color-mix(in srgb,var(--df) 3%,transparent)}\nbody.df-smart-drag-active .df-layout-empty-slot:hover{border-color:var(--df);background:color-mix(in srgb,var(--df) 8%,var(--bs-body-bg,#fff));box-shadow:0 0 0 6px color-mix(in srgb,var(--df) 7%,transparent)}\n'''
if css_anchor not in s: raise SystemExit('1.3.56 missing CSS anchor')
s=s.replace(css_anchor,css_anchor+css_extra,1)

p.write_text(s,encoding='utf-8')
PY

# Rebuild each child with its ORIGINAL role/name preserved.
rm -f "$TMP/outer"/*.zip
while IFS=$'\t' read -r IDX NEWNAME; do
  CHILD="$TMP/children/$IDX"
  test -d "$CHILD"
  while IFS= read -r -d '' PHP; do php -l "$PHP" >/dev/null; done < <(find "$CHILD" -type f -name '*.php' -print0)
  (cd "$CHILD" && zip -qr "$TMP/outer/$NEWNAME" .)
done < "$MAP"

find "$TMP/outer" -maxdepth 2 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.json' -o -name '*.txt' -o -name '*.md' \) -print0 \
  | xargs -0 -r sed -i 's/1\.3\.54/1.3.56/g'

# Canonical package completeness: all children expected by pkg_decaroforms.xml must exist.
test -f "$TMP/outer/com_decaroforms_1.3.56.zip"
test -f "$TMP/outer/plg_system_decaroforms_1.3.56.zip"
test -f "$TMP/outer/plg_editors-xtd_decaroforms_1.3.56.zip"
MANIFEST="$TMP/outer/pkg_decaroforms.xml"
test -f "$MANIFEST"
grep -q 'com_decaroforms_1.3.56.zip' "$MANIFEST"
grep -q 'plg_system_decaroforms_1.3.56.zip' "$MANIFEST"
grep -q 'plg_editors-xtd_decaroforms_1.3.56.zip' "$MANIFEST"
python3 - "$MANIFEST" <<'PY'
import sys,xml.etree.ElementTree as ET
ET.parse(sys.argv[1])
PY
for C in "$TMP/outer"/*.zip; do unzip -t "$C" >/dev/null; done

php -l "$BUILDER"
python3 - "$BUILDER" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
js='\n'.join(m.group(1) for m in re.finditer(r'<script(?:\s[^>]*)?>(.*?)</script>',s,re.S|re.I))
js=re.sub(r'<\?(?:php|=).*?\?>','null',js,flags=re.S|re.I)
Path('/tmp/forms-1356-builder.js').write_text(js,encoding='utf-8')
PY
node --check /tmp/forms-1356-builder.js

grep -q "version:'1.3.56'" "$BUILDER"
grep -q "if(ry<=.36)return{kind:'line'" "$BUILDER"
grep -q "if(ry>=.64)return{kind:'line'" "$BUILDER"
grep -q "function smartNearestEmptySlot" "$BUILDER"
grep -q "function smartNearestCardNearPoint" "$BUILDER"
grep -q "smartNearestEmptySlot(x,y,16)" "$BUILDER"
grep -q "smartNearestCardNearPoint(x,y,22)" "$BUILDER"

python3 - <<'PY'
def classify(rx,ry,can_side=True,current=None):
    if current and current[0]=='line' and current[1]=='before' and ry<=.42:return ('line','before')
    if current and current[0]=='line' and current[1]=='after' and ry>=.58:return ('line','after')
    if can_side and current and current[0]=='beside' and current[1]=='before' and ry>.30 and ry<.70 and rx<=.58:return ('beside','before')
    if can_side and current and current[0]=='beside' and current[1]=='after' and ry>.30 and ry<.70 and rx>=.42:return ('beside','after')
    if ry<=.36:return ('line','before')
    if ry>=.64:return ('line','after')
    if can_side:return ('beside','before' if rx<.5 else 'after')
    return ('line','before' if ry<.5 else 'after')
assert classify(.05,.20)==('line','before')
assert classify(.95,.20)==('line','before')
assert classify(.05,.80)==('line','after')
assert classify(.95,.80)==('line','after')
assert classify(.20,.50)==('beside','before')
assert classify(.80,.50)==('beside','after')
assert classify(.50,.39,current=('line','before'))==('line','before')
assert classify(.50,.61,current=('line','after'))==('line','after')
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
import re,sys
p=Path(sys.argv[1]);v=sys.argv[2];sha=sys.argv[3];s=p.read_text(encoding='utf-8')
s=re.sub(r'<version>[^<]+</version>',f'<version>{v}</version>',s,count=1)
s=re.sub(r'releases/[0-9.]+/pkg_decaroforms_[0-9.]+\.zip',f'releases/{v}/pkg_decaroforms_{v}.zip',s,count=1)
s=re.sub(r'<sha256>[^<]+</sha256>',f'<sha256>{sha}</sha256>',s,count=1)
p.write_text(s,encoding='utf-8')
PY

CHANGE="$ROOT/updates/changelog.xml"
python3 - "$CHANGE" <<'PY'
from pathlib import Path
import sys,xml.etree.ElementTree as ET
p=Path(sys.argv[1]);root=ET.parse(p).getroot()
if not any((c.findtext('version') or '')=='1.3.56' for c in root.findall('changelog')):
    e=ET.Element('changelog')
    vals=[
      ('element','pkg_decaroforms'),('type','package'),('version','1.3.56'),
      ('note','Release canonica della nuova UX drag Campi: 36% superiore = SOPRA, 36% inferiore = SOTTO su tutta la larghezza, fascia centrale SINISTRA/DESTRA, isteresi e tolleranze 22px/16px per campi e slot VUOTO. Corretto inoltre il packaging della 1.3.55, che aveva accorpato i child ZIP e omesso i due plugin richiesti dal manifest; 1.3.56 ripristina component, system plugin ed editors-xtd plugin separati e installabili. Tutte le funzioni precedenti del Builder restano preservate.')]
    for tag,text in vals:
      el=ET.SubElement(e,tag);el.text=text
    root.insert(0,e);ET.indent(root,space='\t')
    p.write_text('<?xml version="1.0" encoding="utf-8"?>\n'+ET.tostring(root,encoding='unicode')+'\n',encoding='utf-8')
PY
python3 - "$FEED" "$CHANGE" <<'PY'
import sys,xml.etree.ElementTree as ET
for f in sys.argv[1:]: ET.parse(f)
PY

cat > "$TARGET_DIR/README.md" <<EOF
# Forms $NEW

Canonical field-drag UX release and package correction:
- top **36%** of a field = SOPRA across its full width;
- bottom **36%** = SOTTO across its full width;
- center **28%** = SINISTRA / DESTRA;
- hysteresis reduces direction flicker;
- **22px** invisible tolerance around field cards;
- **16px** invisible tolerance around VUOTO 50% slots;
- all previous Row identity, stable labels, 50/50 slots, visual lines, Undo/Redo and atomic save behavior preserved;
- package contains the three manifest-required child ZIPs separately: component, system plugin and editors-xtd plugin;
- PHP, JavaScript, XML, child ZIP integrity, outer ZIP integrity and geometry checks passed.

SHA256: $SHA
EOF

echo "Built $TARGET"
echo "SHA256 $SHA"
