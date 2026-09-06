#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
V="1.3.49"
BASE="$ROOT/releases/$V/pkg_decaroforms_$V.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-builder-audit.js' EXIT
OUT="$ROOT/tools/audit-1.3.49-builder-report.txt"
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_$V.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"

{
 echo "FORMS BUILDER FULL AUDIT $V"
 echo "========================================"
 echo
 echo "[1] SYNTAX"
 php -l "$B"
 python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
js='\n'.join(m.group(1) for m in re.finditer(r'<script(?:\s[^>]*)?>(.*?)</script>',s,re.S|re.I))
js=re.sub(r'<\?(?:php|=).*?\?>','null',js,flags=re.S|re.I)
Path('/tmp/forms-builder-audit.js').write_text(js,encoding='utf-8')
print('JS bytes:',len(js.encode()))
PY
 node --check /tmp/forms-builder-audit.js
 echo
 echo "[2] FILE SIZE / COMPLEXITY"
 wc -l -c "$B"
 echo -n "script blocks: "; grep -o '<script' "$B" | wc -l
 echo -n "style blocks: "; grep -o '<style' "$B" | wc -l
 echo -n "addEventListener calls: "; grep -o 'addEventListener' "$B" | wc -l
 echo -n "renderLayoutCanvas calls: "; grep -o 'renderLayoutCanvas()' "$B" | wc -l
 echo -n "normalizeLayoutRows calls: "; grep -o 'normalizeLayoutRows()' "$B" | wc -l
 echo
 echo "[3] DUPLICATE JS FUNCTION DECLARATIONS"
 python3 - /tmp/forms-builder-audit.js <<'PY'
from pathlib import Path
import re,sys,collections
s=Path(sys.argv[1]).read_text()
names=re.findall(r'\bfunction\s+([A-Za-z_$][\w$]*)\s*\(',s)
c=collections.Counter(names)
for n,k in sorted(c.items()):
    if k>1: print(k,n)
print('functions:',len(names),'unique:',len(c))
PY
 echo
 echo "[4] DUPLICATE HTML IDS"
 python3 - "$B" <<'PY'
from pathlib import Path
import re,sys,collections
s=Path(sys.argv[1]).read_text()
ids=re.findall(r'\bid=["\']([^"\']+)["\']',s)
c=collections.Counter(ids)
for n,k in sorted(c.items()):
    if k>1: print(k,n)
print('ids:',len(ids),'unique:',len(c))
PY
 echo
 echo "[5] STRUCTURAL STATE WRITES"
 grep -nE 'layout(Row|Section)State\.(set|clear|delete)|row_meta|section_meta|activeStructureSelection' "$B" || true
 echo
 echo "[6] STRUCTURE DRAG ENGINE"
 grep -nE 'function structure(RowBlocks|ApplyBlocks|MoveRow|MoveSection|SectionRange|FindTarget|Finish)|structureDrag|structureSuppressClickUntil' "$B" || true
 echo
 echo "[7] FIELD DRAG ENGINE"
 grep -nE 'function smart(Move|Find|Classify|Commit|Reflow|Render|Auto|Offset|Effective)|smartDrag|offset_before|offset_after|df-layout-empty-slot' "$B" || true
 echo
 echo "[8] ROW / SECTION CRUD"
 grep -nE 'function (rowMeta|duplicateLayoutRow|requestRemoveLayoutRow|renderRowSettings|duplicateLayoutSection|requestRemoveLayoutSection|renderSectionSettings)|data-row-(copy|remove|edit)|data-section-(copy|remove|edit)' "$B" || true
 echo
 echo "[9] LAYOUT NORMALIZATION"
 grep -nE 'function (normalizeLayoutRows|normalizeVisualLines|visualLinesForItems|setFieldWidth|setLogicalRowOrder|fieldsInRow|layoutGroups)' "$B" || true
 echo
 echo "[10] HISTORY / SAVE / RESTORE"
 grep -nE 'function (pushHistory|restoreHistory|sync)|historyStates|builder_config|fields_json|selected_json|JSON.stringify\(selected|dfBuilderFieldsSnapshot' "$B" || true
 echo
 echo "[11] ACCORDION BEHAVIOUR"
 grep -nE 'toggle(Row|Section)|layoutRowState|layoutSectionState|is-open|aria-expanded|Expand|Collapse|Espandi|Comprimi' "$B" || true
 echo
 echo "[12] CSS CONFLICT CANDIDATES"
 grep -nE '\.df-layout-(row-body|row-group|section-body|section-group|row-head|section-head)|df-smart-source-line-empty|df-smart-source-row-empty|df-layout-empty-slot' "$B" || true
 echo
 echo "[13] RESPONSIVE / DARK MODE"
 grep -nE '@media|max-width:|data-bs-theme|prefers-color-scheme|dark' "$B" || true
 echo
 echo "[14] BUILDER VERSION PATCH COMMENTS"
 grep -nE 'Forms 1\.3\.|version:' "$B" || true
 echo
 echo "[15] RELATED SAVE/LOAD CODE"
 grep -RniE 'builder_config_json|field_order|ordering|config_json|row_meta|layout' "$TMP/component/administrator/components/com_decaroforms" | head -n 500 || true
 echo
 echo "[16] TARGETED FUNCTION BODIES"
 python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text()
names=['defaultFieldConfig','fieldsInRow','visualLinesForItems','normalizeVisualLines','normalizeLayoutRows','structureRowBlocks','structureApplyBlocks','structureSectionRange','structureMoveSection','structureMoveRow','smartMoveBeside','smartMoveLineRelative','smartMoveToExistingRow','smartMoveToSlot','smartMoveNewRow','smartCommitSpec','rowMeta','duplicateLayoutRow','requestRemoveLayoutRow','duplicateLayoutSection','renderLayoutCanvas','renderLayoutFieldCard','setFieldWidth']
for name in names:
    m=re.search(r'function\s+'+re.escape(name)+r'\s*\([^)]*\)\s*\{',s)
    if not m:
        print('\n---',name,'NOT FOUND ---'); continue
    i=m.start(); j=m.end(); depth=1; in_s=in_d=in_t=False; esc=False
    while j<len(s) and depth:
        ch=s[j]
        if esc: esc=False
        elif ch=='\\': esc=True
        elif in_s:
            if ch=="'": in_s=False
        elif in_d:
            if ch=='"': in_d=False
        elif in_t:
            if ch=='`': in_t=False
        else:
            if ch=="'": in_s=True
            elif ch=='"': in_d=True
            elif ch=='`': in_t=True
            elif ch=='{': depth+=1
            elif ch=='}': depth-=1
        j+=1
    print('\n---',name,'---')
    print(s[i:j][:12000])
PY
 echo
 echo "[17] STATIC RISK SCAN"
 python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text()
checks=[]
def add(level,msg): checks.append((level,msg))
if 'layoutRowState.set(newRow,true)' in s: add('HIGH','structureMoveRow still forces moved row open')
if "if(block.meta&&typeof block.meta==='object')nextMeta" not in s: add('HIGH','structureApplyBlocks may drop empty row metadata objects')
if 'normalizeLayoutRows();\n const meta=' in s or 'normalizeLayoutRows(); const meta=' in s: add('HIGH','structureRowBlocks normalizes before snapshot; identity/state may mutate before drag snapshot')
if s.count('document.addEventListener(\'pointermove\'')+s.count('document.addEventListener("pointermove"')>1: add('MEDIUM','multiple document pointermove listeners exist (field + structure engines); arbitration must be verified')
if 'smartDragIgnoreSelector' in s and 'df-layout-structure-handle' not in re.search(r"smartDragIgnoreSelector=.*?;",s,re.S).group(0): add('HIGH','field drag ignore selector does not explicitly exclude structural handles')
if 'structureSuppressClickUntil' not in s: add('MEDIUM','no structural click suppression after drag')
if 'color-mix(' in s: add('LOW','CSS color-mix requires modern browser; Joomla 6 target is generally acceptable')
for lvl,msg in checks: print(lvl,msg)
print('risk_count',len(checks))
PY
} > "$OUT" 2>&1

echo "Audit written to $OUT"
