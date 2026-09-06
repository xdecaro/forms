#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.62"
NEW="1.3.63"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
JS_TMP="/tmp/forms-1363-builder.js"
HASH_BEFORE="/tmp/forms-1363-drag-before.txt"
HASH_AFTER="/tmp/forms-1363-drag-after.txt"
trap 'rm -rf "$TMP" "$JS_TMP" "$HASH_BEFORE" "$HASH_AFTER"' EXIT
mkdir -p "$TMP/outer" "$TMP/children" "$TARGET_DIR"
test -f "$BASE"
unzip -q "$BASE" -d "$TMP/outer"
unzip -t "$BASE" >/dev/null
MAP="$TMP/children-map.tsv"; : > "$MAP"
idx=0; BUILDER=""
for ZIP in "$TMP/outer"/*.zip; do
  [ -e "$ZIP" ] || continue
  idx=$((idx+1)); NAME="$(basename "$ZIP")"; NEWNAME="${NAME//$OLD/$NEW}"; CHILD="$TMP/children/$idx"
  mkdir -p "$CHILD"; unzip -q "$ZIP" -d "$CHILD"; printf '%s\t%s\n' "$idx" "$NEWNAME" >> "$MAP"
  CANDIDATE="$CHILD/administrator/components/com_decaroforms/tmpl/builder/default.php"
  if [ -f "$CANDIDATE" ]; then BUILDER="$CANDIDATE"; fi
done
test -n "$BUILDER" && test -f "$BUILDER"

# Hash approved drag engines before any patch. 1.3.63 must not change drag behavior.
python3 - "$BUILDER" > "$HASH_BEFORE" <<'PY'
from pathlib import Path
import sys,hashlib
s=Path(sys.argv[1]).read_text(encoding='utf-8')
def f(name):
 st=s.find('function '+name+'(')
 if st<0: raise SystemExit('missing '+name)
 br=s.find('{',st); d=0;q=None;esc=False;templ=False;i=br
 while i<len(s):
  c=s[i]
  if q:
   if esc:esc=False
   elif c=='\\':esc=True
   elif c==q:q=None
  elif templ:
   if esc:esc=False
   elif c=='\\':esc=True
   elif c=='`':templ=False
  else:
   if c in "'\"":q=c
   elif c=='`':templ=True
   elif c=='{':d+=1
   elif c=='}':
    d-=1
    if d==0:return s[st:i+1]
  i+=1
 raise SystemExit('unterminated '+name)
for n in ['smartQueueDrag','smartBeginDrag','smartPointerMove','smartFindDropSpec','smartRenderPreview','smartFinishDrag','structureQueue','structurePointerMove','structureFindTarget','structureRenderTarget','structureFinish']:
 print(n,hashlib.sha256(f(n).encode()).hexdigest())
PY

# Version all child text files first.
for CHILD in "$TMP/children"/*; do
  find "$CHILD" -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.js' -o -name '*.json' -o -name '*.css' -o -name '*.txt' -o -name '*.md' \) -print0 | xargs -0 -r sed -i 's/1\.3\.62/1.3.63/g'
  while IFS= read -r -d '' XML; do
    if grep -q '<extension' "$XML" && grep -q '<version>' "$XML"; then
      python3 - "$XML" "$NEW" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]);v=sys.argv[2];s=p.read_text(encoding='utf-8')
s=re.sub(r'<version>[^<]+</version>',f'<version>{v}</version>',s,count=1);p.write_text(s,encoding='utf-8')
PY
    fi
  done < <(find "$CHILD" -maxdepth 1 -type f -name '*.xml' -print0)
done

# UI-only patch: active selection, lock-mode visibility, and approved larger row heights.
python3 - "$BUILDER" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8')
old="const wrap=document.createElement('div');wrap.className='df-layout-section-group'+(group.id==='general'?' is-general':' is-section')+(sectionOpen?' is-open':'');wrap.dataset.sectionId=group.id;"
new="const sectionSelected=group.id!=='general'&&group.sectionField?.[0]?.key===activeFieldKey;const wrap=document.createElement('div');wrap.className='df-layout-section-group'+(group.id==='general'?' is-general':' is-section')+(sectionOpen?' is-open':'')+(sectionSelected?' is-selected':'');wrap.dataset.sectionId=group.id;"
if old not in s: raise SystemExit('1.3.63 section wrapper anchor missing')
s=s.replace(old,new,1)
style_end=s.rfind('</style>')
if style_end<0: raise SystemExit('1.3.63 style end missing')
css=r'''

/* Forms 1.3.63: uniform active selection, explicit lock mode, roomier structure rows. */
.df-layout-section-group.is-selected > .df-layout-section-head,
.df-layout-row-group.is-selected > .df-layout-row-head,
.df-layout-card.is-active{
 background:color-mix(in srgb,#7c3aed 8%,var(--bs-body-bg,#fff))!important;
 box-shadow:inset 4px 0 0 #7c3aed!important;
 border-color:color-mix(in srgb,#7c3aed 24%,var(--df-border,#d8dee8))!important;
}
.df-layout-section-group.is-selected > .df-layout-section-head strong,
.df-layout-row-group.is-selected > .df-layout-row-head .df-layout-row-label,
.df-layout-card.is-active > strong{color:var(--bs-body-color,#202733)!important}

/* The active edit mode must be immediately visible. Red remains reserved for destructive actions. */
.df-lock-toggle{
 transition:background-color .14s ease,border-color .14s ease,color .14s ease,box-shadow .14s ease;
}
.df-lock-toggle[data-lock="1"].is-active{
 background:#4b5563!important;
 border-color:#4b5563!important;
 color:#fff!important;
 box-shadow:0 0 0 2px color-mix(in srgb,#4b5563 20%,transparent)!important;
}
.df-lock-toggle[data-lock="0"].is-active{
 background:#7c3aed!important;
 border-color:#7c3aed!important;
 color:#fff!important;
 box-shadow:0 0 0 2px color-mix(in srgb,#7c3aed 22%,transparent)!important;
}
.df-lock-toggle:not(.is-active){
 background:var(--bs-body-bg,#fff)!important;
 color:var(--bs-body-color,#202733)!important;
}

/* Final approved vertical rhythm: more room for labels, badges, actions and magnetic halves. */
.df-layout-section-head{min-height:72px!important;box-sizing:border-box;align-items:center!important}
.df-layout-row-head{min-height:68px!important;box-sizing:border-box;align-items:center!important}
.df-layout-card{min-height:72px!important;box-sizing:border-box;padding-top:11px!important;padding-bottom:11px!important;align-items:center!important}

[data-bs-theme="dark"] .df-layout-section-group.is-selected > .df-layout-section-head,
[data-bs-theme="dark"] .df-layout-row-group.is-selected > .df-layout-row-head,
[data-bs-theme="dark"] .df-layout-card.is-active,
.dark .df-layout-section-group.is-selected > .df-layout-section-head,
.dark .df-layout-row-group.is-selected > .df-layout-row-head,
.dark .df-layout-card.is-active{
 background:color-mix(in srgb,#8b5cf6 15%,var(--bs-body-bg,#111827))!important;
 border-color:color-mix(in srgb,#8b5cf6 38%,var(--df-border,#374151))!important;
 box-shadow:inset 4px 0 0 #8b5cf6!important;
}
[data-bs-theme="dark"] .df-lock-toggle:not(.is-active),.dark .df-lock-toggle:not(.is-active){
 background:var(--bs-body-bg,#111827)!important;
 color:var(--bs-body-color,#e5e7eb)!important;
 border-color:var(--bs-border-color,#374151)!important;
}
[data-bs-theme="dark"] .df-lock-toggle[data-lock="1"].is-active,.dark .df-lock-toggle[data-lock="1"].is-active{background:#475569!important;border-color:#64748b!important;color:#fff!important}
[data-bs-theme="dark"] .df-lock-toggle[data-lock="0"].is-active,.dark .df-lock-toggle[data-lock="0"].is-active{background:#8b5cf6!important;border-color:#a78bfa!important;color:#fff!important}

@media(max-width:900px){
 .df-layout-section-head,.df-layout-row-head,.df-layout-card{min-height:68px!important}
 .df-layout-card{padding-top:10px!important;padding-bottom:10px!important}
}
@media(max-width:640px){
 .df-layout-section-head,.df-layout-row-head,.df-layout-card{min-height:64px!important}
 .df-layout-card{padding-top:9px!important;padding-bottom:9px!important}
}
'''
s=s[:style_end]+css+s[style_end:]
p.write_text(s,encoding='utf-8')
PY

# Re-hash drag engines after patch (normalize version string only; behavior must be byte-equivalent).
python3 - "$BUILDER" > "$HASH_AFTER" <<'PY'
from pathlib import Path
import sys,hashlib,re
s=Path(sys.argv[1]).read_text(encoding='utf-8').replace('1.3.63','1.3.62')
def f(name):
 st=s.find('function '+name+'(')
 if st<0: raise SystemExit('missing '+name)
 br=s.find('{',st); d=0;q=None;esc=False;templ=False;i=br
 while i<len(s):
  c=s[i]
  if q:
   if esc:esc=False
   elif c=='\\':esc=True
   elif c==q:q=None
  elif templ:
   if esc:esc=False
   elif c=='\\':esc=True
   elif c=='`':templ=False
  else:
   if c in "'\"":q=c
   elif c=='`':templ=True
   elif c=='{':d+=1
   elif c=='}':
    d-=1
    if d==0:return s[st:i+1]
  i+=1
 raise SystemExit('unterminated '+name)
for n in ['smartQueueDrag','smartBeginDrag','smartPointerMove','smartFindDropSpec','smartRenderPreview','smartFinishDrag','structureQueue','structurePointerMove','structureFindTarget','structureRenderTarget','structureFinish']:
 print(n,hashlib.sha256(f(n).encode()).hexdigest())
PY
cmp "$HASH_BEFORE" "$HASH_AFTER"

# Validate component before rebuilding children.
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
grep -q "version:'1.3.63'" "$BUILDER"
grep -q "sectionSelected?' is-selected'" "$BUILDER"
grep -q 'df-lock-toggle\[data-lock="1"\].is-active' "$BUILDER"
grep -q 'df-lock-toggle\[data-lock="0"\].is-active' "$BUILDER"
grep -q 'min-height:72px!important' "$BUILDER"
grep -q 'min-height:68px!important' "$BUILDER"
grep -q 'min-height:64px!important' "$BUILDER"

# Rebuild child ZIPs.
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

# Update outer manifest and validate required children.
find "$TMP/outer" -maxdepth 2 -type f \( -name '*.xml' -o -name '*.php' -o -name '*.ini' -o -name '*.json' -o -name '*.txt' -o -name '*.md' \) -print0 | xargs -0 -r sed -i 's/1\.3\.62/1.3.63/g'
MANIFEST="$TMP/outer/pkg_decaroforms.xml"
python3 - "$MANIFEST" "$NEW" <<'PY'
from pathlib import Path
import re,sys,xml.etree.ElementTree as ET
p=Path(sys.argv[1]);v=sys.argv[2];s=p.read_text(encoding='utf-8');s=re.sub(r'<version>[^<]+</version>',f'<version>{v}</version>',s,count=1);p.write_text(s,encoding='utf-8');ET.parse(p)
PY
test -f "$TMP/outer/com_decaroforms_1.3.63.zip"
test -f "$TMP/outer/plg_system_decaroforms_1.3.63.zip"
test -f "$TMP/outer/plg_editors-xtd_decaroforms_1.3.63.zip"
grep -q 'com_decaroforms_1.3.63.zip' "$MANIFEST"
grep -q 'plg_system_decaroforms_1.3.63.zip' "$MANIFEST"
grep -q 'plg_editors-xtd_decaroforms_1.3.63.zip' "$MANIFEST"
for C in "$TMP/outer"/*.zip; do unzip -t "$C" >/dev/null; done

(cd "$TMP/outer" && zip -qr "$TARGET" .)
unzip -t "$TARGET" >/dev/null
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

# Feed and changelog.
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
entry=f'''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>{v}</version>\n\t\t<note>Builder UI refinement: stato attivo uniforme per Sezione/Riga/Campo con background viola leggero e barra sinistra; Bloccato/Modifica hanno background attivo evidente (grigio vs viola); altezze finali aumentate per Sezione/Riga/Campo (desktop 72/68/72px, tablet 68px, smartphone 64px). Light/dark mode uniformi. Motori drag Campo e Riga/Sezione preservati senza modifiche, inclusi magnetismo, SOPRA/SOTTO, SINISTRA/DESTRA 50% solo Campi, VUOTO 50%, Row ID, Undo/Redo e salvataggio atomico.</note>\n\t</changelog>'''
if f'<version>{v}</version>' not in s:s=s.replace('<changelogs>','<changelogs>'+entry,1)
p.write_text(s,encoding='utf-8');ET.parse(p)
PY
cat > "$TARGET_DIR/README.md" <<EOF
# Forms 1.3.63

Builder visual-state and spacing refinement:
- selected **Section**, **Row** and **Field** now share the same subtle violet background and left accent bar;
- only the currently edited element is highlighted; field selection continues to clear structural selection;
- **Bloccato** active state uses a clear dark-gray background; **Modifica** active state uses violet; inactive mode stays neutral;
- red remains reserved for destructive actions;
- final desktop heights: Section **72px**, Row **68px**, Field **72px**;
- tablet: **68px**; smartphone: **64px**;
- light and dark mode receive explicit active-state contrast;
- approved 1.3.60 Field drag and 1.3.61/1.3.62 Row/Section drag engines are byte-preserved (apart from version text), with no behavior changes;
- Row IDs, stable labels, visual lines, VUOTO 50%, widths, Undo/Redo and atomic save remain unchanged.

SHA256: $SHA
EOF

echo "Forms $NEW built: $TARGET"
echo "SHA256: $SHA"
