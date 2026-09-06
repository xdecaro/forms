#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OLD="1.3.61"
NEW="1.3.62"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
JS_TMP="/tmp/forms-1362-builder.js"
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
    | xargs -0 -r sed -i 's/1\.3\.61/1.3.62/g'

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
import sys
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8')

def extract_function(text,name):
    start=text.find('function '+name+'(')
    if start<0: raise SystemExit(f'1.3.62 missing function: {name}')
    brace=text.find('{',start)
    depth=0;quote=None;esc=False;template=False;i=brace
    while i<len(text):
        c=text[i]
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
                if depth==0:return text[start:i+1],start,i+1
        i+=1
    raise SystemExit(f'1.3.62 unterminated function: {name}')

def replace_function(name,new_text):
    global s
    _,start,end=extract_function(s,name)
    s=s[:start]+new_text+s[end:]

# Freeze the approved 1.3.60/1.3.61 Field drag engine: this release must not change it.
field_names=['smartQueueDrag','smartBeginDrag','smartPointerMove','smartFinishDrag','smartFindDropSpec','smartRenderPreview']
field_before={name:extract_function(s,name)[0] for name in field_names}

replace_function('structureQueue',r'''function structureQueue(e,handle,type,id,label){if(editorLocked)return;if(e.button!=null&&e.button!==0)return;e.stopPropagation();const q={pointerId:e.pointerId,pointerType:e.pointerType||'mouse',type,id,handle,label,x:e.clientX,y:e.clientY};structureDrag.pending=q;structureDrag.lastX=e.clientX;structureDrag.lastY=e.clientY;clearTimeout(structureDrag.pressTimer);if(q.pointerType!=='mouse')structureDrag.pressTimer=setTimeout(()=>{if(structureDrag.pending===q&&!editorLocked)structureBegin();},300);}''')

replace_function('structureBegin',r'''function structureBegin(){const q=structureDrag.pending;if(editorLocked){clearTimeout(structureDrag.pressTimer);structureDrag.pressTimer=null;structureDrag.pending=null;return;}if(!q||structureDrag.active||!q.handle?.isConnected)return;structureDrag.active=true;structureDrag.pointerId=q.pointerId;structureDrag.type=q.type;structureDrag.id=q.id;structureDrag.handle=q.handle;structureDrag.lastX=q.x;structureDrag.lastY=q.y;structureDrag.queuedX=q.x;structureDrag.queuedY=q.y;structureDrag.pending=null;clearTimeout(structureDrag.pressTimer);structureDrag.pressTimer=null;structureGhost(q.label,q.type,q.x,q.y);document.body.classList.add('df-structure-drag-active');const source=q.handle.closest(q.type==='section'?'.df-layout-section-group':'.df-layout-row-group');source?.classList.add('is-structure-source');if(source)source.dataset.structureSourceType=q.type;if(q.pointerType!=='mouse'&&navigator.vibrate)try{navigator.vibrate(10);}catch{}}''')

replace_function('structureFinish',r'''function structureFinish(e,cancel=false){if(structureDrag.pending&&e.pointerId===structureDrag.pending.pointerId){clearTimeout(structureDrag.pressTimer);structureDrag.pending=null;}if(!structureDrag.active||e.pointerId!==structureDrag.pointerId)return;if(e){structureDrag.lastX=e.clientX;structureDrag.lastY=e.clientY;structureDrag.queuedX=e.clientX;structureDrag.queuedY=e.clientY;}structureFlushPointerFrame();const type=structureDrag.type,id=structureDrag.id,spec=structureDrag.spec;structureDrag.ghost?.remove();structureDrag.ghost=null;structureClearTargets();layoutCanvas?.querySelectorAll('.is-structure-source').forEach(el=>{el.classList.remove('is-structure-source');el.removeAttribute('data-structure-source-type');});document.body.classList.remove('df-structure-drag-active');if(structureDrag.raf){cancelAnimationFrame(structureDrag.raf);structureDrag.raf=0;}structureDrag.active=false;structureDrag.pointerId=null;structureDrag.type='';structureDrag.id=null;structureDrag.spec=null;structureDrag.ghostWidth=0;structureDrag.ghostHeight=0;structureSuppressClickUntil=Date.now()+260;if(cancel||editorLocked||!spec)return;let changed=false;if(type==='section'&&spec.kind==='sectionMove')changed=structureMoveSection(id,spec.targetId,spec.position);if(type==='row'&&(spec.kind==='row'||spec.kind==='section'))changed=structureMoveRow(id,spec);if(changed){sync();renderSelected();renderLayoutCanvas();clearTimeout(historyTimer);pushHistory();}}''')

