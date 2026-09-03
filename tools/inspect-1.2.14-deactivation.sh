#!/usr/bin/env bash
set -euo pipefail
ROOT=/tmp/forms-inspect-1214
OUTER="$ROOT/outer"
COMP="$ROOT/component"
OUT="releases/_inspect-1.2.14-deactivation.txt"
rm -rf "$ROOT"
mkdir -p "$OUTER" "$COMP"
unzip -q releases/1.2.14/pkg_decaroforms_1.2.14.zip -d "$OUTER"
COM_ZIP="$(find "$OUTER" -maxdepth 1 -type f -name 'com_decaroforms_*.zip' | head -n1)"
unzip -q "$COM_ZIP" -d "$COMP"
python3 - <<'PY' > "$OUT"
from pathlib import Path
import re
root=Path('/tmp/forms-inspect-1214/component/administrator/components/com_decaroforms')
files=[
 root/'tmpl/builder/default.php',
 root/'src/Controller/BuilderController.php',
 root/'src/Model/BuilderModel.php',
 root/'src/Table/FormTable.php',
 root/'tmpl/forms/default.php',
]
keys=('disable','disabled','enabled','close','closed','reason','message','limit','max_sub','maxsub','expiry','expires','deadline')
for p in files:
    if not p.exists():
        continue
    text=p.read_text(errors='replace')
    lines=text.splitlines()
    print(f'=== {p.relative_to(root)} ===')
    hits=[]
    for i,line in enumerate(lines):
        low=line.lower()
        if any(k in low for k in keys):
            hits.append(i)
    shown=set()
    for i in hits:
        for j in range(max(0,i-3),min(len(lines),i+4)):
            if j not in shown:
                print(f'{j+1}: {lines[j]}')
                shown.add(j)
        print('---')
    print()

print('=== builder form control names ===')
b=(root/'tmpl/builder/default.php').read_text(errors='replace')
for m in re.finditer(r'<(?:input|select|textarea)[^>]*\bname=["\']([^"\']+)["\'][^>]*>', b, re.I):
    tag=m.group(0)
    name=m.group(1)
    if any(k in name.lower() for k in keys) or 'status' in name.lower():
        print(name, '=>', re.sub(r'\s+',' ',tag)[:400])
PY
