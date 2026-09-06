#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OLD="1.3.59"
NEW="1.3.60"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
JS_TMP="/tmp/forms-1360-builder.js"
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
    | xargs -0 -r sed -i 's/1\.3\.59/1.3.60/g'

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
style_end=s.rfind('</style>')
if style_end<0: raise SystemExit('1.3.60 missing style end')
css=r'''

/* Forms 1.3.60: slightly taller field rows for clearer drag zones and badges. */
.df-layout-card{
 min-height:68px;
 padding-top:10px;
 padding-bottom:10px;
 align-items:center;
}
/* Keep the magnetic drag target comfortable without making the Builder bulky. */
.df-smart-drop-overlay>span{
 min-height:22px;
 padding:3px 10px;
}
@media (max-width:900px){
 .df-layout-card{
  min-height:64px;
  padding-top:9px;
  padding-bottom:9px;
 }
}
@media (max-width:640px){
 .df-layout-card{
  min-height:62px;
 }
}
'''
s=s[:style_end]+css+s[style_end:]
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
  | xargs -0 -r sed -i 's/1\.3\.59/1.3.60/g'

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

test -f "$TMP/outer/com_decaroforms_1.3.60.zip"
test -f "$TMP/outer/plg_system_decaroforms_1.3.60.zip"
test -f "$TMP/outer/plg_editors-xtd_decaroforms_1.3.60.zip"
grep -q 'com_decaroforms_1.3.60.zip' "$MANIFEST"
grep -q 'plg_system_decaroforms_1.3.60.zip' "$MANIFEST"
grep -q 'plg_editors-xtd_decaroforms_1.3.60.zip' "$MANIFEST"
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
grep -q "version:'1.3.60'" "$BUILDER"
grep -q 'min-height:68px' "$BUILDER"
grep -q 'min-height:64px' "$BUILDER"
grep -q 'min-height:62px' "$BUILDER"
grep -q 'Forms 1.3.60: slightly taller field rows' "$BUILDER"
# Ensure the 1.3.59 visual drag feedback remains present.
grep -q 'IN SPOSTAMENTO' "$BUILDER"
grep -q -- '--df-drag-accent:#6f42c1' "$BUILDER"
# Ensure the 1.3.58 magnetic engine remains present.
grep -q 'function smartProjectedCanvasPoint' "$BUILDER"
grep -q 'function smartRunPointerFrame' "$BUILDER"

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
entry=f'''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>{v}</version>\n\t\t<note>Builder: aumentata leggermente l'altezza delle righe Campo per rendere piu leggibili e comode le zone magnetiche SOPRA/SOTTO e i relativi badge, senza rendere il Builder troppo alto. Desktop 68px, tablet 64px, smartphone 62px. Ridotta leggermente l'altezza del badge drag per mantenere margine visivo. Nessuna modifica alla logica drag fluida/magnetica 1.3.58 o ai colori 1.3.59.</note>\n\t</changelog>'''
if f'<version>{v}</version>' not in s:s=s.replace('<changelogs>','<changelogs>'+entry,1)
p.write_text(s,encoding='utf-8')
ET.parse(p)
PY

cat > "$TARGET_DIR/README.md" <<EOF
# Forms 1.3.60

Field-row spacing refinement based on the 2026-09-06 Builder screenshot review:
- field cards are slightly taller so the SOPRA/SOTTO magnetic halves no longer feel cramped around the drag badge;
- desktop minimum height: **68px**;
- tablet minimum height: **64px**;
- smartphone minimum height: **62px**;
- drag badge height/padding reduced slightly to keep comfortable space inside each half;
- structural Row headers are unchanged, so the Builder does not become unnecessarily bulky;
- 1.3.58 fluid/magnetic drag behavior and 1.3.59 violet color feedback are unchanged;
- Row IDs, Sections, visual lines, 50/50 slots, widths, Undo/Redo and atomic save preserved.

SHA256: $SHA
EOF

echo "Forms $NEW built: $TARGET"
echo "SHA256: $SHA"
