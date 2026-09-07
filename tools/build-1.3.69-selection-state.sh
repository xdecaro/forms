#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.68"
NEW="1.3.69"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-selection-old.txt /tmp/forms-selection-new.txt /tmp/forms-1369.js' EXIT
mkdir -p "$TMP/outer" "$TMP/unpacked" "$TARGET_DIR"
unzip -q "$BASE" -d "$TMP/outer"

for z in "$TMP/outer"/*.zip; do
  [ -f "$z" ] || continue
  b="$(basename "$z")"
  d="$TMP/unpacked/$b"
  mkdir -p "$d"
  unzip -q "$z" -d "$d"
done

COMP_DIR="$TMP/unpacked/com_decaroforms_${OLD}.zip"
B="$COMP_DIR/administrator/components/com_decaroforms/tmpl/builder/default.php"
test -f "$B"
cp "$B" /tmp/forms-selection-old.txt

python3 - "$B" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
repls=[
("function selectField(index){if(index==null||!selected[index])return;activeStructureSelection=null;activeFieldKey=selected[index].key;openFieldKeys.clear();openFieldKeys.add(activeFieldKey);renderSelected();document.querySelectorAll('.df-layout-card').forEach(card=>card.classList.toggle('is-active',card.dataset.fieldKey===activeFieldKey));}",
 "function selectField(index){if(index==null||!selected[index])return;activeStructureSelection=null;activeFieldKey=selected[index].key;openFieldKeys.clear();openFieldKeys.add(activeFieldKey);renderSelected();renderLayoutCanvas();}"),
("function selectRowSettings(rowNo){rowNo=Math.max(1,Number(rowNo)||1);activeStructureSelection={type:'row',id:rowIdForRow(rowNo),row:rowNo};renderSelected();renderLayoutCanvas();}",
 "function selectRowSettings(rowNo){rowNo=Math.max(1,Number(rowNo)||1);activeFieldKey=null;activeStructureSelection={type:'row',id:rowIdForRow(rowNo),row:rowNo};renderSelected();renderLayoutCanvas();}"),
("const sectionSelected=group.id!=='general'&&group.sectionField?.[0]?.key===activeFieldKey;",
 "const sectionSelected=!activeStructureSelection&&group.id!=='general'&&group.sectionField?.[0]?.key===activeFieldKey;"),
("const card=document.createElement('div');card.className='df-layout-card'+(f.key===activeFieldKey?' is-active':'');",
 "const card=document.createElement('div');card.className='df-layout-card'+(!activeStructureSelection&&f.key===activeFieldKey?' is-active':'');"),
("const activateRowAndToggle=()=>{const open=!rowGroup.classList.contains('is-open');activeStructureSelection={type:'row',id:rowId,row:model.rowNo};layoutRowState.set(rowId,open);renderSelected();renderLayoutCanvas();};",
 "const activateRowAndToggle=()=>{const open=!rowGroup.classList.contains('is-open');activeFieldKey=null;activeStructureSelection={type:'row',id:rowId,row:model.rowNo};layoutRowState.set(rowId,open);renderSelected();renderLayoutCanvas();};")
]
for old,new in repls:
    if old not in s: raise SystemExit('missing patch anchor: '+old[:90])
    s=s.replace(old,new,1)
css='''\n/* Forms 1.3.69: authoritative hierarchical selection state. */
.df-builder .df-layout-section-group.is-section.is-selected > .df-layout-section-head,
.df-builder .df-layout-section-group.is-section:has(.df-layout-row-group.is-selected) > .df-layout-section-head,
.df-builder .df-layout-section-group.is-section:has(.df-layout-card.is-active) > .df-layout-section-head{
 background:color-mix(in srgb,#7c3aed 16%,var(--bs-body-bg,#fff))!important;
 box-shadow:inset 4px 0 0 #7c3aed!important;
}
.df-builder .df-layout-row-group.is-selected > .df-layout-row-head,
.df-builder .df-layout-row-group:has(.df-layout-card.is-active) > .df-layout-row-head{
 background:color-mix(in srgb,#7c3aed 11%,var(--bs-body-bg,#fff))!important;
 box-shadow:inset 3px 0 0 color-mix(in srgb,#7c3aed 88%,transparent)!important;
}
.df-builder .df-layout-card.is-active{
 background:color-mix(in srgb,#7c3aed 9%,var(--bs-body-bg,#fff))!important;
 border-color:color-mix(in srgb,#7c3aed 48%,var(--bs-border-color,#d9dee5))!important;
 box-shadow:inset 4px 0 0 #7c3aed,0 0 0 1px color-mix(in srgb,#7c3aed 14%,transparent),0 1px 2px rgba(15,23,42,.05)!important;
}
.df-builder .df-layout-card.is-active [data-canvas-edit]{
 color:#7c3aed!important;
 background:color-mix(in srgb,#7c3aed 11%,transparent)!important;
}
'''
pos=s.rfind('</style>')
if pos<0: raise SystemExit('style end not found')
s=s[:pos]+css+s[pos:]
p.write_text(s,encoding='utf-8')
PY
cp "$B" /tmp/forms-selection-new.txt

python3 - <<'PY'
from pathlib import Path
import re
old=Path('/tmp/forms-selection-old.txt').read_text(encoding='utf-8')
new=Path('/tmp/forms-selection-new.txt').read_text(encoding='utf-8')
def f(src,name):
    m=re.search(r'function\s+'+re.escape(name)+r'\s*\(',src)
    if not m:return None
    a=src.find('{',m.start()); depth=0; quote=None; esc=False; tmpl=False
    for i in range(a,len(src)):
        c=src[i]
        if quote:
            if esc:esc=False
            elif c=='\\':esc=True
            elif c==quote:quote=None
        elif tmpl:
            if esc:esc=False
            elif c=='\\':esc=True
            elif c=='`':tmpl=False
        else:
            if c in "'\"":quote=c
            elif c=='`':tmpl=True
            elif c=='{':depth+=1
            elif c=='}':
                depth-=1
                if depth==0:return src[m.start():i+1]
    return None
for name in ['smartQueueDrag','smartBeginDrag','smartPointerMove','smartFinish','structureQueue','structureBegin','structurePointerMove','structureFinish','structureMoveRow','structureMoveSection']:
    if f(old,name)!=f(new,name): raise SystemExit('drag regression: '+name)
print('Drag regression check: OK')
PY

# Update versions in every unpacked child.
find "$TMP/unpacked" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.json' -o -name '*.md' \) -print0 | xargs -0 sed -i "s/${OLD//./\\.}/$NEW/g"
# Update package-level text files and references.
find "$TMP/outer" -maxdepth 1 -type f ! -name '*.zip' -print0 | xargs -0 -r sed -i "s/${OLD//./\\.}/$NEW/g"

# Rebuild child ZIPs with new version names.
rm -f "$TMP/outer"/*.zip
for d in "$TMP/unpacked"/*.zip; do
  oldname="$(basename "$d")"
  newname="${oldname//$OLD/$NEW}"
  (cd "$d" && zip -qr "$TMP/outer/$newname" .)
done

# Validate PHP/XML in unpacked children.
while IFS= read -r -d '' f; do php -l "$f" >/dev/null; done < <(find "$TMP/unpacked" -type f -name '*.php' -print0)
python3 - "$TMP/unpacked" "$TMP/outer" <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET,sys
for root in map(Path,sys.argv[1:]):
    for p in root.rglob('*.xml'):
        ET.parse(p)
print('XML validation: OK')
PY

# JS syntax check for builder inline scripts after neutralizing PHP blocks.
python3 - "$B" > /tmp/forms-1369.js <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
s=re.sub(r'<\?(?:php|=).*?\?>','null',s,flags=re.S)
parts=re.findall(r'<script(?:\s[^>]*)?>(.*?)</script>',s,flags=re.S|re.I)
print('\n'.join(parts))
PY
node --check /tmp/forms-1369.js >/dev/null

# Outer package.
rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

# Update feed.
python3 - "$ROOT/updates/pkg_decaroforms.xml" "$NEW" "$SHA" <<'PY'
from pathlib import Path
import sys,re
p=Path(sys.argv[1]); v=sys.argv[2]; sha=sys.argv[3]; s=p.read_text(encoding='utf-8')
s=re.sub(r'<version>[^<]+</version>',f'<version>{v}</version>',s,count=1)
s=re.sub(r'releases/[0-9.]+/pkg_decaroforms_[0-9.]+\.zip',f'releases/{v}/pkg_decaroforms_{v}.zip',s,count=1)
s=re.sub(r'<sha256>[0-9a-f]+</sha256>',f'<sha256>{sha}</sha256>',s,count=1)
p.write_text(s,encoding='utf-8')
PY

# Prepend changelog entry.
python3 - "$ROOT/updates/changelog.xml" "$NEW" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); v=sys.argv[2]; s=p.read_text(encoding='utf-8')
note="Builder: corretto lo stato gerarchico di selezione. Il Campo realmente attivo ora riceve background viola visibile, barra sinistra 4px e bordo viola; quando si passa tra Sezione, Riga e Campo il canvas viene ridisegnato eliminando classi is-selected obsolete. Una sola selezione reale alla volta; Sezione e Riga padre restano evidenziate solo come contesto (16% / 11%), Campo attivo 9%. Motori drag e dati invariati."
entry=f'\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>{v}</version>\n\t\t<note>{note}</note>\n\t</changelog>'
pos=s.find('>')+1
s=s[:pos]+entry+s[pos:]
p.write_text(s,encoding='utf-8')
PY

cat > "$TARGET_DIR/README.md" <<EOF
# Forms $NEW

Selection-state fix for the Builder:
- Field selection now redraws the canvas, removing stale Section/Row selection classes;
- only one real selection is active at a time;
- selected Field gets visible purple 9% background, 4px purple left bar and clearer purple border;
- parent Row remains contextual at 11%; parent Section remains contextual at 16%;
- selecting a Row clears the previous active Field state;
- Section/Row/Field remain 59px high;
- approved Field/Row/Section drag engines are regression-checked and unchanged;
- Row IDs/labels, empty Rows, 50/50 slots, widths, Undo/Redo, AI import and atomic save are preserved.

SHA256: $SHA
EOF

# Final checks.
python3 - "$ROOT/updates/pkg_decaroforms.xml" "$ROOT/updates/changelog.xml" <<'PY'
import xml.etree.ElementTree as ET,sys
for p in sys.argv[1:]: ET.parse(p)
print('Feed/changelog XML: OK')
PY
grep -q "<version>$NEW</version>" "$ROOT/updates/pkg_decaroforms.xml"
grep -q "$SHA" "$ROOT/updates/pkg_decaroforms.xml"
unzip -tq "$TARGET" >/dev/null
printf '%s\n' "$SHA" > "$TARGET_DIR/SHA256.txt"
echo "Forms $NEW ready: $SHA"
