#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OLD="1.3.64"
NEW="1.3.65"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
JS_TMP="/tmp/forms-1365-builder.js"
trap 'rm -rf "$TMP" "$JS_TMP"' EXIT

mkdir -p "$TMP/outer" "$TMP/children" "$TARGET_DIR"
test -f "$BASE"
unzip -t "$BASE" >/dev/null
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
    | xargs -0 -r sed -i 's/1\.3\.64/1.3.65/g'

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
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8')
end=s.rfind('</style>')
if end<0: raise SystemExit('missing </style>')
css=r'''

/* Forms 1.3.65: one 59px rhythm + root-state active edit mode. */
.df-builder .df-layout-section-head,
.df-builder .df-layout-row-head,
.df-builder .df-layout-card{
  min-height:59px!important;
}
.df-builder .df-layout-section-head{padding-top:8px!important;padding-bottom:8px!important}
.df-builder .df-layout-row-head{padding-top:8px!important;padding-bottom:8px!important}
.df-builder .df-layout-card{padding-top:7px!important;padding-bottom:7px!important}

/* Mode state is driven by the authoritative Builder root, not by focus styling. */
.df-builder:not(.is-locked) .df-editor-toolbar .df-lock-toggle[data-lock="0"]{
  background:#6f3cff!important;
  color:#fff!important;
  border-color:#6f3cff!important;
  box-shadow:none!important;
}
.df-builder:not(.is-locked) .df-editor-toolbar .df-lock-toggle[data-lock="0"] .df-ui-icon{color:#fff!important}
.df-builder:not(.is-locked) .df-editor-toolbar .df-lock-toggle[data-lock="1"]{
  background:var(--bs-body-bg,#fff)!important;
  color:var(--bs-body-color,#1f2937)!important;
  border-color:var(--df-border,#d9dee5)!important;
  box-shadow:none!important;
}
.df-builder.is-locked .df-editor-toolbar .df-lock-toggle[data-lock="1"]{
  background:#334155!important;
  color:#fff!important;
  border-color:#334155!important;
  box-shadow:none!important;
}
.df-builder.is-locked .df-editor-toolbar .df-lock-toggle[data-lock="1"] .df-ui-icon{color:#fff!important}
.df-builder.is-locked .df-editor-toolbar .df-lock-toggle[data-lock="0"]{
  background:var(--bs-body-bg,#fff)!important;
  color:var(--bs-body-color,#1f2937)!important;
  border-color:var(--df-border,#d9dee5)!important;
  box-shadow:none!important;
}

/* Keep the two buttons readable in dark mode while preserving the same state colors. */
html[data-bs-theme="dark"] .df-builder:not(.is-locked) .df-editor-toolbar .df-lock-toggle[data-lock="1"],
body[data-bs-theme="dark"] .df-builder:not(.is-locked) .df-editor-toolbar .df-lock-toggle[data-lock="1"],
html[data-color-scheme="dark"] .df-builder:not(.is-locked) .df-editor-toolbar .df-lock-toggle[data-lock="1"],
html[data-bs-theme="dark"] .df-builder.is-locked .df-editor-toolbar .df-lock-toggle[data-lock="0"],
body[data-bs-theme="dark"] .df-builder.is-locked .df-editor-toolbar .df-lock-toggle[data-lock="0"],
html[data-color-scheme="dark"] .df-builder.is-locked .df-editor-toolbar .df-lock-toggle[data-lock="0"]{
  background:#111827!important;
  color:#f8fafc!important;
  border-color:#475569!important;
}

/* 59px is intentional on desktop, tablet and smartphone for visual consistency with accordions 1-8. */
@media(max-width:900px){
  .df-builder .df-layout-section-head,.df-builder .df-layout-row-head,.df-builder .df-layout-card{min-height:59px!important}
  .df-builder .df-layout-section-head,.df-builder .df-layout-row-head{padding-top:8px!important;padding-bottom:8px!important}
  .df-builder .df-layout-card{padding-top:7px!important;padding-bottom:7px!important}
}
@media(max-width:560px){
  .df-builder .df-layout-section-head,.df-builder .df-layout-row-head,.df-builder .df-layout-card{min-height:59px!important}
  .df-builder .df-layout-section-head,.df-builder .df-layout-row-head{padding-top:7px!important;padding-bottom:7px!important}
  .df-builder .df-layout-card{padding-top:6px!important;padding-bottom:6px!important}
}
'''
s=s[:end]+css+s[end:]
p.write_text(s,encoding='utf-8')
PY

