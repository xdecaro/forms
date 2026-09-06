#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OLD="1.3.58"
NEW="1.3.59"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
JS_TMP="/tmp/forms-1359-builder.js"
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
    | xargs -0 -r sed -i 's/1\.3\.58/1.3.59/g'

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
if style_end<0: raise SystemExit('1.3.59 missing style end')
css=r'''

/* Forms 1.3.59: drag color feedback + visible source placeholder. */
:root,
[data-bs-theme="light"]{
 --df-drag-accent:#6f42c1;
 --df-drag-accent-rgb:111,66,193;
 --df-drag-on-accent:#fff;
}
[data-bs-theme="dark"]{
 --df-drag-accent:#a78bfa;
 --df-drag-accent-rgb:167,139,250;
 --df-drag-on-accent:#17111f;
}
body.df-smart-drag-active .df-layout-card.df-smart-source-hidden{
 display:flex!important;
 visibility:visible!important;
 opacity:.48!important;
 pointer-events:none!important;
 background:rgba(var(--df-drag-accent-rgb),.09)!important;
 border-color:rgba(var(--df-drag-accent-rgb),.50)!important;
 border-style:dashed!important;
 box-shadow:inset 0 0 0 1px rgba(var(--df-drag-accent-rgb),.12)!important;
 filter:saturate(.75)!important;
}
body.df-smart-drag-active .df-layout-card.df-smart-source-hidden>*{
 opacity:.58!important;
}
body.df-smart-drag-active .df-layout-card.df-smart-source-hidden::after{
 content:'IN SPOSTAMENTO';
 position:absolute;
 left:50%;top:50%;
 transform:translate(-50%,-50%);
 z-index:3;
 padding:4px 9px;
 border-radius:999px;
 background:var(--df-drag-accent);
 color:var(--df-drag-on-accent);
 font-size:10px;
 font-weight:900;
 letter-spacing:.035em;
 white-space:nowrap;
 box-shadow:0 2px 8px rgba(var(--df-drag-accent-rgb),.24);
}
.df-smart-drop-overlay{
 border-color:var(--df-drag-accent)!important;
 color:var(--df-drag-accent)!important;
 background:rgba(var(--df-drag-accent-rgb),.16)!important;
 box-shadow:0 4px 16px rgba(var(--df-drag-accent-rgb),.22)!important;
}
.df-smart-drop-overlay>span{
 display:inline-flex;
 align-items:center;
 justify-content:center;
 min-height:24px;
 padding:4px 10px;
 border-radius:999px;
 background:var(--df-drag-accent)!important;
 color:var(--df-drag-on-accent)!important;
 font-weight:950;
 line-height:1;
 box-shadow:0 2px 8px rgba(var(--df-drag-accent-rgb),.22);
}
.df-smart-drop-overlay.is-beside,
.df-smart-drop-overlay.is-slot-field,
.df-smart-drop-overlay.is-empty-slot{
 background:rgba(var(--df-drag-accent-rgb),.22)!important;
 border:2px solid var(--df-drag-accent)!important;
}
.df-smart-drop-overlay.is-line,
.df-smart-drop-overlay.is-newrow,
.df-smart-drop-overlay.is-append{
 background:rgba(var(--df-drag-accent-rgb),.17)!important;
 border:2px dashed var(--df-drag-accent)!important;
}
.df-smart-drop-overlay.is-joinrow{
 background:rgba(var(--df-drag-accent-rgb),.14)!important;
 border:2px solid var(--df-drag-accent)!important;
}
.df-smart-drop-overlay.is-slot-empty{
 background:rgba(var(--df-drag-accent-rgb),.08)!important;
 border:2px dashed rgba(var(--df-drag-accent-rgb),.72)!important;
 color:var(--df-drag-accent)!important;
 opacity:1!important;
}
/* The fixed overlay is the only drop indicator in 1.3.59: remove old black/red shadows. */
body.df-smart-drag-active .df-layout-row.df-smart-line-target-before,
body.df-smart-drag-active .df-layout-row.df-smart-line-target-after,
body.df-smart-drag-active .df-layout-card.df-smart-target-left,
body.df-smart-drag-active .df-layout-card.df-smart-target-right,
body.df-smart-drag-active .df-layout-row-group.df-smart-row-target-before,
body.df-smart-drag-active .df-layout-row-group.df-smart-row-target-after,
body.df-smart-drag-active .df-layout-row-group.df-smart-row-join-target{
 box-shadow:none!important;
 outline:none!important;
}
@media (prefers-reduced-motion:reduce){
 body.df-smart-drag-active .df-layout-card.df-smart-source-hidden::after{transition:none!important}
}
'''
s=s[:style_end]+css+s[style_end:]
p.write_text(s,encoding='utf-8')
PY

# Rebuild children preserving component/plugin separation.
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
  | xargs -0 -r sed -i 's/1\.3\.58/1.3.59/g'

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

test -f "$TMP/outer/com_decaroforms_1.3.59.zip"
test -f "$TMP/outer/plg_system_decaroforms_1.3.59.zip"
test -f "$TMP/outer/plg_editors-xtd_decaroforms_1.3.59.zip"
grep -q 'com_decaroforms_1.3.59.zip' "$MANIFEST"
grep -q 'plg_system_decaroforms_1.3.59.zip' "$MANIFEST"
grep -q 'plg_editors-xtd_decaroforms_1.3.59.zip' "$MANIFEST"
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
grep -q "version:'1.3.59'" "$BUILDER"
grep -q -- '--df-drag-accent:#6f42c1' "$BUILDER"
grep -q 'IN SPOSTAMENTO' "$BUILDER"
grep -q '.df-smart-drop-overlay.is-beside' "$BUILDER"
grep -q 'background:rgba(var(--df-drag-accent-rgb),.22)!important' "$BUILDER"
grep -q 'visibility:visible!important' "$BUILDER"

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
entry=f'''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>{v}</version>\n\t\t<note>Corretto il feedback colore del drag Campi senza modificare la logica stabile della 1.3.58: il campo sorgente resta visibile come placeholder colorato invece di lasciare una riga vuota; SOPRA/SOTTO, SINISTRA/DESTRA e VUOTO 50% hanno ora background viola evidente, bordo coerente e label ad alto contrasto in light/dark mode. Rimossi durante il drag i vecchi shadow/indicatori neri o rossi che si sovrapponevano al nuovo overlay.</note>\n\t</changelog>'''
if f'<version>{v}</version>' not in s:s=s.replace('<changelogs>','<changelogs>'+entry,1)
p.write_text(s,encoding='utf-8')
ET.parse(p)
PY

cat > "$TARGET_DIR/README.md" <<EOF
# Forms 1.3.59

Drag visual feedback fix based on the 2026-09-06 screenshot review:
- source field no longer becomes an empty blank row while dragging; it stays as a translucent violet placeholder with “IN SPOSTAMENTO”;
- SINISTRA / DESTRA 50% targets now have a clearly visible violet background, not text only;
- SOPRA / SOTTO and VUOTO 50% use the same coherent visual language;
- old black/red target shadows are suppressed while the new overlay is active;
- light and dark mode get separate accessible accent values;
- no changes to 1.3.58 magnetic hit testing, intent lock, requestAnimationFrame flow, Row IDs, Sections, visual lines, widths, Undo/Redo or atomic save;
- Joomla child ZIP structure preserved.

SHA256: $SHA
EOF

echo "Forms $NEW built: $TARGET"
echo "SHA256: $SHA"
