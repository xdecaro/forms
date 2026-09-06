#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
ZIP="$ROOT/releases/1.3.43/pkg_decaroforms_1.3.43.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$ZIP" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.43.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.43-structure-pending.txt"
python3 - "$B" "$OUT" <<'PY'
from pathlib import Path
import sys,re
s=Path(sys.argv[1]).read_text(encoding='utf-8')
out=[]

def grab(start, ends, label, maxlen=20000):
    a=s.find(start)
    out.append(f"\n===== {label} =====\n")
    if a<0:
        out.append('MISSING\n'); return
    candidates=[s.find(e,a+len(start)) for e in ends]
    candidates=[x for x in candidates if x>=0]
    b=min(candidates) if candidates else min(len(s),a+maxlen)
    out.append(s[a:b][:maxlen]+'\n')

grab('function layoutGroups(){',['function renderLayoutCanvas(){','function renderLayoutFieldCard('],'layoutGroups')
grab('function renderLayoutCanvas(){',['function renderAdditional','const aiAllowedTypes=','function aiOpen('],'renderLayoutCanvas',50000)
grab('function structureSectionRange(',['function structureMoveSection('],'structureSectionRange')
grab('function structureMoveSection(',['function structureMoveRow('],'structureMoveSection')
grab('function structureMoveRow(',['function structureClearTargets('],'structureMoveRow')
grab('function structureRenderTarget(',['function structureGhost('],'structureRenderTarget')
grab('function structureFindTarget(',['function structureBegin'],'structureFindTarget')
grab('function smartRenderPreview(',['function smartClassifyCard('],'smartRenderPreview',30000)
grab('function smartClassifyCard(',['function smartNearestCardInRow('],'smartClassifyCard')
grab('function smartFindDropSpec(',['function smartShiftRowMeta('],'smartFindDropSpec')
grab('function smartMoveBeside(',['function smartMoveToExistingRow(','function smartMoveNewRow('],'smartMoveBeside')
grab('function smartMoveToExistingRow(',['function smartMoveNewRow('],'smartMoveToExistingRow')
grab('function smartMoveNewRow(',['function smartCommitSpec('],'smartMoveNewRow')

for pat in ['duplicate','sectionActions','data-structure-action','deleteSection','removeSection','cloneSection','sectionField','Generale','general']:
    out.append(f"\n===== SEARCH {pat} =====\n")
    for m in list(re.finditer(re.escape(pat),s,re.I))[:30]:
        a=max(0,m.start()-450); b=min(len(s),m.end()+900)
        out.append(s[a:b].replace('\n',' ')+'\n---\n')

Path(sys.argv[2]).write_text(''.join(out),encoding='utf-8')
PY
rm -rf "$ROOT/releases/_upload"
echo "Wrote $OUT"
