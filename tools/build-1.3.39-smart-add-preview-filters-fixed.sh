#!/usr/bin/env bash
set -euo pipefail
TMP_SCRIPT="$(mktemp)"
trap 'rm -f "$TMP_SCRIPT"' EXIT
cp tools/build-1.3.39-smart-add-preview-filters.sh "$TMP_SCRIPT"
python3 - "$TMP_SCRIPT" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')
old="a=s.index('function fieldsInRow(');b=s.index('/* Forms 1.3.38: AI mode selector',a)"
new="a=s.index('function fieldsInRow(');b=s.index('const aiAllowedTypes=',a)"
if old not in s:
    raise SystemExit('1.3.39 fixed wrapper: syntax-check anchor missing')
s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
PY
bash "$TMP_SCRIPT"
