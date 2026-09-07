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

def show(label, token, before=2200, after=4200, limit=12):
    print('\n===== '+label+' =====')
    pos=0
    for n in range(limit):
        i=s.find(token,pos)
        if i<0: break
        print('\n---',n+1,'---\n'+s[max(0,i-before):min(len(s),i+after)].replace(';',';\n'))
        pos=i+len(token)

for label,token in [
 ('FUNCTION ADD','function add('),('CONST ADD','const add='),('LET ADD','let add='),
 ('ADD ARROW','add=x=>'),('LIBRARY DECL','const library='),('LIBRARY DECL LET','let library='),
 ('HEADING OBJECT',"type:'heading'"),('FIELDSET OBJECT',"type:'fieldset'"),('BUILDER ROLE SECTION',"builder_role:'section'"),
 ('OPEN LIBRARY HANDLER',"getElementById('df-open-library')"),('ACTIVE LIBRARY CATEGORY','activeLibraryCategory')]:
    show(label,token)
PY
