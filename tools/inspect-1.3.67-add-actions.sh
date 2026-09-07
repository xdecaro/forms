#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$ROOT/releases/1.3.67/pkg_decaroforms_1.3.67.zip" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.67.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.67-add-actions-report.txt"
python3 - "$B" > "$OUT" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')

def func(name):
    start=s.find('function '+name+'(')
    if start<0:return 'NOT FOUND'
    brace=s.find('{',start); depth=0; quote=None; esc=False; template=False; i=brace
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
            if c in "'\"": quote=c
            elif c=='`': template=True
            elif c=='{': depth+=1
            elif c=='}':
                depth-=1
                if depth==0:return s[start:i+1]
        i+=1
    return 'UNTERMINATED'

for name in ['isLayoutSectionField','renderLibrary','renderFieldLibrary','addLibraryField','createField','makeField','selectField','selectRowSettings','layoutGroups','structureRowBlocks','structureApplyBlocks','smartShiftRowMeta']:
    print('\n===== FUNCTION '+name+' =====\n'+func(name).replace(';',';\n'))

for token in ['library.addEventListener','library.onclick','df-library','selected.push(','selected.splice(','type:\'section\'','type:"section"','layout_section','structure_section','category:\'structure\'','category:"structure"']:
    print('\n===== TOKEN '+token+' =====')
    pos=0
    for n in range(12):
        i=s.find(token,pos)
        if i<0:break
        print('\n---',n+1,'---')
        print(s[max(0,i-1200):min(len(s),i+2200)].replace(';',';\n'))
        pos=i+len(token)
PY
