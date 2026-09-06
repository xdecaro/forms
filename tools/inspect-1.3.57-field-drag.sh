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
needles=[
 'const smartDrag=',
 'function smartBeginDrag(){',
 'function smartClassifyCard(card,x,y){',
 'function smartNearestCardInRow(',
 'function smartFindDropSpec(x,y){',
 'function smartRenderPreview(',
 'function smartPointerMove(',
 'function smartPointerUp(',
 'function smartCleanup(',
 '.df-smart-drag-ghost',
 '.df-smart-line-preview',
 'body.df-smart-drag-active'
]
for needle in needles:
    i=s.find(needle)
    print('\n\n===== '+needle+' =====')
    if i<0:
        print('NOT FOUND'); continue
    print(s[max(0,i-800):min(len(s),i+7000)])
PY
