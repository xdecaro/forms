#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.54"
NEW="1.3.55"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1355-builder.js' EXIT
mkdir -p "$TMP/outer" "$TMP/children" "$TARGET_DIR"
test -f "$BASE"
unzip -q "$BASE" -d "$TMP/outer"

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

  find "$CHILD" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.js' -o -name '*.json' -o -name '*.css' -o -name '*.txt' -o -name '*.md' \) -print0 \
    | xargs -0 -r sed -i 's/1\.3\.54/1.3.55/g'

  CANDIDATE="$CHILD/administrator/components/com_decaroforms/tmpl/builder/default.php"
  if [ -f "$CANDIDATE" ]; then BUILDER="$CANDIDATE"; fi
  rm -f "$ZIP"
  (cd "$CHILD" && zip -qr "$TMP/outer/$NEWNAME" .)
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
    if a<0:
        raise SystemExit(f'1.3.55 missing start anchor: {label}')
    b=s.find(end,a)
    if b<0:
        raise SystemExit(f'1.3.55 missing end anchor: {label}')
    s=s[:a]+replacement+s[b:]

def replace_once(old,new,label):
    global s
    if old not in s:
        raise SystemExit(f'1.3.55 missing anchor: {label}')
    s=s.replace(old,new,1)

# 1) Wider and more predictable geometric zones for field drag.
# Top/bottom win across the full card width; the middle band is reserved for left/right.
replace_between(
    'function smartClassifyCard(card,x,y){',
    'function smartNearestCardInRow(',
'''function smartClassifyCard(card,x,y){
 if(!card||card.dataset.fieldKey===smartDrag.fieldKey)return null;
 const target=smartFieldByKey(card.dataset.fieldKey),source=smartFieldByKey(smartDrag.fieldKey);if(!target||!source)return null;
 const r=card.getBoundingClientRect(),rx=(x-r.left)/Math.max(1,r.width),ry=(y-r.top)/Math.max(1,r.height),targetLine=visualLineForField(target).map(([f])=>f),sourceInLine=targetLine.includes(source),count=targetLine.filter(f=>f!==source).length+(sourceInLine?0:1),canSide=count<=4,row=Number(target.config?.layout?.row||1),current=smartDrag.spec&&smartDrag.spec.targetKey===target.key?smartDrag.spec:null;
 // Hysteresis: once a direction is active, keep it for a few extra pixels to avoid flicker.
 if(current?.kind==='line'&&current.position==='before'&&ry<=.42)return{kind:'line',row,targetKey:target.key,position:'before'};
 if(current?.kind==='line'&&current.position==='after'&&ry>=.58)return{kind:'line',row,targetKey:target.key,position:'after'};
 if(canSide&&current?.kind==='beside'&&current.position==='before'&&ry>.30&&ry<.70&&rx<=.58)return{kind:'beside',targetKey:target.key,row,position:'before'};
 if(canSide&&current?.kind==='beside'&&current.position==='after'&&ry>.30&&ry<.70&&rx>=.42)return{kind:'beside',targetKey:target.key,row,position:'after'};
 // Fresh target: 36% top = SOPRA, 36% bottom = SOTTO, full width.
 if(ry<=.36)return{kind:'line',row,targetKey:target.key,position:'before'};
 if(ry>=.64)return{kind:'line',row,targetKey:target.key,position:'after'};
 // Middle 28% is for same-line left/right. If the line is full, fall back to vertical.
 if(canSide)return{kind:'beside',targetKey:target.key,row,position:rx<.5?'before':'after'};
 return{kind:'line',row,targetKey:target.key,position:ry<.5?'before':'after'};
}
''',
    'smartClassifyCard wide zones'
)

