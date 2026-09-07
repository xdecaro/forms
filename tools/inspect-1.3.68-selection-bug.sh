#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$ROOT/releases/1.3.68/pkg_decaroforms_1.3.68.zip" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.68.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.68-selection-bug-report.txt"
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
            if c in "'\"":quote=c
            elif c=='`':template=True
            elif c=='{':depth+=1
            elif c=='}':
                depth-=1
                if depth==0:return s[start:i+1]
        i+=1
    return 'UNTERMINATED'

for name in ['selectField','selectRowSettings','renderLayoutFieldCard','renderLayoutCanvas','renderSelected']:
    print('\n===== FUNCTION '+name+' =====')
    print(func(name))

for token in ['.df-layout-card.is-active','.df-layout-row-head','.df-layout-section-head','is-selected','is-active','Forms 1.3.68','Forms 1.3.67']:
    print('\n===== TOKEN '+token+' =====')
    hits=list(re.finditer(re.escape(token),s))
    print('COUNT',len(hits))
    for m in hits[-20:]:
        ls=s.rfind('\n',0,max(0,m.start()-700))+1
        le=s.find('\n',min(len(s),m.end()+700)); le=len(s) if le<0 else le
        print(s[ls:le])
PY
