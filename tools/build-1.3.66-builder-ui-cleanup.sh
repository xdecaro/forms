#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
OLD="1.3.65"
NEW="1.3.66"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
JS_TMP="/tmp/forms-1366-builder.js"
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
    | xargs -0 -r sed -i 's/1\.3\.65/1.3.66/g'

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
import re,sys
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8')

# --- 1) Make the edit state explicit and accessible in one authoritative place. ---
old="function applyLockState(){if(!builderRoot)return;builderRoot.classList.toggle('is-locked',editorLocked);document.querySelectorAll('.df-lock-toggle').forEach(b=>b.classList.toggle('is-active',(b.dataset.lock==='1')===editorLocked));document.querySelectorAll('.df-save-top').forEach(b=>b.disabled=editorLocked);builderForm.querySelectorAll('input:not([type=\"hidden\"]),select,textarea,button:not(.df-section-toggle):not(.df-info)').forEach(el=>{if(!el.dataset.lockOriginal)el.dataset.lockOriginal=el.disabled?'1':'0';el.disabled=editorLocked||el.dataset.lockOriginal==='1';});updateHistoryButtons();}"
new="function applyLockState(){if(!builderRoot)return;builderRoot.classList.toggle('is-locked',editorLocked);builderRoot.dataset.editorMode=editorLocked?'locked':'edit';document.querySelectorAll('.df-lock-toggle').forEach(b=>{const active=(b.dataset.lock==='1')===editorLocked;b.classList.toggle('is-active',active);b.setAttribute('aria-pressed',active?'true':'false');});document.querySelectorAll('.df-save-top').forEach(b=>b.disabled=editorLocked);builderForm.querySelectorAll('input:not([type=\"hidden\"]),select,textarea,button:not(.df-section-toggle):not(.df-info)').forEach(el=>{if(!el.dataset.lockOriginal)el.dataset.lockOriginal=el.disabled?'1':'0';el.disabled=editorLocked||el.dataset.lockOriginal==='1';});updateHistoryButtons();}"
if old not in s: raise SystemExit('applyLockState anchor not found')
s=s.replace(old,new,1)

# --- 2) Clean only the conflicting toolbar-mode CSS, not the approved Builder/drag UI. ---
# We remove qualified CSS rules whose selectors mention df-lock-toggle or the old broad
# theme override for every non-save toolbar button. Nested @media blocks are preserved.
style_match=re.search(r'<style>(.*?)</style>',s,re.S|re.I)
if not style_match: raise SystemExit('style block missing')
css=style_match.group(1)

# Lightweight recursive CSS cleaner: preserves comments/at-rules, removes selected qualified rules.
def find_matching(text,start,open_ch='{',close_ch='}'):
    depth=0;quote=None;esc=False;i=start
    while i<len(text):
        c=text[i]
        if quote:
            if esc: esc=False
            elif c=='\\': esc=True
            elif c==quote: quote=None
        else:
            if c in "'\"": quote=c
            elif c==open_ch: depth+=1
            elif c==close_ch:
                depth-=1
                if depth==0:return i
        i+=1
    return -1

def should_remove_selector(sel):
    q=' '.join(sel.split())
    if '.df-lock-toggle' in q:
        return True
    if '.df-editor-toolbar button:not(.df-save-top)' in q:
        return True
    return False

def clean_block(text):
    out=[];i=0;n=len(text)
    while i<n:
        # comments
        if text.startswith('/*',i):
            j=text.find('*/',i+2)
            if j<0: out.append(text[i:]);break
            out.append(text[i:j+2]);i=j+2;continue
        # whitespace / semicolon text outside rules
        if text[i].isspace():out.append(text[i]);i+=1;continue
        # read prelude to next top-level { or ;
        j=i;quote=None;esc=False
        while j<n:
            c=text[j]
            if quote:
                if esc:esc=False
                elif c=='\\':esc=True
                elif c==quote:quote=None
            else:
                if c in "'\"":quote=c
                elif c in '{;':break
            j+=1
        if j>=n:
            out.append(text[i:]);break
        pre=text[i:j]
        if text[j]==';':
            out.append(text[i:j+1]);i=j+1;continue
        end=find_matching(text,j)
        if end<0: raise SystemExit('unbalanced CSS block near '+pre[:80])
        body=text[j+1:end]
        stripped=pre.strip()
        if stripped.startswith('@'):
            # recurse for @media/@supports; preserve declarations-only at-rules as-is.
            if stripped.lower().startswith(('@media','@supports','@layer','@container')):
                out.append(pre+'{'+clean_block(body)+'}')
            else:
                out.append(pre+'{'+body+'}')
        else:
            if not should_remove_selector(pre):
                out.append(pre+'{'+body+'}')
        i=end+1
    return ''.join(out)

before_lock=css.count('.df-lock-toggle')
css=clean_block(css)
after_lock=css.count('.df-lock-toggle')

