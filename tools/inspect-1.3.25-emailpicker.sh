#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.25/pkg_decaroforms_1.3.25.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.25.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
python3 - "$B" "$ROOT/tools/inspection-emailpicker-1.3.25.txt" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text(encoding='utf-8').splitlines()
out=Path(sys.argv[2])
indices=[i for i,line in enumerate(src) if 'renderEmailPickers' in line or 'sandbox' in line or 'srcdoc' in line]
if not indices:
    raise SystemExit('No renderEmailPickers/sandbox/srcdoc references found')
ranges=[]
for i in indices:
    ranges.append((max(0,i-35),min(len(src),i+45)))
merged=[]
for a,b in sorted(ranges):
    if not merged or a>merged[-1][1]: merged.append([a,b])
    else: merged[-1][1]=max(merged[-1][1],b)
lines=[]
for a,b in merged:
    lines.append(f'--- lines {a+1}-{b} ---')
    lines.extend(f'{n+1}: {src[n]}' for n in range(a,b))
    lines.append('')
out.write_text('\n'.join(lines),encoding='utf-8')
PY
rm -rf "$ROOT/releases/_upload"