# Drag behavior must remain unchanged from the approved 1.3.64 base.
python3 - "$TMP/builder-before.php" "$BUILDER" <<'PY'
from pathlib import Path
import sys
before=Path(sys.argv[1]).read_text(encoding='utf-8').replace("version:'1.3.64'","version:'1.3.65'")
after=Path(sys.argv[2]).read_text(encoding='utf-8')

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
 if func(before,name)!=func(after,name):raise SystemExit('drag regression: '+name+' changed')
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

find "$TMP/outer" -maxdepth 2 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.json' -o -name '*.txt' -o -name '*.md' \) -print0 \
 | xargs -0 -r sed -i 's/1\.3\.64/1.3.65/g'

MANIFEST="$TMP/outer/pkg_decaroforms.xml"
test -f "$MANIFEST"
python3 - "$MANIFEST" "$NEW" <<'PY'
from pathlib import Path
import re,sys,xml.etree.ElementTree as ET
p=Path(sys.argv[1]);v=sys.argv[2];s=p.read_text(encoding='utf-8')
s=re.sub(r'<version>[^<]+</version>',f'<version>{v}</version>',s,count=1)
p.write_text(s,encoding='utf-8');ET.parse(p)
PY

test -f "$TMP/outer/com_decaroforms_1.3.65.zip"
test -f "$TMP/outer/plg_system_decaroforms_1.3.65.zip"
test -f "$TMP/outer/plg_editors-xtd_decaroforms_1.3.65.zip"
grep -q 'com_decaroforms_1.3.65.zip' "$MANIFEST"
grep -q 'plg_system_decaroforms_1.3.65.zip' "$MANIFEST"
grep -q 'plg_editors-xtd_decaroforms_1.3.65.zip' "$MANIFEST"
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

grep -q "version:'1.3.65'" "$BUILDER"
grep -q 'min-height:59px!important' "$BUILDER"
grep -q '.df-builder:not(.is-locked) .df-editor-toolbar .df-lock-toggle\[data-lock="0"\]' "$BUILDER"
grep -q '.df-builder.is-locked .df-editor-toolbar .df-lock-toggle\[data-lock="1"\]' "$BUILDER"
grep -q 'background:#6f3cff!important' "$BUILDER"
grep -q 'background:#334155!important' "$BUILDER"

(cd "$TMP/outer" && zip -qr "$TARGET" .)
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
entry=f'''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>{v}</version>\n\t\t<note>Builder UI: Sezione, Riga e Campo uniformati a 59px su desktop, tablet e smartphone, coerenti con gli accordion 1-8. Corretto definitivamente lo stato attivo Bloccato/Modifica usando lo stato autorevole .df-builder.is-locked: Modifica attiva viola pieno con testo bianco, Bloccato attivo grigio ardesia pieno con testo bianco; scelta inattiva neutra e dark mode coerente. Motori drag Campo/Riga/Sezione invariati.</note>\n\t</changelog>'''
if f'<version>{v}</version>' not in s:s=s.replace('<changelogs>','<changelogs>'+entry,1)
p.write_text(s,encoding='utf-8');ET.parse(p)
PY

cat > "$TARGET_DIR/README.md" <<EOF
# Forms 1.3.65

Uniform Builder rhythm and definitive edit-mode state:
- Section, Row and Field are all **59px** high on desktop, tablet and smartphone;
- sizing now matches the existing accordion rhythm used by sections 1-8;
- active **Modifica** is driven by `.df-builder:not(.is-locked)` and uses a solid purple background with white text;
- active **Bloccato** is driven by `.df-builder.is-locked` and uses a solid slate background with white text;
- inactive choice remains neutral, with explicit dark-mode treatment;
- selection highlighting from 1.3.63 remains intact;
- approved Field/Row/Section drag engines are regression-checked and unchanged;
- Row IDs, stable labels, visual lines, 50/50 slots, widths, Undo/Redo and atomic save remain unchanged.

SHA256: $SHA
EOF

echo "Forms $NEW built: $TARGET"
echo "SHA256: $SHA"
