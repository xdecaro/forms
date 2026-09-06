#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.51"
NEW="1.3.52"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1352-builder.js' EXIT
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

  # Keep all child package/component/plugin versions coherent.
  find "$CHILD" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.js' -o -name '*.json' -o -name '*.css' -o -name '*.txt' -o -name '*.md' \) -print0 \
    | xargs -0 -r sed -i 's/1\.3\.51/1.3.52/g'

  CANDIDATE="$CHILD/administrator/components/com_decaroforms/tmpl/builder/default.php"
  if [ -f "$CANDIDATE" ]; then
    BUILDER="$CANDIDATE"
  fi

done

test -n "$BUILDER" && test -f "$BUILDER"

python3 - "$BUILDER" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')

def replace_once(old,new,label):
    global s
    if old not in s:
        raise SystemExit(f'1.3.52 missing anchor: {label}')
    s=s.replace(old,new,1)

def replace_between(start,end,replacement,label):
    global s
    a=s.find(start)
    if a<0:
        raise SystemExit(f'1.3.52 missing start: {label}')
    b=s.find(end,a)
    if b<0:
        raise SystemExit(f'1.3.52 missing end: {label}')
    s=s[:a]+replacement+s[b:]

# Make the complete target Row an easy drop area: upper half = before, lower half = after.
# A small centre hysteresis band keeps the current choice stable instead of flickering.
replace_between(
"function structureFindTarget(x,y){",
"function structureBegin(){",
'''function structureRowDropSpec(group,y){
 if(!group)return null;
 const targetRow=Number(group.dataset.rowNo||0),targetRowId=String(group.dataset.rowId||'');
 if(!targetRow||!targetRowId||targetRowId===String(structureDrag.id||''))return null;
 const r=group.getBoundingClientRect(),mid=r.top+r.height/2,band=Math.min(18,Math.max(8,r.height*.12));
 const prev=structureDrag.spec;
 let position;
 if(prev?.kind==='row'&&String(prev.targetRowId||'')===targetRowId&&Math.abs(y-mid)<=band){position=prev.position==='after'?'after':'before';}
 else position=y<mid?'before':'after';
 return{kind:'row',targetRow,targetRowId,position};
}
function structureFindTarget(x,y){const stack=document.elementsFromPoint?document.elementsFromPoint(x,y):[];
 if(structureDrag.type==='section'){
  const head=stack.find(el=>el?.classList?.contains('df-layout-section-head'));if(head){const wrap=head.closest('.df-layout-section-group'),targetId=wrap?.dataset.sectionId;if(targetId&&targetId!==structureDrag.id){const r=head.getBoundingClientRect();return{kind:'sectionMove',targetId,position:y<r.top+r.height/2?'before':'after'};}}
  let best=null,dist=Infinity;for(const group of [...(layoutCanvas?.querySelectorAll('.df-layout-section-group')||[])]){const targetId=group.dataset.sectionId;if(!targetId||targetId===structureDrag.id)continue;const r=group.getBoundingClientRect();let d=Infinity,position='before';if(y<r.top){d=r.top-y;position='before';}else if(y>r.bottom){d=y-r.bottom;position='after';}if(d<dist){dist=d;best={kind:'sectionMove',targetId,position};}}if(best&&dist<=26)return best;return null;
 }
 if(structureDrag.type==='row'){
  const directGroup=stack.map(el=>el?.closest?.('.df-layout-row-group')).find(group=>group&&String(group.dataset.rowId||'')!==String(structureDrag.id||''));
  const directSpec=structureRowDropSpec(directGroup,y);if(directSpec)return directSpec;
  const secHead=stack.find(el=>el?.classList?.contains('df-layout-section-head'));if(secHead){const wrap=secHead.closest('.df-layout-section-group'),sectionId=wrap?.dataset.sectionId;if(sectionId)return{kind:'section',sectionId};}
  let best=null,dist=Infinity;
  for(const group of [...(layoutCanvas?.querySelectorAll('.df-layout-row-group')||[])]){
   const targetRowId=String(group.dataset.rowId||'');if(!targetRowId||targetRowId===String(structureDrag.id||''))continue;
   const r=group.getBoundingClientRect();let d=0;
   if(y<r.top)d=r.top-y;else if(y>r.bottom)d=y-r.bottom;
   if(d<dist){dist=d;best=structureRowDropSpec(group,y);}
  }
  if(best&&dist<=40)return best;
 }
 return null;
}
''',
"structureFindTarget"
)

