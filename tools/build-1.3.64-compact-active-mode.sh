#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OLD="1.3.63"
NEW="1.3.64"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
JS_TMP="/tmp/forms-1364-builder.js"
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
    | xargs -0 -r sed -i 's/1\.3\.63/1.3.64/g'

  while IFS= read -r -d '' XML; do
    if grep -q '<extension' "$XML" && grep -q '<version>' "$XML"; then
      python3 - "$XML" "$NEW" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); v=sys.argv[2]; s=p.read_text(encoding='utf-8')
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
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
end=s.rfind('</style>')
if end<0: raise SystemExit('missing </style>')
css=r'''

/* Forms 1.3.64: compact Builder spacing + unmistakable active edit mode. */
.df-builder .df-layout-section-head{min-height:64px!important;padding-top:10px!important;padding-bottom:10px!important}
.df-builder .df-layout-row-head{min-height:62px!important;padding-top:9px!important;padding-bottom:9px!important}
.df-builder .df-layout-card{min-height:64px!important;padding-top:8px!important;padding-bottom:8px!important}

/* The active mode must be obvious, not just outlined. */
.df-builder .df-editor-toolbar .df-lock-toggle.is-active[data-lock="0"]{
  background:#6f3cff!important;
  color:#fff!important;
  border-color:#6f3cff!important;
  box-shadow:0 0 0 2px color-mix(in srgb,#6f3cff 18%,transparent)!important;
}
.df-builder .df-editor-toolbar .df-lock-toggle.is-active[data-lock="0"] .df-ui-icon{color:#fff!important}
.df-builder .df-editor-toolbar .df-lock-toggle.is-active[data-lock="1"]{
  background:#334155!important;
  color:#fff!important;
  border-color:#334155!important;
  box-shadow:0 0 0 2px color-mix(in srgb,#334155 14%,transparent)!important;
}
.df-builder .df-editor-toolbar .df-lock-toggle.is-active[data-lock="1"] .df-ui-icon{color:#fff!important}

/* Keep inactive choice neutral in both themes. */
html:not([data-bs-theme="dark"]):not([data-color-scheme="dark"]) body:not([data-bs-theme="dark"]) .df-builder .df-editor-toolbar .df-lock-toggle:not(.is-active),
html[data-bs-theme="light"] .df-builder .df-editor-toolbar .df-lock-toggle:not(.is-active){
  background:#fff!important;color:#1f2937!important;border-color:#d9dee5!important;box-shadow:none!important;
}
html[data-bs-theme="dark"] .df-builder .df-editor-toolbar .df-lock-toggle:not(.is-active),
body[data-bs-theme="dark"] .df-builder .df-editor-toolbar .df-lock-toggle:not(.is-active),
html[data-color-scheme="dark"] .df-builder .df-editor-toolbar .df-lock-toggle:not(.is-active){
  background:#111827!important;color:#f8fafc!important;border-color:#475569!important;box-shadow:none!important;
}

/* Compact responsive rhythm without reducing touch clarity too much. */
@media(max-width:900px){
  .df-builder .df-layout-section-head,.df-builder .df-layout-row-head,.df-builder .df-layout-card{min-height:60px!important}
  .df-builder .df-layout-section-head{padding-top:9px!important;padding-bottom:9px!important}
  .df-builder .df-layout-row-head,.df-builder .df-layout-card{padding-top:8px!important;padding-bottom:8px!important}
}
@media(max-width:560px){
  .df-builder .df-layout-section-head,.df-builder .df-layout-row-head,.df-builder .df-layout-card{min-height:58px!important}
  .df-builder .df-layout-section-head,.df-builder .df-layout-row-head,.df-builder .df-layout-card{padding-top:7px!important;padding-bottom:7px!important}
}
'''
s=s[:end]+css+s[end:]
p.write_text(s,encoding='utf-8')
PY

# Regression guard: drag engines must remain byte-identical to the 1.3.63 base (version text aside).
python3 - "$TMP/builder-before.php" "$BUILDER" <<'PY'
from pathlib import Path
import sys
before=Path(sys.argv[1]).read_text(encoding='utf-8')
after=Path(sys.argv[2]).read_text(encoding='utf-8')