# Make lock state visually consistent for all three drag handles.
style_end=s.rfind('</style>')
if style_end<0: raise SystemExit('1.3.62 missing </style>')
css=r'''

/* Forms 1.3.62: Bloccato/Modifica now governs Campo, Riga and Sezione uniformly. */
.df-builder.is-locked .df-layout-handle,
.df-builder.is-locked .df-layout-structure-handle{
 cursor:not-allowed!important;
 opacity:.42;
}
.df-builder.is-locked .df-layout-handle:hover,
.df-builder.is-locked .df-layout-structure-handle:hover{
 color:inherit!important;
 background:transparent!important;
}
'''
s=s[:style_end]+css+s[style_end:]

# Approved Field drag engine must be byte-for-byte unchanged after the structural fix.
for name,before in field_before.items():
    after=extract_function(s,name)[0]
    if before!=after:
        raise SystemExit(f'1.3.62 regression: Field drag function changed: {name}')

p.write_text(s,encoding='utf-8')
PY

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
  | xargs -0 -r sed -i 's/1\.3\.61/1.3.62/g'

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

test -f "$TMP/outer/com_decaroforms_1.3.62.zip"
test -f "$TMP/outer/plg_system_decaroforms_1.3.62.zip"
test -f "$TMP/outer/plg_editors-xtd_decaroforms_1.3.62.zip"
grep -q 'com_decaroforms_1.3.62.zip' "$MANIFEST"
grep -q 'plg_system_decaroforms_1.3.62.zip' "$MANIFEST"
grep -q 'plg_editors-xtd_decaroforms_1.3.62.zip' "$MANIFEST"
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

grep -q "version:'1.3.62'" "$BUILDER"
grep -q 'function structureQueue(e,handle,type,id,label){if(editorLocked)return;' "$BUILDER"
grep -q 'if(cancel||editorLocked||!spec)return;' "$BUILDER"
grep -q 'Forms 1.3.62: Bloccato/Modifica now governs Campo, Riga and Sezione uniformly' "$BUILDER"
# Approved Field drag remains present and untouched.
grep -q 'function smartQueueDrag(e,card,key){if(editorLocked||!e.isPrimary' "$BUILDER"
grep -q 'function smartProjectedCanvasPoint' "$BUILDER"
grep -q 'function smartRunPointerFrame' "$BUILDER"
grep -q 'IN SPOSTAMENTO' "$BUILDER"
# Approved structure drag remains present.
grep -q 'function structureOverlayRect' "$BUILDER"
grep -q 'function structureRunPointerFrame' "$BUILDER"

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
entry=f'''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>{v}</version>\n\t\t<note>Correzione regressione Builder 1.3.61: la modalita Bloccato/Modifica ora governa in modo uniforme Campo, Riga e Sezione. In Bloccato nessuno dei tre puo essere trascinato; in Modifica restano attivi i tre drag. Aggiunti controlli server-side UI-state equivalenti all'avvio e al commit del drag strutturale, piu feedback visivo dei drag handle disabilitati. Il motore drag Campo approvato 1.3.60 e mantenuto invariato byte-per-byte.</note>\n\t</changelog>'''
if f'<version>{v}</version>' not in s:s=s.replace('<changelogs>','<changelogs>'+entry,1)
p.write_text(s,encoding='utf-8')
ET.parse(p)
PY

cat > "$TARGET_DIR/README.md" <<EOF
# Forms 1.3.62

Lock/drag consistency fix based on the manual Console recording:
- the recording showed pointer movement up to 108px while Field drag correctly stayed inactive in locked state;
- Row and Section drag from 1.3.61 did not honor the same editor lock and could still start;
- **Bloccato** now disables drag for Campo, Riga and Sezione uniformly;
- **Modifica** keeps all three drag systems active;
- structure drag checks the lock both before starting and before committing;
- locked drag handles use a disabled cursor/opacity for clearer UX;
- approved Field drag engine from 1.3.60/1.3.61 is preserved byte-for-byte;
- approved Row/Section vertical SOPRA/SOTTO drag from 1.3.61 is preserved;
- Row IDs, stable labels, visual lines, 50/50 slots, widths, Undo/Redo and atomic save are unchanged.

SHA256: $SHA
EOF

echo "Forms $NEW built: $TARGET"
echo "SHA256: $SHA"
