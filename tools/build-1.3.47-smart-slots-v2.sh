#!/usr/bin/env bash
set -euo pipefail
SRC="tools/build-1.3.47-smart-slots.sh"
TMP_SCRIPT="$(mktemp)"
trap 'rm -f "$TMP_SCRIPT"' EXIT
python3 - "$SRC" "$TMP_SCRIPT" <<'PY'
from pathlib import Path
import sys,re
src=Path(sys.argv[1]).read_text(encoding='utf-8')
start=src.find('# Slot preview before normal beside preview.')
end=src.find('# Reflow source/target lines:', start)
if start < 0 or end < 0:
    raise SystemExit('v2: slot preview block not found')
replacement=r'''# Slot preview before normal beside preview.
anchor="if(spec.kind==='beside'){"
if anchor not in s: raise SystemExit('1.3.47: slot preview anchor missing')
slot_preview="if(spec.kind==='slot'){   const row=smartDrag.sourceRow;if(row){smartRememberGrid(row);row.style.gridTemplateColumns='1fr 1fr';const empty=document.createElement('div'),field=document.createElement('div');empty.className='df-smart-slot-preview is-empty';field.className='df-smart-slot-preview is-field';empty.innerHTML='<span>VUOTO 50%</span>';field.innerHTML=`<span>${esc(smartFieldByKey(smartDrag.fieldKey)?.label||'Campo')} · 50%</span>`;if(spec.position==='right'){row.append(empty,field);}else{row.append(field,empty);}}  }else "
s=s.replace(anchor,slot_preview+anchor,1)

'''
s=src[:start]+replacement+src[end:]
Path(sys.argv[2]).write_text(s,encoding='utf-8')
PY
chmod +x "$TMP_SCRIPT"
bash "$TMP_SCRIPT"