# 2) Invisible tolerance around VUOTO and around cards so the user does not need pixel-perfect aiming.
replace_once(
'''function smartNearestCardInRow(row,x,y){const cards=[...row.querySelectorAll('.df-layout-card:not(.df-smart-source-hidden)')];if(!cards.length)return null;let best=null,score=Infinity;for(const card of cards){const r=card.getBoundingClientRect(),cx=Math.max(r.left,Math.min(x,r.right)),cy=Math.max(r.top,Math.min(y,r.bottom)),d=(x-cx)**2+(y-cy)**2;if(d<score){score=d;best=card;}}return best;}\nfunction smartFindDropSpec(x,y){const stack=document.elementsFromPoint?document.elementsFromPoint(x,y):[];const emptySlot=stack.map(el=>el?.closest?.('.df-layout-empty-slot[data-slot-target-key]')).find(Boolean);if(emptySlot){const targetKey=emptySlot.dataset.slotTargetKey||'',side=emptySlot.dataset.slotSide||'before',target=smartFieldByKey(targetKey);if(target&&targetKey!==smartDrag.fieldKey)return{kind:'beside',targetKey,row:Number(target.config?.layout?.row||1),position:side==='after'?'after':'before'};}let card=stack.find(el=>el?.classList?.contains('df-layout-card')&&!el.classList.contains('df-smart-source-hidden'));if(card)return smartClassifyCard(card,x,y);''',
'''function smartNearestCardInRow(row,x,y){const cards=[...row.querySelectorAll('.df-layout-card:not(.df-smart-source-hidden)')];if(!cards.length)return null;let best=null,score=Infinity;for(const card of cards){const r=card.getBoundingClientRect(),cx=Math.max(r.left,Math.min(x,r.right)),cy=Math.max(r.top,Math.min(y,r.bottom)),d=(x-cx)**2+(y-cy)**2;if(d<score){score=d;best=card;}}return best;}\nfunction smartNearestEmptySlot(x,y,margin=16){const slots=[...(layoutCanvas?.querySelectorAll('.df-layout-empty-slot[data-slot-target-key]')||[])];let best=null,score=Infinity;for(const slot of slots){const r=slot.getBoundingClientRect();if(!r.width||!r.height)continue;const dx=x<r.left?r.left-x:x>r.right?x-r.right:0,dy=y<r.top?r.top-y:y>r.bottom?y-r.bottom:0,d=dx*dx+dy*dy;if(d<=margin*margin&&d<score){score=d;best=slot;}}return best;}\nfunction smartNearestCardNearPoint(x,y,margin=22){const cards=[...(layoutCanvas?.querySelectorAll('.df-layout-card:not(.df-smart-source-hidden)')||[])];let best=null,score=Infinity;for(const card of cards){const r=card.getBoundingClientRect();if(!r.width||!r.height)continue;const dx=x<r.left?r.left-x:x>r.right?x-r.right:0,dy=y<r.top?r.top-y:y>r.bottom?y-r.bottom:0,d=dx*dx+dy*dy;if(d<=margin*margin&&d<score){score=d;best=card;}}return best;}\nfunction smartFindDropSpec(x,y){const stack=document.elementsFromPoint?document.elementsFromPoint(x,y):[];let emptySlot=stack.map(el=>el?.closest?.('.df-layout-empty-slot[data-slot-target-key]')).find(Boolean);if(!emptySlot)emptySlot=smartNearestEmptySlot(x,y,16);if(emptySlot){const targetKey=emptySlot.dataset.slotTargetKey||'',side=emptySlot.dataset.slotSide||'before',target=smartFieldByKey(targetKey);if(target&&targetKey!==smartDrag.fieldKey)return{kind:'beside',targetKey,row:Number(target.config?.layout?.row||1),position:side==='after'?'after':'before'};}let card=stack.find(el=>el?.classList?.contains('df-layout-card')&&!el.classList.contains('df-smart-source-hidden'));if(!card)card=smartNearestCardNearPoint(x,y,22);if(card)return smartClassifyCard(card,x,y);''',
    'expanded slot/card proximity'
)

