#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.53/pkg_decaroforms_1.3.53.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$BASE" -d "$TMP/outer"
COMP="$(find "$TMP/outer" -maxdepth 1 -type f -name 'com_decaroforms_1.3.53.zip' -print -quit)"
test -n "$COMP" && test -f "$COMP"
unzip -q "$COMP" -d "$TMP/component"
SRC="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
test -f "$SRC"
python3 - "$SRC" "$ROOT/tools/audit-1.3.53-row-label-report.txt" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text(encoding='utf-8')
out=[]
patterns=[
    'function rowMeta(',
    'function rowIdForRow(',
    'function normalizeLayoutRows(',
    'df-layout-row-label',
    'meta.title',
    'data-row-title',
    'row_title',
    'Impostazioni riga',
    'duplicateLayoutRow(',
    'requestRemoveLayoutRow(',
    'function renderLayoutCanvas(',
]
for pat in patterns:
    start=0; hits=0
    while True:
        i=src.find(pat,start)
        if i<0: break
        hits+=1
        a=max(0,i-1200); b=min(len(src),i+2600)
        out.append(f'\n===== {pat} hit {hits} @ {i} =====\n'+src[a:b])
        start=i+len(pat)
        if hits>=5: break
Path(sys.argv[2]).write_text('\n'.join(out),encoding='utf-8')
PY
