#!/usr/bin/env bash
set -euo pipefail
TMP_SCRIPT="$(mktemp)"
trap 'rm -f "$TMP_SCRIPT"' EXIT
cp tools/build-1.3.69-selection-state.sh "$TMP_SCRIPT"
python3 - "$TMP_SCRIPT" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')
old="pos=s.find('>')+1\ns=s[:pos]+entry+s[pos:]"
new="marker='<changelogs>'\nif marker not in s: raise SystemExit('changelog root missing')\ns=s.replace(marker,marker+entry,1)"
if old not in s: raise SystemExit('changelog patch anchor missing')
s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
PY
bash "$TMP_SCRIPT"
