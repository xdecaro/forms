#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"; V="1.3.49"; TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/o" "$TMP/c"
unzip -q "$ROOT/releases/$V/pkg_decaroforms_$V.zip" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_$V.zip" -d "$TMP/c"
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/audit-1.3.49-row-model-report.txt"
python3 - "$B" > "$OUT" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')

def body(name):
 m=re.search(r'function\s+'+re.escape(name)+r'\s*\([^)]*\)\s*\{',s)
 if not m:return 'NOT FOUND'
 i=m.start(); j=m.end(); depth=1; q=None; esc=False
 while j<len(s) and depth:
  ch=s[j]
  if esc: esc=False
  elif ch=='\\': esc=True
  elif q:
   if ch==q:q=None
  elif ch in "'\"`":q=ch
  elif ch=='{':depth+=1
  elif ch=='}':depth-=1
  j+=1
 return s[i:j]

names=['normalizeLayoutRows','smartShiftRowMeta','structureRowBlocks','structureApplyBlocks','structureMoveRow','duplicateLayoutRow','requestRemoveLayoutRow','smartMoveBeside','smartMoveLineRelative','smartMoveToExistingRow','smartMoveNewRow','add','layoutGroups','renderLayoutCanvas']
print('ROW MODEL AUDIT 1.3.49')
print('======================')
for n in names:
 print('\n###',n,'###\n',body(n)[:16000])

print('\n### ROW NUMBER MUTATIONS ###')
for i,line in enumerate(s.splitlines(),1):
 if re.search(r'layout\.row\s*=|layout\.row\s*\+|layout\.row\s*-|row_meta|layoutRowState|activeStructureSelection',line):
  print(f'{i}: {line[:1600]}')

print('\n### EMPTY ROW SIGNALS ###')
for i,line in enumerate(s.splitlines(),1):
 if re.search(r'empty row|empty-row|new row|nuova riga|Aggiungi riga|addRow|createRow|row_meta',line,re.I):
  print(f'{i}: {line[:1600]}')

print('\n### FINDINGS ###')
find=[]
if 'row_id' not in s and 'row_uid' not in s: find.append('HIGH: no stable row identity (row_id/row_uid) found; numeric layout.row is used as position and de facto identity')
nb=body('normalizeLayoutRows')
if 'layoutRowState' not in nb: find.append('HIGH: normalizeLayoutRows renumbers rows but does not remap accordion state')
sr=body('smartShiftRowMeta')
if 'layoutRowState' not in sr: find.append('HIGH: smartShiftRowMeta shifts row metadata but not accordion state')
dl=body('duplicateLayoutRow')
if 'layoutRowState' not in dl: find.append('MEDIUM: duplicateLayoutRow does not explicitly create/preserve a separate accordion identity')
rm=body('requestRemoveLayoutRow')
if 'layoutRowState' not in rm: find.append('HIGH: requestRemoveLayoutRow removes/renumbers rows without explicit accordion-state remap')
lg=body('layoutGroups')
if 'row_meta' not in lg or 'selected' in lg: find.append('MEDIUM: layout grouping appears field-driven; verify persistence of truly empty logical rows')
for x in find: print(x)
print('finding_count',len(find))
PY

echo "written $OUT"
