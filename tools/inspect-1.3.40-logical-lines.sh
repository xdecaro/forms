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
]:
    grab(name,start,end)

patterns=(
 'config.layout','layout.row','layout.width','layout.col','row_meta','grid-template-columns','gridTemplateColumns',
 "['layout']",'[\"layout\"]',"['row']",'[\"row\"]',"['width']",'[\"width\"]',"['col']",'[\"col\"]'
)
for p in sorted(root.rglob('*')):
    if not p.is_file() or p.suffix.lower() not in {'.php','.js','.mjs','.xml'}: continue
    try: text=p.read_text(encoding='utf-8')
    except Exception: continue
    hits=[]
    for pat in patterns:
        for m in re.finditer(re.escape(pat),text):
            a=max(0,m.start()-900); b=min(len(text),m.end()+1600)
            hits.append((m.start(),text[a:b]))
    if hits:
        out.append(f"\n=== FILE REFERENCES: {p.relative_to(root)} ===\n")
        seen=set()
        for _,chunk in sorted(hits)[:60]:
            key=chunk[:200]
            if key in seen: continue
            seen.add(key); out.append(chunk+'\n---')

out.append('\n=== SITE FILE LIST ===\n')
for p in sorted(root.rglob('*')):
    if p.is_file() and ('site/' in str(p.relative_to(root)).replace('\\','/') or 'components/com_decaroforms/' in str(p.relative_to(root)).replace('\\','/')):
        out.append(str(p.relative_to(root)))
Path(sys.argv[2]).write_text('\n'.join(out),encoding='utf-8')
PY
rm -rf "$ROOT/releases/_upload"
echo "Wrote $OUT"
