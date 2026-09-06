#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.66"
NEW="1.3.67"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
JS_TMP="/tmp/forms-1367-builder.js"
trap 'rm -rf "$TMP" "$JS_TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/children" "$TARGET_DIR"
test -f "$BASE"
unzip -t "$BASE" >/dev/null
unzip -q "$BASE" -d "$TMP/outer"
MAP="$TMP/children-map.tsv"; : > "$MAP"
idx=0; BUILDER=""
for ZIP in "$TMP/outer"/*.zip; do
  [ -e "$ZIP" ] || continue
  idx=$((idx+1)); NAME="$(basename "$ZIP")"; NEWNAME="${NAME//$OLD/$NEW}"; CHILD="$TMP/children/$idx"
  mkdir -p "$CHILD"; unzip -q "$ZIP" -d "$CHILD"; printf '%s\t%s\n' "$idx" "$NEWNAME" >> "$MAP"
  find "$CHILD" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.js' -o -name '*.json' -o -name '*.css' -o -name '*.txt' -o -name '*.md' \) -print0 | xargs -0 -r sed -i 's/1\.3\.66/1.3.67/g'
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
cp "$BUILDER" "$TMP/builder-before.php"

python3 - "$BUILDER" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8');end=s.rfind('</style>')
if end<0: raise SystemExit('missing </style>')
css=r'''

/* Forms 1.3.67: hierarchical active path in the Builder.
   One real selection remains authoritative; parents receive context only. */
.df-builder-workspace .df-layout-section-head,
.df-builder-workspace .df-layout-row-head,
.df-builder-workspace .df-layout-card{
  transition:background-color .14s ease,border-color .14s ease,box-shadow .14s ease;
}

