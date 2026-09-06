#!/usr/bin/env bash
set -euo pipefail
TMP_SCRIPT="$(mktemp)"
trap 'rm -f "$TMP_SCRIPT"' EXIT
cp tools/build-1.3.50-builder-core-refactor.sh "$TMP_SCRIPT"
python3 - "$TMP_SCRIPT" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]);s=p.read_text(encoding='utf-8')
old="    s=s[:a]+replacement+s[b:]"
new="    s=s[:a]+replacement+s[b+len(end_marker):]"
if old not in s:
    raise SystemExit('v2 helper anchor missing')
p.write_text(s.replace(old,new,1),encoding='utf-8')
PY
bash "$TMP_SCRIPT"