canonical=r'''

/* Forms 1.3.66: canonical Builder toolbar/edit-mode CSS after conflict cleanup. */
.df-builder .df-editor-toolbar .df-lock-toggle{
  min-height:34px;
  padding:6px 14px;
  border:1px solid var(--df-border,#d9dee5);
  background:var(--bs-body-bg,#fff);
  color:var(--bs-body-color,#1f2937);
  font-weight:800;
  cursor:pointer;
  transition:background-color .14s ease,border-color .14s ease,color .14s ease,box-shadow .14s ease;
}
.df-builder .df-editor-toolbar .df-lock-toggle .df-ui-icon{margin-right:6px;color:currentColor}
.df-builder .df-editor-toolbar .df-lock-toggle:not(.is-active):hover,
.df-builder .df-editor-toolbar .df-lock-toggle:not(.is-active):focus-visible{
  background:var(--bs-secondary-bg,#f3f4f6);
  border-color:color-mix(in srgb,var(--df-border,#d9dee5) 65%,var(--bs-body-color,#1f2937));
}
.df-builder[data-editor-mode="edit"] .df-editor-toolbar .df-lock-toggle[data-lock="0"]{
  background:#7c3aed!important;
  border-color:#7c3aed!important;
  color:#fff!important;
  box-shadow:inset 0 0 0 1px rgba(255,255,255,.16)!important;
}
.df-builder[data-editor-mode="locked"] .df-editor-toolbar .df-lock-toggle[data-lock="1"]{
  background:#475569!important;
  border-color:#475569!important;
  color:#fff!important;
  box-shadow:inset 0 0 0 1px rgba(255,255,255,.10)!important;
}
.df-builder[data-editor-mode="edit"] .df-editor-toolbar .df-lock-toggle[data-lock="1"],
.df-builder[data-editor-mode="locked"] .df-editor-toolbar .df-lock-toggle[data-lock="0"]{
  background:var(--bs-body-bg,#fff)!important;
  border-color:var(--df-border,#d9dee5)!important;
  color:var(--bs-body-color,#1f2937)!important;
  box-shadow:none!important;
}
:where(html[data-bs-theme="dark"],body[data-bs-theme="dark"],html[data-color-scheme="dark"]) .df-builder .df-editor-toolbar .df-lock-toggle{
  background:#111827;
  border-color:#475569;
  color:#f8fafc;
}
:where(html[data-bs-theme="dark"],body[data-bs-theme="dark"],html[data-color-scheme="dark"]) .df-builder[data-editor-mode="edit"] .df-editor-toolbar .df-lock-toggle[data-lock="1"],
:where(html[data-bs-theme="dark"],body[data-bs-theme="dark"],html[data-color-scheme="dark"]) .df-builder[data-editor-mode="locked"] .df-editor-toolbar .df-lock-toggle[data-lock="0"]{
  background:#111827!important;
  border-color:#475569!important;
  color:#f8fafc!important;
}
:where(html[data-bs-theme="dark"],body[data-bs-theme="dark"],html[data-color-scheme="dark"]) .df-builder[data-editor-mode="edit"] .df-editor-toolbar .df-lock-toggle[data-lock="0"]{
  background:#8b5cf6!important;
  border-color:#8b5cf6!important;
  color:#fff!important;
}

/* One definitive rhythm for Sezione, Riga and Campo. */
.df-builder .df-layout-section-head,
.df-builder .df-layout-row-head,
.df-builder .df-layout-card{min-height:59px!important}
'''
css=css.rstrip()+canonical+'\n'

# ensure top-level balance after cleanup
bal=0;quote=None;esc=False
for c in css:
    if quote:
        if esc:esc=False
        elif c=='\\':esc=True
        elif c==quote:quote=None
    else:
        if c in "'\"":quote=c
        elif c=='{':bal+=1
        elif c=='}':bal-=1
        if bal<0:raise SystemExit('negative CSS brace balance')
if bal!=0:raise SystemExit('CSS brace imbalance '+str(bal))

s=s[:style_match.start(1)]+css+s[style_match.end(1):]
p.write_text(s,encoding='utf-8')
print(f'lock selector cleanup: {before_lock} -> {after_lock + canonical.count(".df-lock-toggle")}')
PY

# Regression guard: all approved drag functions remain byte-identical to 1.3.65.
python3 - "$TMP/builder-before.php" "$BUILDER" <<'PY'
from pathlib import Path
import sys
before=Path(sys.argv[1]).read_text(encoding='utf-8');after=Path(sys.argv[2]).read_text(encoding='utf-8')
def func(s,name):
    start=s.find('function '+name+'(')
    if start<0:raise SystemExit('missing '+name)
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
    if func(before,name)!=func(after,name):raise SystemExit('drag regression: '+name)
print('drag engines unchanged')
PY

