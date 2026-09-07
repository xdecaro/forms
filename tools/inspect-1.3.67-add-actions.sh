#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$ROOT/releases/1.3.67/pkg_decaroforms_1.3.67.zip" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.67.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.67-add-actions-report.txt"
python3 - "$B" > "$OUT" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
body=s[s.rfind('</style>')+8:]
for token in ['df-add-field-main','df-field-entry-actions','df-ai-import-main','data-add-field','Aggiungi campo','field-library','add-field','librarySearch','libraryList','selectField(index)','selectRowSettings(rowNo)','isLayoutSectionField']:
    print('\n===== '+token+' =====')
    pos=0
    for n in range(8):
        i=body.find(token,pos)
        if i<0: break
        chunk=body[max(0,i-1800):min(len(body),i+2600)]
        chunk=chunk.replace(';',';\n').replace('><','>\n<')
        print('\n---',n+1,'---\n'+chunk)
        pos=i+len(token)
PY
