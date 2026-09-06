#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
for V in 1.3.60 1.3.61; do
  mkdir -p "$TMP/$V/outer" "$TMP/$V/component"
  unzip -q "$ROOT/releases/$V/pkg_decaroforms_$V.zip" -d "$TMP/$V/outer"
  unzip -q "$TMP/$V/outer/com_decaroforms_$V.zip" -d "$TMP/$V/component"
done
B60="$TMP/1.3.60/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
B61="$TMP/1.3.61/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.61-field-drag-start-report.txt"
python3 - "$B60" "$B61" > "$OUT" <<'PY'
from pathlib import Path
import sys,re,difflib
p60,p61=map(Path,sys.argv[1:])
s60=p60.read_text(encoding='utf-8'); s61=p61.read_text(encoding='utf-8')

def extract_func(s,name):
    start=s.find('function '+name+'(')
    if start<0:return 'NOT FOUND'
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
    return s[start:start+12000]

names=['smartQueueDrag','smartPointerMove','smartBeginDrag','smartCancelPending','smartFinishDrag','smartEndVisual','structureQueue','structurePointerMove']
for name in names:
    print('\n===== 1.3.60 '+name+' =====')
    print(extract_func(s60,name))
    print('\n===== 1.3.61 '+name+' =====')
    print(extract_func(s61,name))

for label,s in [('1.3.60',s60),('1.3.61',s61)]:
    print('\n===== '+label+' smartDragIgnoreSelector DEFINITION =====')
    m=re.search(r"(?:const|let|var)\s+smartDragIgnoreSelector\s*=\s*[^;]+;",s)
    print(m.group(0) if m else 'NOT FOUND')
    print('\n===== '+label+' editorLocked REFERENCES =====')
    for m in list(re.finditer(r'editorLocked',s))[:12]:
        print(s[max(0,m.start()-300):min(len(s),m.start()+500)])
    print('\n===== '+label+' FIELD POINTERDOWN WIRING =====')
    needle="card.addEventListener('pointerdown',e=>smartQueueDrag(e,card,f.key));"
    i=s.find(needle)
    print(s[max(0,i-1200):min(len(s),i+1200)] if i>=0 else 'NOT FOUND')
    print('\n===== '+label+' DOCUMENT POINTER EVENTS =====')
    for needle in ["document.addEventListener('pointermove'","document.addEventListener('pointerup'","document.addEventListener('pointercancel'"]:
        i=s.find(needle)
        print(s[max(0,i-800):min(len(s),i+1800)] if i>=0 else needle+' NOT FOUND')

# List selector classes in ignore selector if available.
for label,s in [('1.3.60',s60),('1.3.61',s61)]:
    m=re.search(r"(?:const|let|var)\s+smartDragIgnoreSelector\s*=\s*(['\"])(.*?)\1\s*;",s,re.S)
    print('\n===== '+label+' IGNORE SELECTOR TOKENS =====')
    print(m.group(2) if m else 'NOT FOUND')

# Focused unified diff all changed lines touching field/structure event wiring.
l60=s60.splitlines(); l61=s61.splitlines()
print('\n===== FILTERED DIFF 1.3.60 -> 1.3.61 =====')
for line in difflib.unified_diff(l60,l61,fromfile='1.3.60',tofile='1.3.61',n=2):
    if any(k in line for k in ['smartQueueDrag','smartPointerMove','smartBeginDrag','pointerdown','pointermove','pointerup','structureQueue','structurePointerMove','df-layout-handle','df-layout-card','smartDragIgnoreSelector','editorLocked']):
        print(line)
PY
