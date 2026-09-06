#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.57/pkg_decaroforms_1.3.57.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.57.zip" -d "$TMP/component"
BUILDER="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
test -f "$BUILDER"
python3 - "$BUILDER" > "$ROOT/tools/inspect-1.3.57-field-drag-report.txt" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')

def extract_function(name):
    start=s.find('function '+name+'(')
    if start<0:
        return 'NOT FOUND'
    brace=s.find('{',start)
    if brace<0:return 'NO BRACE'
    depth=0; quote=None; esc=False; template=False
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

for name in [
    'smartProjectedPoint','smartClassifyCard','smartNearestCardInRow',
    'smartNearestEmptySlot','smartNearestCardNearPoint','smartFindDropSpec',
    'smartRenderPreview','smartCreateGhost','smartPositionGhost',
    'smartBeginDrag','smartQueueDrag','smartPointerMove','smartFinishDrag'
]:
    print('\n===== '+name+' =====')
    print(extract_function(name))

for marker in ['const smartDrag=','/* Forms 1.3.57: intent-aware field drag with grab-offset compensation. */']:
    i=s.find(marker)
    print('\n===== '+marker+' =====')
    print(s[i:i+4500] if i>=0 else 'NOT FOUND')
PY
