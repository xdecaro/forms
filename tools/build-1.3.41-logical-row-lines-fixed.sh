#!/usr/bin/env bash
set -euo pipefail
TMP_SCRIPT="$(mktemp)"
trap 'rm -f "$TMP_SCRIPT"' EXIT
cp tools/build-1.3.41-logical-row-lines.sh "$TMP_SCRIPT"
python3 - "$TMP_SCRIPT" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')

# The 1.3.40 helper cluster ends at repairInvalidRows, not rowMeta.
old="replace_between('function fieldsInRow(row){','function rowMeta(',helpers,'row/visual-line helpers')"
new="replace_between('function fieldsInRow(row){','function repairInvalidRows(){',helpers,'row/visual-line helpers')"
if old not in s: raise SystemExit('1.3.41 fixed wrapper: helper boundary missing')
s=s.replace(old,new,1)

# setFieldWidth in 1.3.40 is an inline/local helper rather than the standalone
# declaration assumed by the first build script. Add the new implementation and
# redirect all Builder calls without touching the rest of the field editor.
a=s.index('# Width changes affect only the visual line where the field lives.')
b=s.index('# Removing a field first closes only its old visual line',a)
width_patch="""# Width changes affect only the visual line where the field lives.
logical_width=r'''function setLogicalFieldWidth(index,width){if(index==null||!selected[index])return;const field=selected[index],row=Number(field.config.layout.row||1),line=visualLineForField(field),members=line.map(([f])=>f);width=Math.max(10,Math.min(100,Number(width)||100));if(members.length<=1){field.config.layout.width=100;}else if(width===100){members.forEach(f=>f.config.layout.width=100);}else{field.config.layout.width=width;const others=members.filter(f=>f!==field),remaining=100-width,base=Math.floor(remaining/Math.max(1,others.length)),extra=remaining-base*Math.max(1,others.length);others.forEach((f,i)=>f.config.layout.width=Math.max(1,base+(i<extra?1:0)));}normalizeVisualLines(row);sync();renderSelected();renderLayoutCanvas();}'''
anchor='function repairInvalidRows(){'
if anchor not in s: raise SystemExit('1.3.41: repair anchor for width helper missing')
s=s.replace(anchor,logical_width+'\\n'+anchor,1)
s=s.replace('setFieldWidth(', 'setLogicalFieldWidth(')

"""
s=s[:a]+width_patch+s[b:]
p.write_text(s,encoding='utf-8')
PY
bash "$TMP_SCRIPT"
