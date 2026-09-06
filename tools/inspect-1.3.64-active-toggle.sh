#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$ROOT/releases/1.3.64/pkg_decaroforms_1.3.64.zip" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.64.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.64-active-toggle-report.txt"
python3 - "$B" > "$OUT" <<'PY'
from pathlib import Path
import sys,re
s=Path(sys.argv[1]).read_text(encoding='utf-8')
body=re.sub(r'<style.*?</style>','',s,flags=re.S|re.I)
print('===== LOCK TOGGLE MARKUP / JS (styles removed) =====')
for m in re.finditer(r'df-lock-toggle',body):
 print(body[max(0,m.start()-1200):min(len(body),m.start()+1800)])
print('\n===== LOCK FUNCTIONS =====')
for name in ['applyLockState','setEditorLocked']:
 start=s.find('function '+name+'(')
 print('\n--- '+name+' ---')
 if start<0:
  print('NOT FOUND'); continue
 brace=s.find('{',start);depth=0;quote=None;esc=False;template=False;i=brace
 while i<len(s):
  c=s[i]
  if quote:
   if esc:esc=False
   elif c=='\\':esc=True
   elif c==quote:quote=None
  elif template:
   if esc:esc=False
   elif c=='\\':esc=True
   elif c=='`':template=False
  else:
   if c in "'\"":quote=c
   elif c=='`':template=True
   elif c=='{':depth+=1
   elif c=='}':
    depth-=1
    if depth==0:
     print(s[start:i+1]);break
  i+=1
print('\n===== 1.3.64 FINAL CSS =====')
idx=s.find('/* Forms 1.3.64: compact Builder spacing + unmistakable active edit mode. */')
print(s[idx:idx+5000] if idx>=0 else 'NOT FOUND')
PY
