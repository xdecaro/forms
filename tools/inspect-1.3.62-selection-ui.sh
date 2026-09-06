#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$ROOT/releases/1.3.62/pkg_decaroforms_1.3.62.zip" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.62.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.62-selection-ui-report.txt"
python3 - "$B" > "$OUT" <<'PY'
from pathlib import Path
import sys,re
s=Path(sys.argv[1]).read_text(encoding='utf-8')

def func(name):
 st=s.find('function '+name+'(')
 if st<0:return 'NOT FOUND'
 br=s.find('{',st);d=0;q=None;esc=False;templ=False;i=br
 while i<len(s):
  c=s[i]
  if q:
   if esc:esc=False
   elif c=='\\':esc=True
   elif c==q:q=None
  elif templ:
   if esc:esc=False
   elif c=='\\':esc=True
   elif c=='`':templ=False
  else:
   if c in "'\"":q=c
   elif c=='`':templ=True
   elif c=='{':d+=1
   elif c=='}':
    d-=1
    if d==0:return s[st:i+1]
  i+=1
 return s[st:st+12000]

for n in ['selectField','renderLayoutFieldCard','renderLayoutCanvas','renderRowSettings','renderSectionSettings','applyLockState','setEditorLocked']:
 print('\n===== FUNCTION '+n+' =====')
 print(func(n))

for needle in ["wrap.className='df-layout-section-group'","df-layout-row-group'+","data-section-edit","data-row-edit","df-lock-toggle",".df-layout-card.is-active",".df-layout-row-group.is-active",".df-layout-section-group.is-active",".df-layout-row-group.is-selected"]:
 print('\n===== NEEDLE '+needle+' =====')
 for m in list(re.finditer(re.escape(needle),s))[:12]:
  print(s[max(0,m.start()-1000):min(len(s),m.start()+2600)])
PY
