#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
ZIP="$ROOT/releases/1.3.46/pkg_decaroforms_1.3.46.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$ZIP" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.46.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.46-smart-slots.txt"
python3 - "$B" "$OUT" <<'PY'
from pathlib import Path
import sys,re
s=Path(sys.argv[1]).read_text(encoding='utf-8')
out=[]
patterns=[
"function visualLinesForItems",
"function normalizeVisualLines",
"function smartFitRow",
"function smartClassifyCard",
"function smartFindDropSpec",
"function smartRenderPreview",
"function smartMoveBeside",
"function smartMoveLineRelative",
"function smartMoveToExistingRow",
"function smartMoveNewRow",
"function smartCommitSpec",
"function setFieldWidth",
"function setLogicalFieldWidth",
"function smartSourcePlaceholder",
"function smartRestorePreviewDom",
"df-smart-row-join-preview",
"df-smart-line"
]
for pat in patterns:
    out.append(f"\n===== {pat} =====\n")
    for m in list(re.finditer(re.escape(pat),s))[:8]:
        a=max(0,m.start()-1200); b=min(len(s),m.end()+4500)
        out.append(s[a:b].replace('\n',' ')+'\n---\n')
Path(sys.argv[2]).write_text(''.join(out),encoding='utf-8')
PY