# Large, visible 50/50 target overlays during Row drag. They are visual only and never intercept the pointer.
css='''\n/* Forms 1.3.52: forgiving 50/50 Row drag target. */\nbody.df-structure-drag-active .df-layout-row-group.is-row-drop-before,body.df-structure-drag-active .df-layout-row-group.is-row-drop-after{isolation:isolate}\nbody.df-structure-drag-active .df-layout-row-group.is-row-drop-before::before,body.df-structure-drag-active .df-layout-row-group.is-row-drop-after::after{left:0!important;right:0!important;height:50%!important;display:flex!important;align-items:center!important;justify-content:center!important;border:2px dashed #7c3aed!important;background:color-mix(in srgb,#7c3aed 8%,transparent)!important;border-radius:8px!important;color:#6d28d9!important;font-size:10px!important;font-weight:950!important;letter-spacing:.055em!important;line-height:1!important;pointer-events:none!important;text-shadow:0 0 5px var(--bs-body-bg,#fff),0 0 5px var(--bs-body-bg,#fff)!important;z-index:40!important}\nbody.df-structure-drag-active .df-layout-row-group.is-row-drop-before::before{top:0!important;bottom:auto!important;border-bottom-left-radius:0!important;border-bottom-right-radius:0!important}\nbody.df-structure-drag-active .df-layout-row-group.is-row-drop-after::after{bottom:0!important;top:auto!important;border-top-left-radius:0!important;border-top-right-radius:0!important}\n[data-bs-theme="dark"] body.df-structure-drag-active .df-layout-row-group.is-row-drop-before::before,[data-bs-theme="dark"] body.df-structure-drag-active .df-layout-row-group.is-row-drop-after::after{color:#c4b5fd!important;background:color-mix(in srgb,#8b5cf6 13%,transparent)!important;text-shadow:0 0 5px var(--bs-body-bg,#111827),0 0 5px var(--bs-body-bg,#111827)!important}\n'''
replace_once('</style>',css+'</style>','Builder style block')

p.write_text(s,encoding='utf-8')
PY

# Rebuild every child ZIP after patching.
idx=0
for ZIP in "$TMP/outer"/*.zip; do
  [ -e "$ZIP" ] || continue
  idx=$((idx+1))
  NAME="$(basename "$ZIP")"
  NEWNAME="${NAME//$OLD/$NEW}"
  CHILD="$TMP/children/$idx"
  while IFS= read -r -d '' PHP; do php -l "$PHP" >/dev/null; done < <(find "$CHILD" -type f -name '*.php' -print0)
  rm -f "$ZIP"
  (cd "$CHILD" && zip -qr "$TMP/outer/$NEWNAME" .)
done

# Outer manifest/text versions.
find "$TMP/outer" -maxdepth 1 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.json' -o -name '*.txt' -o -name '*.md' \) -print0 \
  | xargs -0 -r sed -i 's/1\.3\.51/1.3.52/g'

php -l "$BUILDER"
python3 - "$BUILDER" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
js='\n'.join(m.group(1) for m in re.finditer(r'<script(?:\s[^>]*)?>(.*?)</script>',s,re.S|re.I))
js=re.sub(r'<\?(?:php|=).*?\?>','null',js,flags=re.S|re.I)
Path('/tmp/forms-1352-builder.js').write_text(js,encoding='utf-8')
PY
node --check /tmp/forms-1352-builder.js

grep -q "function structureRowDropSpec" "$BUILDER"
grep -q "directGroup=stack.map" "$BUILDER"
grep -q "dist<=40" "$BUILDER"
grep -q "forgiving 50/50 Row drag target" "$BUILDER"
grep -q "version:'1.3.52'" "$BUILDER"

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
import sys
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8')
if '<version>1.3.52</version>' not in s:
    entry='''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>1.3.52</version>\n\t\t<note>Builder UX: trascinamento Righe reso molto più tollerante. Tutta la metà superiore della Riga bersaglio significa SOPRA e tutta la metà inferiore significa SOTTO; aggiunta isteresi al centro per evitare lampeggi e una zona di aggancio più ampia tra le Righe. Indicatore visivo 50/50 esteso su tutta la destinazione, compatibile light/dark.</note>\n\t</changelog>'''
    pos=s.find('>')+1
    s=s[:pos]+entry+s[pos:]
    p.write_text(s,encoding='utf-8')
PY

cat > "$TARGET_DIR/README.md" <<EOF
# Forms $NEW

Builder Row drag UX release:
- whole target Row is now an active drop surface;
- upper 50% = move before, lower 50% = move after;
- centre hysteresis prevents flickering between before/after;
- gap tolerance increased for easier Row reordering;
- large visual drop overlay shows SOPRA/SOTTO clearly;
- light/dark compatibility preserved;
- stable Row IDs and 1.3.51 Builder core behavior preserved;
- PHP and extracted JavaScript syntax checks passed.

SHA256: $SHA
EOF

echo "Built $TARGET"
echo "SHA256 $SHA"