/* Direct active Section: strongest state for this level. */
.df-builder-workspace .df-layout-section-group.is-section.is-selected>.df-layout-section-head{
  background:color-mix(in srgb,#7c3aed 13%,var(--bs-body-bg,#fff))!important;
  box-shadow:inset 4px 0 0 #7c3aed!important;
}

/* Active Row: strong Row + light contextual Section parent. */
.df-builder-workspace .df-layout-row-group.is-selected>.df-layout-row-head{
  background:color-mix(in srgb,#7c3aed 13%,var(--bs-body-bg,#fff))!important;
  box-shadow:inset 4px 0 0 #7c3aed!important;
}
.df-builder-workspace .df-layout-section-group.is-section:not(.is-selected):has(> .df-layout-section-body .df-layout-row-group.is-selected)>.df-layout-section-head{
  background:color-mix(in srgb,#7c3aed 5%,var(--bs-body-bg,#fff))!important;
  box-shadow:inset 3px 0 0 color-mix(in srgb,#7c3aed 55%,transparent)!important;
}

/* Active Field: strongest Field, medium Row context, light Section context. */
.df-builder-workspace .df-layout-card.is-active{
  background:color-mix(in srgb,#7c3aed 14%,var(--bs-body-bg,#fff))!important;
  border-color:color-mix(in srgb,#7c3aed 62%,var(--df-border,#d9dee5))!important;
  box-shadow:inset 4px 0 0 #7c3aed,0 0 0 1px color-mix(in srgb,#7c3aed 24%,transparent)!important;
}
.df-builder-workspace .df-layout-row-group:not(.is-selected):has(> .df-layout-row-body .df-layout-card.is-active)>.df-layout-row-head{
  background:color-mix(in srgb,#7c3aed 8%,var(--bs-body-bg,#fff))!important;
  box-shadow:inset 3px 0 0 color-mix(in srgb,#7c3aed 72%,transparent)!important;
}
.df-builder-workspace .df-layout-section-group.is-section:not(.is-selected):has(> .df-layout-section-body .df-layout-card.is-active)>.df-layout-section-head{
  background:color-mix(in srgb,#7c3aed 5%,var(--bs-body-bg,#fff))!important;
  box-shadow:inset 3px 0 0 color-mix(in srgb,#7c3aed 55%,transparent)!important;
}

/* Dark mode: keep the hierarchy readable without turning the canvas into solid purple. */
html[data-bs-theme="dark"] .df-builder-workspace .df-layout-section-group.is-section.is-selected>.df-layout-section-head,
body[data-bs-theme="dark"] .df-builder-workspace .df-layout-section-group.is-section.is-selected>.df-layout-section-head,
html[data-color-scheme="dark"] .df-builder-workspace .df-layout-section-group.is-section.is-selected>.df-layout-section-head,
html[data-bs-theme="dark"] .df-builder-workspace .df-layout-row-group.is-selected>.df-layout-row-head,
body[data-bs-theme="dark"] .df-builder-workspace .df-layout-row-group.is-selected>.df-layout-row-head,
html[data-color-scheme="dark"] .df-builder-workspace .df-layout-row-group.is-selected>.df-layout-row-head{
  background:color-mix(in srgb,#8b5cf6 20%,var(--bs-body-bg,#111827))!important;
}
html[data-bs-theme="dark"] .df-builder-workspace .df-layout-card.is-active,
body[data-bs-theme="dark"] .df-builder-workspace .df-layout-card.is-active,
html[data-color-scheme="dark"] .df-builder-workspace .df-layout-card.is-active{
  background:color-mix(in srgb,#8b5cf6 22%,var(--bs-body-bg,#111827))!important;
  border-color:#8b5cf6!important;
}
html[data-bs-theme="dark"] .df-builder-workspace .df-layout-row-group:not(.is-selected):has(> .df-layout-row-body .df-layout-card.is-active)>.df-layout-row-head,
body[data-bs-theme="dark"] .df-builder-workspace .df-layout-row-group:not(.is-selected):has(> .df-layout-row-body .df-layout-card.is-active)>.df-layout-row-head,
html[data-color-scheme="dark"] .df-builder-workspace .df-layout-row-group:not(.is-selected):has(> .df-layout-row-body .df-layout-card.is-active)>.df-layout-row-head{
  background:color-mix(in srgb,#8b5cf6 14%,var(--bs-body-bg,#111827))!important;
}
html[data-bs-theme="dark"] .df-builder-workspace .df-layout-section-group.is-section:not(.is-selected):has(> .df-layout-section-body .df-layout-card.is-active)>.df-layout-section-head,
body[data-bs-theme="dark"] .df-builder-workspace .df-layout-section-group.is-section:not(.is-selected):has(> .df-layout-section-body .df-layout-card.is-active)>.df-layout-section-head,
html[data-color-scheme="dark"] .df-builder-workspace .df-layout-section-group.is-section:not(.is-selected):has(> .df-layout-section-body .df-layout-card.is-active)>.df-layout-section-head,
html[data-bs-theme="dark"] .df-builder-workspace .df-layout-section-group.is-section:not(.is-selected):has(> .df-layout-section-body .df-layout-row-group.is-selected)>.df-layout-section-head,
body[data-bs-theme="dark"] .df-builder-workspace .df-layout-section-group.is-section:not(.is-selected):has(> .df-layout-section-body .df-layout-row-group.is-selected)>.df-layout-section-head,
html[data-color-scheme="dark"] .df-builder-workspace .df-layout-section-group.is-section:not(.is-selected):has(> .df-layout-section-body .df-layout-row-group.is-selected)>.df-layout-section-head{
  background:color-mix(in srgb,#8b5cf6 9%,var(--bs-body-bg,#111827))!important;
}
'''
s=s[:end]+css+s[end:]
p.write_text(s,encoding='utf-8')
PY

# Drag engines are approved and must stay byte-identical apart from the release version elsewhere.
python3 - "$TMP/builder-before.php" "$BUILDER" <<'PY'
from pathlib import Path
import sys
before=Path(sys.argv[1]).read_text(encoding='utf-8');after=Path(sys.argv[2]).read_text(encoding='utf-8')
def func(s,name):
    start=s.find('function '+name+'(')
    if start<0: raise SystemExit('missing '+name)
    brace=s.find('{',start);depth=0;quote=None;esc=False;template=False;i=brace
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
                if depth==0:return s[start:i+1]
        i+=1
    raise SystemExit('unterminated '+name)
for name in ['smartQueueDrag','smartBeginDrag','smartPointerMove','smartFindDropSpec','smartFinishDrag','structureQueue','structureBegin','structurePointerMove','structureFindTarget','structureFinish']:
    if func(before,name)!=func(after,name): raise SystemExit('drag regression: '+name)
print('drag engines unchanged')
PY

rm -f "$TMP/outer"/*.zip
while IFS=$'\t' read -r IDX NEWNAME; do
  CHILD="$TMP/children/$IDX"
  while IFS= read -r -d '' PHP; do php -l "$PHP" >/dev/null; done < <(find "$CHILD" -type f -name '*.php' -print0)
  while IFS= read -r -d '' XML; do python3 - "$XML" <<'PY'
import sys,xml.etree.ElementTree as ET
ET.parse(sys.argv[1])
PY
  done < <(find "$CHILD" -type f -name '*.xml' -print0)
  (cd "$CHILD" && zip -qr "$TMP/outer/$NEWNAME" .)
done < "$MAP"
find "$TMP/outer" -maxdepth 2 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.json' -o -name '*.txt' -o -name '*.md' \) -print0 | xargs -0 -r sed -i 's/1\.3\.66/1.3.67/g'
MANIFEST="$TMP/outer/pkg_decaroforms.xml"
python3 - "$MANIFEST" "$NEW" <<'PY'
from pathlib import Path
import re,sys,xml.etree.ElementTree as ET
p=Path(sys.argv[1]);v=sys.argv[2];s=p.read_text(encoding='utf-8');s=re.sub(r'<version>[^<]+</version>',f'<version>{v}</version>',s,count=1);p.write_text(s,encoding='utf-8');ET.parse(p)
PY
test -f "$TMP/outer/com_decaroforms_1.3.67.zip"
test -f "$TMP/outer/plg_system_decaroforms_1.3.67.zip"
test -f "$TMP/outer/plg_editors-xtd_decaroforms_1.3.67.zip"
for C in "$TMP/outer"/*.zip; do unzip -t "$C" >/dev/null; done
php -l "$BUILDER" >/dev/null
python3 - "$BUILDER" "$JS_TMP" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8');js='\n'.join(m.group(1) for m in re.finditer(r'<script(?:\s[^>]*)?>(.*?)</script>',s,re.S|re.I));js=re.sub(r'<\?(?:php|=).*?\?>','null',js,flags=re.S|re.I);Path(sys.argv[2]).write_text(js,encoding='utf-8')
PY
node --check "$JS_TMP"
grep -q "version:'1.3.67'" "$BUILDER"
grep -q 'hierarchical active path' "$BUILDER"
grep -q ':has(> .df-layout-row-body .df-layout-card.is-active)' "$BUILDER"
grep -q ':has(> .df-layout-section-body .df-layout-card.is-active)' "$BUILDER"
grep -q 'min-height:59px!important' "$BUILDER"
(
 cd "$TMP/outer"; zip -qr "$TARGET" .
)
unzip -t "$TARGET" >/dev/null
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"
FEED="$ROOT/updates/pkg_decaroforms.xml"
python3 - "$FEED" "$NEW" "$SHA" <<'PY'
from pathlib import Path
import re,sys,xml.etree.ElementTree as ET
p=Path(sys.argv[1]);v=sys.argv[2];sha=sys.argv[3];s=p.read_text(encoding='utf-8');s=re.sub(r'<version>[^<]+</version>',f'<version>{v}</version>',s,count=1);s=re.sub(r'releases/[0-9.]+/pkg_decaroforms_[0-9.]+\.zip',f'releases/{v}/pkg_decaroforms_{v}.zip',s,count=1);s=re.sub(r'<sha256>[^<]+</sha256>',f'<sha256>{sha}</sha256>',s,count=1);p.write_text(s,encoding='utf-8');ET.parse(p)
PY
CHANGE="$ROOT/updates/changelog.xml"
python3 - "$CHANGE" "$NEW" <<'PY'
from pathlib import Path
import sys,xml.etree.ElementTree as ET
p=Path(sys.argv[1]);v=sys.argv[2];s=p.read_text(encoding='utf-8');entry=f'''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>{v}</version>\n\t\t<note>Builder: evidenziazione gerarchica viola dell'elemento in modifica. Sezione attiva forte; Riga attiva forte con Sezione padre leggera; Campo attivo più evidente con Riga padre media e Sezione padre leggera. Una sola selezione reale, genitori solo contestuali. Altezza uniforme 59px, light/dark e motori drag approvati invariati.</note>\n\t</changelog>''';
if f'<version>{v}</version>' not in s:s=s.replace('<changelogs>','<changelogs>'+entry,1)
p.write_text(s,encoding='utf-8');ET.parse(p)
PY
cat > "$TARGET_DIR/README.md" <<EOF
# Forms 1.3.67

Hierarchical active selection for the Builder:
- active Section: clear purple state;
- active Row: clear purple Row + subtle Section parent context;
- active Field: strongest Field + medium Row parent + subtle Section parent;
- only one real selection remains active; parent colors are contextual only;
- Section, Row and Field remain 59px high;
- light and dark mode supported;
- approved Field/Row/Section drag engines are byte-regression-checked and unchanged;
- Row IDs, stable labels, 50/50 slots, widths, Undo/Redo and atomic save remain unchanged.

SHA256: $SHA
EOF
echo "Forms $NEW built: $TARGET"
echo "SHA256: $SHA"
