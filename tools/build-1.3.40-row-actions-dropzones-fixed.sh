#!/usr/bin/env bash
set -euo pipefail
TMP_SCRIPT="$(mktemp)"
trap 'rm -f "$TMP_SCRIPT"' EXIT
cp tools/build-1.3.40-row-actions-dropzones.sh "$TMP_SCRIPT"
python3 - "$TMP_SCRIPT" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')
old='''pat=r"function structureFindTarget\\(x,y\\)\\{.*?\\n\\}\\nfunction structureBegin"\nm=re.search(pat,s,re.S)\nif not m: raise SystemExit('1.3.40: structureFindTarget block missing')'''
new='''a_target=s.index('function structureFindTarget(')\nb_target=s.index('function structureBegin',a_target)'''
if old not in s:
    raise SystemExit('1.3.40 fixed wrapper: target finder anchor missing')
s=s.replace(old,new,1)
old2="s=s[:m.start()]+new_target+s[m.end():]"
new2="s=s[:a_target]+new_target+s[b_target+len('function structureBegin'):]"
# Replace only the occurrence immediately after new_target block by targeting the last
# one before the Visual polish section.
idx=s.find(old2,s.find("new_target=r'''function structureFindTarget"))
if idx < 0:
    raise SystemExit('1.3.40 fixed wrapper: target splice anchor missing')
s=s[:idx]+new2+s[idx+len(old2):]
p.write_text(s,encoding='utf-8')
PY
bash "$TMP_SCRIPT"