# Rebuild children and validate PHP/XML.
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
  | xargs -0 -r sed -i 's/1\.3\.65/1.3.66/g'

MANIFEST="$TMP/outer/pkg_decaroforms.xml"
python3 - "$MANIFEST" "$NEW" <<'PY'
from pathlib import Path
import re,sys,xml.etree.ElementTree as ET
p=Path(sys.argv[1]);v=sys.argv[2];s=p.read_text(encoding='utf-8');s=re.sub(r'<version>[^<]+</version>',f'<version>{v}</version>',s,count=1);p.write_text(s,encoding='utf-8');ET.parse(p)
PY

test -f "$TMP/outer/com_decaroforms_1.3.66.zip"
test -f "$TMP/outer/plg_system_decaroforms_1.3.66.zip"
test -f "$TMP/outer/plg_editors-xtd_decaroforms_1.3.66.zip"
grep -q 'com_decaroforms_1.3.66.zip' "$MANIFEST"
grep -q 'plg_system_decaroforms_1.3.66.zip' "$MANIFEST"
grep -q 'plg_editors-xtd_decaroforms_1.3.66.zip' "$MANIFEST"
for C in "$TMP/outer"/*.zip; do unzip -t "$C" >/dev/null; done

php -l "$BUILDER" >/dev/null
python3 - "$BUILDER" "$JS_TMP" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
js='\n'.join(m.group(1) for m in re.finditer(r'<script(?:\s[^>]*)?>(.*?)</script>',s,re.S|re.I));js=re.sub(r'<\?(?:php|=).*?\?>','null',js,flags=re.S|re.I);Path(sys.argv[2]).write_text(js,encoding='utf-8')
PY
node --check "$JS_TMP"

# UI cleanup assertions.
grep -q "version:'1.3.66'" "$BUILDER"
grep -q "builderRoot.dataset.editorMode=editorLocked?'locked':'edit'" "$BUILDER"
grep -q "aria-pressed" "$BUILDER"
grep -q 'data-editor-mode="edit"' "$BUILDER"
grep -q 'data-editor-mode="locked"' "$BUILDER"
grep -q 'min-height:59px!important' "$BUILDER"
python3 - "$BUILDER" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8');css=re.search(r'<style>(.*?)</style>',s,re.S|re.I).group(1)
count=css.count('.df-lock-toggle')
print('final df-lock-toggle references:',count)
if count>16:raise SystemExit('toolbar cleanup incomplete: too many lock selectors')
if '.df-editor-toolbar button:not(.df-save-top)' in css:raise SystemExit('legacy broad toolbar override still present')
# CSS brace balance
bal=0;quote=None;esc=False
for c in css:
    if quote:
        if esc:esc=False
        elif c=='\\':esc=True
        elif c==quote:quote=None
    else:
        if c in "'\"":quote=c
        elif c=='{':bal+=1
        elif c=='}':bal-=1
if bal!=0:raise SystemExit('CSS brace imbalance')
PY

(cd "$TMP/outer" && zip -qr "$TARGET" .)
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
p=Path(sys.argv[1]);v=sys.argv[2];s=p.read_text(encoding='utf-8')
entry=f'''\n\t<changelog>\n\t\t<element>pkg_decaroforms</element>\n\t\t<type>package</type>\n\t\t<version>{v}</version>\n\t\t<note>Pulizia Builder UI: rimossi i selettori CSS duplicati e conflittuali della toolbar Bloccato/Modifica, incluso il vecchio override light-mode ad alta specificita che annullava il background attivo. Stato editor ora esposto da data-editor-mode e aria-pressed; Modifica attivo viola pieno, Bloccato attivo grigio pieno, inattivo neutro, dark mode coerente. Sezione, Riga e Campo restano uniformi a 59px. Motori drag e logica dati invariati.</note>\n\t</changelog>'''
if f'<version>{v}</version>' not in s:s=s.replace('<changelogs>','<changelogs>'+entry,1)
p.write_text(s,encoding='utf-8');ET.parse(p)
PY

cat > "$TARGET_DIR/README.md" <<EOF
# Forms 1.3.66

Builder UI cleanup release:
- removed duplicated/conflicting lock-toggle CSS accumulated across earlier revisions;
- removed the broad high-specificity light/dark toolbar button override that was winning over the active-state color;
- editor mode now has one authoritative \`data-editor-mode\` state plus \`aria-pressed\` on the two mode buttons;
- active **Modifica** = solid purple with white text;
- active **Bloccato** = solid slate with white text;
- inactive mode remains neutral; dark mode has explicit neutral/active treatment;
- Section, Row and Field remain uniformly **59px**;
- approved Field/Row/Section drag engines are byte-regression-checked and unchanged;
- Row IDs, stable labels, visual lines, 50/50 slots, widths, Undo/Redo and atomic save are unchanged.

SHA256: $SHA
EOF

echo "Forms $NEW built: $TARGET"
echo "SHA256: $SHA"
