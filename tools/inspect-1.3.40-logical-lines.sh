#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
VER="1.3.40"
BASE="$ROOT/releases/$VER/pkg_decaroforms_$VER.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_$VER.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.40-logical-lines.txt"
python3 - "$B" "$OUT" "$TMP/component" <<'PY'
from pathlib import Path
import sys,re
s=Path(sys.argv[1]).read_text(encoding='utf-8')
root=Path(sys.argv[3])
out=[]
def grab(name,start,end=None,limit=26000):
    i=s.find(start)
    if i<0:
        out.append(f"\n=== {name} MISSING ===\n"); return
    j=s.find(end,i) if end else -1
    if j<0: j=min(len(s),i+limit)
    out.append(f"\n=== {name} ===\n"+s[i:j])
for name,start,end in [
 ('defaultFieldConfig','function defaultFieldConfig(', 'function repairInvalidRows('),
 ('normalizeLayoutRows','function normalizeLayoutRows(', 'function widthChoices('),
 ('sortSelectedByLayout','function sortSelectedByLayout(', 'function widthChoices('),
 ('fieldsInRow','function fieldsInRow(', 'function rowMeta('),
 ('smartAutoWidths','function smartAutoWidths(', 'function smartFitRow('),
 ('smartFitRow','function smartFitRow(', 'function repairInvalidRows('),
 ('set width call context','setFieldWidth', None),
 ('move field context','function moveFieldToRow', '/* Forms 1.3.40: intelligent field drag & drop.'),
 ('smart drag preview','function smartPreviewBesideWidths(', 'function smartShiftRowMeta('),
 ('smart moves','function smartMoveBeside(', 'function smartEndVisual('),
 ('structure blocks','function structureRowBlocks(', 'function structureClearTargets('),
 ('duplicate row','function duplicateLayoutRow(', 'function renderRowSettings('),
 ('layoutGroups','function layoutGroups(', 'function layoutFieldCount('),
 ('render layout','function renderLayoutCanvas()', 'function renderColumns('),
 ('sync','function sync()', 'function pushHistory('),
]:
    grab(name,start,end)
out.append('\n=== FUNCTION NAMES AROUND WIDTH/MOVE/REMOVE ===\n')
for m in re.finditer(r'function\s+[A-Za-z0-9_]+\s*\([^)]*\)',s):
    sig=m.group(0)
    if any(k.lower() in sig.lower() for k in ('width','movefield','remove','duplicate','add')):
        out.append(sig)
Path(sys.argv[2]).write_text('\n'.join(out),encoding='utf-8')
PY
rm -rf "$ROOT/releases/_upload"
echo "Wrote $OUT"