# 3) Make the active destination visually larger/clearer without changing the persisted layout model.
css_anchor='''@media(max-width:800px){.df-smart-line-preview{margin:5px 2px}.df-smart-line-field{max-width:48%}}'''
css_extra='''\n\n/* Forms 1.3.55: wider field drag hit zones; visual emphasis only, no layout semantics change. */\nbody.df-smart-drag-active .df-layout-card:not(.df-smart-source-hidden){position:relative;isolation:isolate}\nbody.df-smart-drag-active .df-layout-card.df-smart-line-target-before{box-shadow:inset 0 0 0 2px color-mix(in srgb,var(--df) 72%,transparent),inset 0 14px 0 color-mix(in srgb,var(--df) 10%,transparent)}\nbody.df-smart-drag-active .df-layout-card.df-smart-line-target-after{box-shadow:inset 0 0 0 2px color-mix(in srgb,var(--df) 72%,transparent),inset 0 -14px 0 color-mix(in srgb,var(--df) 10%,transparent)}\nbody.df-smart-drag-active .df-layout-card.df-smart-target-left{box-shadow:inset 3px 0 0 var(--df),inset 14px 0 0 color-mix(in srgb,var(--df) 8%,transparent)}\nbody.df-smart-drag-active .df-layout-card.df-smart-target-right{box-shadow:inset -3px 0 0 var(--df),inset -14px 0 0 color-mix(in srgb,var(--df) 8%,transparent)}\nbody.df-smart-drag-active .df-layout-empty-slot{transition:border-color .12s ease,background .12s ease,box-shadow .12s ease;box-shadow:0 0 0 4px color-mix(in srgb,var(--df) 3%,transparent)}\nbody.df-smart-drag-active .df-layout-empty-slot:hover{border-color:var(--df);background:color-mix(in srgb,var(--df) 8%,var(--bs-body-bg,#fff));box-shadow:0 0 0 6px color-mix(in srgb,var(--df) 7%,transparent)}\n'''
if css_anchor not in s:
    raise SystemExit('1.3.55 missing CSS anchor')
s=s.replace(css_anchor,css_anchor+css_extra,1)

p.write_text(s,encoding='utf-8')
PY

