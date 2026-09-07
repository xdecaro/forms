#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.67"
NEW="1.3.68"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1368.js' EXIT

test -f "$BASE"
test ! -e "$TARGET"
mkdir -p "$TMP/outer" "$TMP/children" "$TARGET_DIR"
unzip -q "$BASE" -d "$TMP/outer"

COMP_DIR=""
for ZIP in "$TMP/outer"/*.zip; do
  [ -f "$ZIP" ] || continue
  NAME="$(basename "$ZIP")"
  DIR="$TMP/children/${NAME%.zip}"
  mkdir -p "$DIR"
  unzip -q "$ZIP" -d "$DIR"
  if [[ "$NAME" == com_decaroforms* ]]; then
    COMP_DIR="$DIR"
  fi
done

test -n "$COMP_DIR"
B="$COMP_DIR/administrator/components/com_decaroforms/tmpl/builder/default.php"
test -f "$B"
cp "$B" "$TMP/default-old.php"

python3 - "$B" "$TMP/default-old.php" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); oldp=Path(sys.argv[2])
s=p.read_text(encoding='utf-8')
old=oldp.read_text(encoding='utf-8')

# 1) Four clear creation actions, preserving existing Field/AI behavior.
old_markup='''            <div class="df-field-entry-actions">\n              <button class="df-add-field-main" type="button" id="df-open-library"><span aria-hidden="true">＋</span> Aggiungi campo</button>\n              <button class="df-ai-import-main" type="button" id="df-open-ai-import"><span aria-hidden="true">＋</span> Importa con AI</button>\n            </div>'''
new_markup='''            <div class="df-field-entry-actions" aria-label="Aggiungi elementi al modulo">\n              <button class="df-builder-add-structure df-add-section-main" type="button" id="df-add-section"><span aria-hidden="true">＋</span> Aggiungi sezione</button>\n              <button class="df-builder-add-structure df-add-row-main" type="button" id="df-add-row"><span aria-hidden="true">＋</span> Aggiungi riga</button>\n              <button class="df-add-field-main" type="button" id="df-open-library"><span aria-hidden="true">＋</span> Aggiungi campo</button>\n              <button class="df-ai-import-main" type="button" id="df-open-ai-import"><span aria-hidden="true">＋</span> Importa con AI</button>\n            </div>'''
if old_markup not in s:
    raise SystemExit('1.3.68: field-entry markup anchor missing')
s=s.replace(old_markup,new_markup,1)

# 2) Add first-class Section / empty Row creation functions.
anchor='function add(item){'
if anchor not in s:
    raise SystemExit('1.3.68: add(item) anchor missing')
helpers=r'''/* Forms 1.3.68: direct structure creation actions. */
function builderActiveSectionId(){
 const groups=layoutGroups();
 if(activeStructureSelection?.type==='row'){
  refreshActiveRowSelection();
  const rowNo=Math.max(1,Number(activeStructureSelection?.row)||1);
  return groups.find(g=>g.rows.some(r=>Number(r.rowNo)===rowNo))?.id||'general';
 }
 if(activeFieldKey){
  return groups.find(g=>g.sectionField?.[0]?.key===activeFieldKey||g.rows.some(r=>r.items.some(([f])=>f.key===activeFieldKey)))?.id||'general';
 }
 return'general';
}
function addBuilderSection(){
 if(editorLocked)return false;
 const row=Math.max(0,...logicalRowNumbers())+1;
 const x=defaultFieldConfig({key:'section',label:'Nuova sezione',type:'heading',category:'structure',required:false,placeholder:'',default:'',help:'',options:[],config:{content:'',conditions:[],condition_logic:'all',condition_action:'show',layout:{row,col:1,width:100}}});
 x.key=uniqueKey(x.key);x.config.layout={...(x.config.layout||{}),row,col:1,width:100};
 selected.push(x);normalizeLayoutRows();sortSelectedByLayout();
 activeStructureSelection=null;activeFieldKey=x.key;openFieldKeys.clear();openFieldKeys.add(x.key);
 const sectionId='section:'+x.key;layoutSectionState.set(sectionId,true);
 renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();sync();clearTimeout(historyTimer);pushHistory();
 requestAnimationFrame(()=>{[...document.querySelectorAll('.df-layout-section-group')].find(el=>el.dataset.sectionId===sectionId)?.scrollIntoView({behavior:'smooth',block:'nearest'});});
 return true;
}
function addBuilderRow(){
 if(editorLocked)return false;
 normalizeLayoutRows();
 const sectionId=builderActiveSectionId(),blocks=structureRowBlocks(),rowId=newRowId();
 const empty={rowNo:0,rowId,fields:[],meta:{id:rowId,title:'',description:''},sectionKey:null,openState:true};
 let at=blocks.length;
 if(sectionId==='general'){
  const range=structureSectionRange(blocks,'general');at=range?.end??0;
 }else{
  const range=structureSectionRange(blocks,sectionId);at=range?.end??blocks.length;
 }
 blocks.splice(Math.max(0,Math.min(blocks.length,at)),0,empty);structureApplyBlocks(blocks);normalizeLayoutRows();
 const newRow=rowNoForId(rowId)||Math.max(1,at+1);
 activeStructureSelection={type:'row',id:rowId,row:newRow};layoutRowState.set(rowId,true);if(sectionId!=='general')layoutSectionState.set(sectionId,true);
 renderSelected();renderLayoutCanvas();renderColumns();renderTokens();renderUserEmailFields();sync();clearTimeout(historyTimer);pushHistory();
 requestAnimationFrame(()=>{[...document.querySelectorAll('.df-layout-row-group')].find(el=>el.dataset.rowId===rowId)?.scrollIntoView({behavior:'smooth',block:'nearest'});});
 return true;
}
/* End Forms 1.3.68 direct structure creation actions. */
'''
s=s.replace(anchor,helpers+'\n'+anchor,1)

# 3) Clicking the center of a Section selects it as well as toggling it.
old_section="const toggleSection=()=>{layoutSectionState.set(group.id,!wrap.classList.contains('is-open'));renderLayoutCanvas();};head.addEventListener('click',e=>{if(Date.now()<structureSuppressClickUntil||e.target.closest('.df-layout-structure-handle'))return;if(e.target.closest('button'))return;toggleSection();});head.addEventListener('keydown',e=>{if((e.key==='Enter'||e.key===' ')&&!e.target.closest('button')){e.preventDefault();toggleSection();}});"
new_section="const toggleSection=()=>{layoutSectionState.set(group.id,!wrap.classList.contains('is-open'));renderLayoutCanvas();};head.addEventListener('click',e=>{if(Date.now()<structureSuppressClickUntil||e.target.closest('.df-layout-structure-handle'))return;if(e.target.closest('button'))return;if(group.sectionField){const [,si]=group.sectionField;selectField(si);}toggleSection();});head.addEventListener('keydown',e=>{if((e.key==='Enter'||e.key===' ')&&!e.target.closest('button')){e.preventDefault();if(group.sectionField){const [,si]=group.sectionField;selectField(si);}toggleSection();}});"
if old_section not in s:
    raise SystemExit('1.3.68: section click anchor missing')
s=s.replace(old_section,new_section,1)

# 4) Clicking the center of a Row selects that Row and toggles it in one render.
old_row="const toggleRow=()=>{layoutRowState.set(rowId,!rowGroup.classList.contains('is-open'));renderLayoutCanvas();};rowHead.onclick=e=>{if(Date.now()<structureSuppressClickUntil||e.target.closest('.df-layout-structure-handle')||e.target.closest('button'))return;toggleRow();};rowHead.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();toggleRow();}};"
new_row="const activateRowAndToggle=()=>{const open=!rowGroup.classList.contains('is-open');activeStructureSelection={type:'row',id:rowId,row:model.rowNo};layoutRowState.set(rowId,open);renderSelected();renderLayoutCanvas();};rowHead.onclick=e=>{if(Date.now()<structureSuppressClickUntil||e.target.closest('.df-layout-structure-handle')||e.target.closest('button'))return;activateRowAndToggle();};rowHead.onkeydown=e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();activateRowAndToggle();}};"
if old_row not in s:
    raise SystemExit('1.3.68: row click anchor missing')
s=s.replace(old_row,new_row,1)

# 5) Wire the two new buttons before initial rendering.
init_anchor='ensureInitialFieldWorkspace();renderLayout();renderTokens();renderUserEmailFields();renderAdditional();renderEmailPickers(false);sync();'
if init_anchor not in s:
    raise SystemExit('1.3.68: init anchor missing')
wire="document.getElementById('df-add-section')?.addEventListener('click',addBuilderSection);document.getElementById('df-add-row')?.addEventListener('click',addBuilderRow);"
s=s.replace(init_anchor,wire+init_anchor,1)

# 6) Stronger, inverse hierarchy: Section > Row > Field, with explicit active Field bar.
css=r'''
/* Forms 1.3.68: stronger hierarchical selection and 2x2 creation actions. */
.df-builder .df-field-entry-actions{display:grid!important;grid-template-columns:repeat(2,minmax(0,1fr));gap:10px!important;align-items:stretch!important}
.df-builder .df-field-entry-actions>button{width:100%;min-width:0;min-height:46px}
.df-builder .df-builder-add-structure{display:flex;align-items:center;justify-content:center;gap:7px;border:1px solid color-mix(in srgb,#7c3aed 58%,var(--df-border));border-radius:7px;background:color-mix(in srgb,#7c3aed 7%,var(--bs-body-bg,#fff));color:color-mix(in srgb,#7c3aed 88%,var(--bs-body-color,#1f2937));font-weight:850;cursor:pointer;transition:background .16s ease,border-color .16s ease,transform .16s ease}
.df-builder .df-add-section-main{background:color-mix(in srgb,#7c3aed 12%,var(--bs-body-bg,#fff));border-color:color-mix(in srgb,#7c3aed 72%,var(--df-border))}
.df-builder .df-add-row-main{background:color-mix(in srgb,#7c3aed 8%,var(--bs-body-bg,#fff))}
.df-builder .df-builder-add-structure:hover,.df-builder .df-builder-add-structure:focus-visible{background:color-mix(in srgb,#7c3aed 17%,var(--bs-body-bg,#fff));border-color:#7c3aed;outline:none}
.df-builder.is-locked .df-builder-add-structure{opacity:.46;cursor:not-allowed}

/* Parent hierarchy is intentionally stronger than the child background. */
.df-builder .df-layout-section-group.is-section:has(.df-layout-row-group.is-selected)>.df-layout-section-head,
.df-builder .df-layout-section-group.is-section:has(.df-layout-card.is-active)>.df-layout-section-head,
.df-builder .df-layout-section-group.is-section.is-selected>.df-layout-section-head{background:color-mix(in srgb,#7c3aed 16%,var(--bs-body-bg,#fff))!important}
.df-builder .df-layout-section-group.is-section.is-selected>.df-layout-section-head{box-shadow:inset 4px 0 0 #7c3aed!important}
.df-builder .df-layout-section-group.is-section:not(.is-selected):has(.df-layout-row-group.is-selected)>.df-layout-section-head,
.df-builder .df-layout-section-group.is-section:not(.is-selected):has(.df-layout-card.is-active)>.df-layout-section-head{box-shadow:inset 2px 0 0 color-mix(in srgb,#7c3aed 72%,transparent)!important}

.df-builder .df-layout-row-group:has(.df-layout-card.is-active)>.df-layout-row-head,
.df-builder .df-layout-row-group.is-selected>.df-layout-row-head{background:color-mix(in srgb,#7c3aed 11%,var(--bs-body-bg,#fff))!important}
.df-builder .df-layout-row-group.is-selected>.df-layout-row-head{box-shadow:inset 4px 0 0 #7c3aed!important}
.df-builder .df-layout-row-group:not(.is-selected):has(.df-layout-card.is-active)>.df-layout-row-head{box-shadow:inset 2px 0 0 color-mix(in srgb,#7c3aed 68%,transparent)!important}

.df-builder .df-layout-card.is-active{background:color-mix(in srgb,#7c3aed 8%,var(--bs-body-bg,#fff))!important;border-color:color-mix(in srgb,#7c3aed 62%,var(--df-border))!important;box-shadow:inset 4px 0 0 #7c3aed,0 0 0 1px color-mix(in srgb,#7c3aed 18%,transparent)!important}
.df-builder .df-layout-card.is-active [data-field-edit],.df-builder .df-layout-card.is-active .df-icon-only[data-act="edit"]{color:#7c3aed!important}

html[data-bs-theme="dark"] .df-builder .df-layout-section-group.is-section:has(.df-layout-row-group.is-selected)>.df-layout-section-head,
body[data-bs-theme="dark"] .df-builder .df-layout-section-group.is-section:has(.df-layout-row-group.is-selected)>.df-layout-section-head,
html[data-bs-theme="dark"] .df-builder .df-layout-section-group.is-section:has(.df-layout-card.is-active)>.df-layout-section-head,
body[data-bs-theme="dark"] .df-builder .df-layout-section-group.is-section:has(.df-layout-card.is-active)>.df-layout-section-head,
html[data-bs-theme="dark"] .df-builder .df-layout-section-group.is-section.is-selected>.df-layout-section-head,
body[data-bs-theme="dark"] .df-builder .df-layout-section-group.is-section.is-selected>.df-layout-section-head{background:color-mix(in srgb,#a78bfa 22%,var(--bs-body-bg,#111827))!important}
html[data-bs-theme="dark"] .df-builder .df-layout-row-group:has(.df-layout-card.is-active)>.df-layout-row-head,
body[data-bs-theme="dark"] .df-builder .df-layout-row-group:has(.df-layout-card.is-active)>.df-layout-row-head,
html[data-bs-theme="dark"] .df-builder .df-layout-row-group.is-selected>.df-layout-row-head,
body[data-bs-theme="dark"] .df-builder .df-layout-row-group.is-selected>.df-layout-row-head{background:color-mix(in srgb,#a78bfa 16%,var(--bs-body-bg,#111827))!important}
html[data-bs-theme="dark"] .df-builder .df-layout-card.is-active,
body[data-bs-theme="dark"] .df-builder .df-layout-card.is-active{background:color-mix(in srgb,#a78bfa 12%,var(--bs-body-bg,#111827))!important;border-color:#8b5cf6!important}
html[data-bs-theme="dark"] .df-builder .df-builder-add-structure,
body[data-bs-theme="dark"] .df-builder .df-builder-add-structure{background:color-mix(in srgb,#a78bfa 12%,var(--bs-body-bg,#111827));border-color:#6d5ca8;color:#ede9fe}
@media(max-width:640px){.df-builder .df-field-entry-actions{grid-template-columns:1fr!important}}
'''
style_end=s.rfind('</style>')
if style_end<0:
    raise SystemExit('1.3.68: style end missing')
s=s[:style_end]+css+'\n'+s[style_end:]

# Runtime version only; historical comments stay historical.
s=s.replace("version:'1.3.67'","version:'1.3.68'")

# Regression check: drag engines must remain byte-identical.
def extract(src,name):
    start=src.find('function '+name+'(')
    if start<0:return None
    brace=src.find('{',start); depth=0; quote=None; esc=False; template=False; i=brace
    while i<len(src):
        c=src[i]
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
                if depth==0:return src[start:i+1]
        i+=1
    return None
for name in ['smartQueueDrag','smartBeginDrag','smartPointerMove','smartFinishDrag','structureQueue','structurePointerMove','structureFinish','structureMoveRow','structureMoveSection']:
    a=extract(old,name); b=extract(s,name)
    if a is None or b is None or a!=b:
        raise SystemExit('1.3.68: drag regression in '+name)

p.write_text(s,encoding='utf-8')
PY

# Version manifests in all child packages and rebuild each child ZIP.
for ZIP in "$TMP/outer"/*.zip; do
  [ -f "$ZIP" ] || continue
  NAME="$(basename "$ZIP")"
  DIR="$TMP/children/${NAME%.zip}"
  python3 - "$DIR" "$OLD" "$NEW" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]); old=sys.argv[2]; new=sys.argv[3]
for p in root.rglob('*.xml'):
    try:s=p.read_text(encoding='utf-8')
    except UnicodeDecodeError:continue
    if old in s:p.write_text(s.replace(old,new),encoding='utf-8')
PY
  NEWNAME="${NAME//$OLD/$NEW}"
  rm -f "$ZIP"
  (cd "$DIR" && zip -qr "$TMP/outer/$NEWNAME" . -x '*.DS_Store' '__MACOSX/*')
done

# Outer manifest references + version.
python3 - "$TMP/outer" "$OLD" "$NEW" <<'PY'
from pathlib import Path
import sys
root=Path(sys.argv[1]); old=sys.argv[2]; new=sys.argv[3]
for p in root.glob('*.xml'):
    s=p.read_text(encoding='utf-8')
    if old in s:p.write_text(s.replace(old,new),encoding='utf-8')
PY

# Static checks before packaging.
find "$COMP_DIR" -type f -name '*.php' -print0 | xargs -0 -n1 php -l >/tmp/forms-1368-php.log
python3 - "$B" /tmp/forms-1368.js <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
js='\n'.join(re.findall(r'<script(?:\s[^>]*)?>(.*?)</script>',s,re.S|re.I))
js=re.sub(r'<\?php.*?\?>','null',js,flags=re.S)
Path(sys.argv[2]).write_text(js,encoding='utf-8')
PY
node --check /tmp/forms-1368.js
python3 - "$TMP" <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET,sys
for p in Path(sys.argv[1]).rglob('*.xml'):
    ET.parse(p)
PY

grep -q 'id="df-add-section"' "$B"
grep -q 'id="df-add-row"' "$B"
grep -q 'function addBuilderSection()' "$B"
grep -q 'function addBuilderRow()' "$B"
grep -q 'activateRowAndToggle' "$B"
grep -q '16%,var(--bs-body-bg' "$B"
grep -q '11%,var(--bs-body-bg' "$B"
grep -q '8%,var(--bs-body-bg' "$B"

# Build outer package.
(cd "$TMP/outer" && zip -qr "$TARGET" . -x '*.DS_Store' '__MACOSX/*')
unzip -tq "$TARGET" >/dev/null
for ZIP in "$TMP/outer"/*.zip; do unzip -tq "$ZIP" >/dev/null; done
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

# Release README.
cat > "$TARGET_DIR/README.md" <<EOF
# Forms $NEW

Builder structure actions and clearer direct selection:
- added **Aggiungi sezione** and **Aggiungi riga** beside the existing Aggiungi campo / Importa con AI actions;
- Aggiungi sezione creates a new empty Section at the end and selects it immediately;
- Aggiungi riga creates a persistent empty Row inside the currently selected Section/Row/Field context, otherwise in General;
- clicking the center of a Section or Row now both selects it (purple state) and toggles its accordion; edit icons remain available;
- hierarchical purple is intentionally stronger outside-in: Section 16%, Row 11%, Field 8%; the real active Field also has a solid 4px purple bar and clearer border;
- 2x2 action grid on desktop/tablet and single-column actions on narrow smartphones;
- existing Field library behavior, AI import, 59px rhythm, Row IDs/labels, empty Rows, 50/50 slots, Undo/Redo, atomic save, light/dark mode and approved drag engines are preserved.

SHA256: $SHA
EOF

# Update server feed.
python3 - "$ROOT/updates/pkg_decaroforms.xml" "$OLD" "$NEW" "$SHA" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); old,new,sha=sys.argv[2:5]; s=p.read_text(encoding='utf-8')
s=s.replace(f'<version>{old}</version>',f'<version>{new}</version>',1)
s=s.replace(f'/releases/{old}/pkg_decaroforms_{old}.zip',f'/releases/{new}/pkg_decaroforms_{new}.zip',1)
s=re.sub(r'<sha256>[0-9a-fA-F]+</sha256>',f'<sha256>{sha}</sha256>',s,count=1)
p.write_text(s,encoding='utf-8')
PY

# Changelog: prepend a valid entry without rewriting historical entries.
python3 - "$ROOT/updates/changelog.xml" "$NEW" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); new=sys.argv[2]; s=p.read_text(encoding='utf-8')
entry=f'''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>{new}</version>\n\t\t<note>Builder: aggiunti Aggiungi sezione e Aggiungi riga accanto ad Aggiungi campo e Importa con AI. La nuova Sezione nasce vuota in fondo; la nuova Riga nasce vuota nel contesto della Sezione/Riga/Campo selezionato, altrimenti in Generale. Clic sul centro di Sezione e Riga ora seleziona anche l'accordion e mostra subito lo stato viola. Gerarchia viola invertita e piu leggibile: Sezione 16%, Riga 11%, Campo 8% con barra attiva 4px. Drag, 59px, Row ID, 50/50, Undo/Redo, salvataggio e dark mode preservati.</note>\n\t</changelog>'''
if f'<version>{new}</version>' in s: raise SystemExit('duplicate changelog version')
s=s.replace('<changelogs>','<changelogs>'+entry,1)
p.write_text(s,encoding='utf-8')
PY

# Final XML and feed/hash validation.
python3 - "$ROOT/updates/pkg_decaroforms.xml" "$ROOT/updates/changelog.xml" <<'PY'
import xml.etree.ElementTree as ET,sys
for f in sys.argv[1:]:ET.parse(f)
PY
grep -q "<version>$NEW</version>" "$ROOT/updates/pkg_decaroforms.xml"
grep -q "$SHA" "$ROOT/updates/pkg_decaroforms.xml"
grep -q "releases/$NEW/pkg_decaroforms_$NEW.zip" "$ROOT/updates/pkg_decaroforms.xml"

echo "Forms $NEW ready"
echo "SHA256=$SHA"
