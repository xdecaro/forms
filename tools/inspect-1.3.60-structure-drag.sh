#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.60/pkg_decaroforms_1.3.60.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.60.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
test -f "$B"
python3 - "$B" > "$ROOT/tools/inspect-1.3.60-structure-drag-report.txt" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')

def extract(name):
    start=s.find('function '+name+'(')
    if start<0:return 'NOT FOUND'
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
    return s[start:start+12000]

for name in ['structureClearTargets','structureSpecKey','structureRenderTarget','structureGhost','structurePositionGhost','structureRowDropSpec','structureFindTarget','structureBegin','structureQueue','structurePointerMove','structureFinish','structureMoveSection','structureMoveRow']:
    print('\n===== '+name+' =====')
    print(extract(name))

for marker in ['body.df-structure-drag-active .df-layout-section-group','is-section-drop-before','is-row-drop-before','.df-structure-drag-ghost','Forms 1.3.60: field card vertical breathing room']:
    i=s.find(marker)
    print('\n===== '+marker+' =====')
    print(s[max(0,i-1200):min(len(s),i+9000)] if i>=0 else 'NOT FOUND')
PY