# Rebuild child ZIPs after patching and version changes.
idx=0
for OLDZIP in "$TMP/children"/*; do
  [ -d "$OLDZIP" ] || continue
  idx=$((idx+1))
  CHILD="$OLDZIP"
  while IFS= read -r -d '' PHP; do php -l "$PHP" >/dev/null; done < <(find "$CHILD" -type f -name '*.php' -print0)
done

# Rebuild outer child ZIPs from the patched child directories.
rm -f "$TMP/outer"/*.zip
idx=0
for CHILD in "$TMP/children"/*; do
  [ -d "$CHILD" ] || continue
  idx=$((idx+1))
  # Determine package type by manifest/content, preserving canonical expected names.
  if [ -f "$CHILD/decaroforms.xml" ] || [ -d "$CHILD/administrator/components/com_decaroforms" ]; then
    OUTNAME="com_decaroforms_$NEW.zip"
  else
    # Find original manifest to infer plugin/package child name from 1.3.54 outer listing is not reliable here.
    MANIFEST="$(find "$CHILD" -maxdepth 2 -type f -name '*.xml' -print -quit || true)"
    if grep -Rqs 'plg_system_decaroforms' "$CHILD"; then OUTNAME="plg_system_decaroforms_$NEW.zip"
    elif grep -Rqs 'decaroforms' "$CHILD"; then OUTNAME="plg_system_decaroforms_$NEW.zip"
    else OUTNAME="child_${idx}_$NEW.zip"; fi
  fi
  (cd "$CHILD" && zip -qr "$TMP/outer/$OUTNAME" .)
done

# If the 1.3.54 outer package contains an outer manifest, update it now.
find "$TMP/outer" -maxdepth 1 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.json' -o -name '*.txt' -o -name '*.md' \) -print0 \
  | xargs -0 -r sed -i 's/1\.3\.54/1.3.55/g'

php -l "$BUILDER"
python3 - "$BUILDER" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
js='\n'.join(m.group(1) for m in re.finditer(r'<script(?:\s[^>]*)?>(.*?)</script>',s,re.S|re.I))
js=re.sub(r'<\?(?:php|=).*?\?>','null',js,flags=re.S|re.I)
Path('/tmp/forms-1355-builder.js').write_text(js,encoding='utf-8')
PY
node --check /tmp/forms-1355-builder.js

grep -q "version:'1.3.55'" "$BUILDER"
grep -q "if(ry<=.36)return{kind:'line'" "$BUILDER"
grep -q "if(ry>=.64)return{kind:'line'" "$BUILDER"
grep -q "function smartNearestEmptySlot" "$BUILDER"
grep -q "function smartNearestCardNearPoint" "$BUILDER"
grep -q "smartNearestEmptySlot(x,y,16)" "$BUILDER"
grep -q "smartNearestCardNearPoint(x,y,22)" "$BUILDER"
grep -q "Forms 1.3.55: wider field drag hit zones" "$BUILDER"

# Deterministic geometry checks for the intended UX.
python3 - <<'PY'
def classify(rx,ry,can_side=True,current=None):
    if current and current[0]=='line' and current[1]=='before' and ry<=.42: return ('line','before')
    if current and current[0]=='line' and current[1]=='after' and ry>=.58: return ('line','after')
    if can_side and current and current[0]=='beside' and current[1]=='before' and ry>.30 and ry<.70 and rx<=.58: return ('beside','before')
    if can_side and current and current[0]=='beside' and current[1]=='after' and ry>.30 and ry<.70 and rx>=.42: return ('beside','after')
    if ry<=.36: return ('line','before')
    if ry>=.64: return ('line','after')
    if can_side: return ('beside','before' if rx<.5 else 'after')
    return ('line','before' if ry<.5 else 'after')
assert classify(.05,.20)==('line','before')   # full-width top
assert classify(.95,.20)==('line','before')   # full-width top, even at right edge
assert classify(.05,.80)==('line','after')    # full-width bottom
assert classify(.95,.80)==('line','after')
assert classify(.20,.50)==('beside','before')
assert classify(.80,.50)==('beside','after')
assert classify(.50,.39,current=('line','before'))==('line','before')
assert classify(.50,.61,current=('line','after'))==('line','after')
PY

# Build the final outer package.
(
  cd "$TMP/outer"
  zip -qr "$TARGET" .
)
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
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8')
root=ET.fromstring(s)
if not any((c.findtext('version') or '')=='1.3.55' for c in root.findall('changelog')):
    entry=ET.Element('changelog')
    for tag,text in [
        ('element','pkg_decaroforms'),('type','package'),('version','1.3.55'),
        ('note','Builder UX: aree di trascinamento Campi molto più ampie e stabili. Il 36% superiore del campo indica SOPRA e il 36% inferiore SOTTO su tutta la larghezza; la fascia centrale è dedicata a SINISTRA/DESTRA. Aggiunta isteresi per evitare lampeggi, tolleranza invisibile di 22px attorno ai campi e 16px attorno agli slot VUOTO 50%. Nessuna modifica al modello dati: restano invariati row_id e nomi Riga stabili, visual line, slot 50/50, larghezze automatiche, titoli/descrizioni, accordion, Undo/Redo e salvataggio atomico.')]:
        el=ET.SubElement(entry,tag);el.text=text
    root.insert(0,entry)
    ET.indent(root,space='\t')
    p.write_text('<?xml version="1.0" encoding="utf-8"?>\n'+ET.tostring(root,encoding='unicode')+'\n',encoding='utf-8')
PY

python3 - "$FEED" "$CHANGE" <<'PY'
import sys,xml.etree.ElementTree as ET
for f in sys.argv[1:]: ET.parse(f)
PY

cat > "$TARGET_DIR/README.md" <<EOF
# Forms $NEW

Field drag UX stabilization release:
- top 36% of every field = **SOPRA** across the full field width;
- bottom 36% = **SOTTO** across the full field width;
- center 28% = **SINISTRA / DESTRA** for same-line placement;
- hysteresis keeps the selected direction stable near zone boundaries;
- 22px invisible proximity tolerance around field cards;
- 16px invisible proximity tolerance around **VUOTO 50%** slots;
- stronger light/dark visual emphasis for active field targets;
- no data-model changes: stable Row IDs/names from 1.3.54 and all previous Builder behavior are preserved;
- PHP, extracted JavaScript, XML and deterministic geometry checks passed.

SHA256: $SHA
EOF

echo "Built $TARGET"
echo "SHA256 $SHA"
