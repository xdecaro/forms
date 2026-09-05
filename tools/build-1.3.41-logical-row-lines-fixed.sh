#!/usr/bin/env bash
set -euo pipefail
TMP_SCRIPT="$(mktemp)"
trap 'rm -f "$TMP_SCRIPT"' EXIT
cp tools/build-1.3.41-logical-row-lines.sh "$TMP_SCRIPT"
python3 - "$TMP_SCRIPT" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')

# 1.3.40 helper cluster ends at repairInvalidRows, not rowMeta.
old="replace_between('function fieldsInRow(row){','function rowMeta(',helpers,'row/visual-line helpers')"
new="replace_between('function fieldsInRow(row){','function repairInvalidRows(){',helpers,'row/visual-line helpers')"
if old not in s:
    raise SystemExit('1.3.41 fixed wrapper: helper boundary missing')
s=s.replace(old,new,1)

# normalizeLayoutRows must stop before widthChoices. In 1.3.40 the functions
# setFieldWidth/selectField/duplicateField/removeCanvasField/moveFieldToRow are
# between widthChoices and sortSelectedByLayout; replacing through sortSelected
# would delete them before the subsequent 1.3.41 patches can update them.
old="replace_between('function normalizeLayoutRows(){','function sortSelectedByLayout(',new_normalize,'normalizeLayoutRows')"
new="replace_between('function normalizeLayoutRows(){','function widthChoices(',new_normalize,'normalizeLayoutRows')"
if old not in s:
    raise SystemExit('1.3.41 fixed wrapper: normalize boundary missing')
s=s.replace(old,new,1)

p.write_text(s,encoding='utf-8')
PY
bash "$TMP_SCRIPT"