def func(s,name):
    start=s.find('function '+name+'(')
    if start<0: raise SystemExit('missing '+name)
    brace=s.find('{',start); depth=0; quote=None; esc=False; template=False
    i=brace
    while i<len(s):
        c=s[i]
        if quote:
            if esc: esc=False
            elif c=='\\': esc=True
            elif c==quote: quote=None
        elif template:
            if esc: esc=False
            elif c=='\\': esc=True
            elif c=='`': template=False
        else:
            if c in "'\"": quote=c
            elif c=='`': template=True
            elif c=='{': depth+=1
            elif c=='}':
                depth-=1
                if depth==0:return s[start:i+1]
        i+=1
    raise SystemExit('unterminated '+name)

for name in ['smartQueueDrag','smartBeginDrag','smartPointerMove','smartFindDropSpec','smartFinishDrag','structureQueue','structureBegin','structurePointerMove','structureFindTarget','structureFinish']:
    if func(before,name)!=func(after,name):
        raise SystemExit('drag regression: '+name+' changed')
print('drag engines unchanged')
PY

# Rebuild children.
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
  | xargs -0 -r sed -i 's/1\.3\.63/1.3.64/g'

MANIFEST="$TMP/outer/pkg_decaroforms.xml"
test -f "$MANIFEST"
python3 - "$MANIFEST" "$NEW" <<'PY'
from pathlib import Path
import re,sys,xml.etree.ElementTree as ET
p=Path(sys.argv[1]);v=sys.argv[2];s=p.read_text(encoding='utf-8')
s=re.sub(r'<version>[^<]+</version>',f'<version>{v}</version>',s,count=1)
p.write_text(s,encoding='utf-8');ET.parse(p)
PY

test -f "$TMP/outer/com_decaroforms_1.3.64.zip"
test -f "$TMP/outer/plg_system_decaroforms_1.3.64.zip"
test -f "$TMP/outer/plg_editors-xtd_decaroforms_1.3.64.zip"
grep -q 'com_decaroforms_1.3.64.zip' "$MANIFEST"
grep -q 'plg_system_decaroforms_1.3.64.zip' "$MANIFEST"
grep -q 'plg_editors-xtd_decaroforms_1.3.64.zip' "$MANIFEST"
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

grep -q "version:'1.3.64'" "$BUILDER"
grep -q 'min-height:64px!important' "$BUILDER"
grep -q 'min-height:62px!important' "$BUILDER"
grep -q 'data-lock="0"' "$BUILDER"
grep -q 'background:#6f3cff!important' "$BUILDER"
grep -q 'data-lock="1"' "$BUILDER"

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
entry=f'''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>{v}</version>\n\t\t<note>Builder UI refinement: Sezione, Riga e Campo riportati a un'altezza più compatta (64/62/64px desktop, 60px tablet, 58px smartphone). Lo stato attivo Bloccato/Modifica ora usa un background pieno e inequivocabile: Modifica viola con testo bianco, Bloccato grigio scuro con testo bianco, con varianti coerenti light/dark. Motori drag Campo/Riga/Sezione preservati senza modifiche.</note>\n\t</changelog>'''
if f'<version>{v}</version>' not in s:s=s.replace('<changelogs>','<changelogs>'+entry,1)
p.write_text(s,encoding='utf-8');ET.parse(p)
PY

cat > "$TARGET_DIR/README.md" <<EOF
# Forms 1.3.64

Compact Builder spacing and clear active edit mode:
- Section: 64px desktop;
- Row: 62px desktop;
- Field: 64px desktop;
- all three: 60px tablet and 58px smartphone;
- active **Modifica** uses solid purple background with white text;
- active **Bloccato** uses solid slate background with white text;
- inactive mode stays neutral in light and dark themes;
- selection highlighting from 1.3.63 remains unchanged;
- approved Field/Row/Section drag engines are regression-checked byte-for-byte and unchanged;
- Row IDs, stable labels, visual lines, 50/50 slots, widths, Undo/Redo and atomic save remain unchanged.

SHA256: $SHA
EOF

echo "Forms $NEW built: $TARGET"
echo "SHA256: $SHA"
