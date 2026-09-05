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
python3 - "$B" "$OUT" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
out=[]
def grab(name,start,end=None,limit=22000):
    i=s.find(start)
    if i<0:
        out.append(f"\n=== {name} MISSING ===\n"); return
    j=s.find(end,i) if end else -1
    if j<0: j=min(len(s),i+limit)
    out.append(f"\n=== {name} ===\n"+s[i:j])
for name,start,end in [
 ('defaultFieldConfig','function defaultFieldConfig(', 'function repairInvalidRows('),
 ('normalizeLayoutRows','function normalizeLayoutRows(', 'function sortSelectedByLayout('),
 ('fieldsInRow','function fieldsInRow(', 'function rowMeta('),
 ('smartAutoWidths','function smartAutoWidths(', 'function smartFitRow('),
 ('smartFitRow','function smartFitRow(', 'function smartAddField('),
 ('smart drag','function smartClassifyCard(', 'function smartEndVisual('),
 ('move existing row','function smartMoveToExistingRow(', 'function smartMoveNewRow('),
 ('render layout','function renderLayoutCanvas()', 'function renderColumns('),
 ('sync','function sync()', 'function pushHistory('),
 ('frontend renderer clue','config.layout.width', None),
]:
    grab(name,start,end)
Path(sys.argv[2]).write_text('\n'.join(out),encoding='utf-8')
PY
rm -rf "$ROOT/releases/_upload"
echo "Wrote $OUT"
