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

def snippet(token, radius=2400):
    print('\n===== '+token+' =====')
    pos=0; count=0
    while True:
        i=s.find(token,pos)
        if i<0 or count>=12: break
        chunk=s[max(0,i-radius):min(len(s),i+radius)]
        chunk=chunk.replace(';',';\n').replace('><','>\n<')
        print('\n--- OCCURRENCE',count+1,'---\n',chunk)
        pos=i+len(token); count+=1

for token in ['df-field-entry-actions','df-add-field-main','Aggiungi campo','data-add-field','field-library','structureUi.section','isLayoutSectionField','selectField(index)','selectRowSettings(rowNo)']:
    snippet(token)
PY
