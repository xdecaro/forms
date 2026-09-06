#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.54/pkg_decaroforms_1.3.54.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$BASE" -d "$TMP/outer"
COMP="$(find "$TMP/outer" -maxdepth 1 -type f -name 'com_decaroforms_1.3.54.zip' -print -quit)"
test -n "$COMP" && test -f "$COMP"
unzip -q "$COMP" -d "$TMP/component"
SRC="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
test -f "$SRC"
python3 - "$SRC" "$ROOT/tools/audit-1.3.54-field-drag-zones-report.txt" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text(encoding='utf-8')
out=[]
patterns=[
    'smartPointerMove',
    'smartMoveToSlot',
    'df-smart-slot-preview',
    'df-smart-line-preview',
    'df-smart-row-join-preview',
    'elementsFromPoint',
    'getBoundingClientRect()',
    'smartQueue',
    'pointermove',
    'offset_before',
]
for pat in patterns:
    start=0; hits=0
    while True:
        i=src.find(pat,start)
        if i<0: break
        hits+=1
        a=max(0,i-2200); b=min(len(src),i+5200)
        out.append(f'\n===== {pat} hit {hits} @ {i} =====\n'+src[a:b])
        start=i+len(pat)
        if hits>=8: break
Path(sys.argv[2]).write_text('\n'.join(out),encoding='utf-8')
PY
