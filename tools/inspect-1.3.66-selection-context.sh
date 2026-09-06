#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$ROOT/releases/1.3.66/pkg_decaroforms_1.3.66.zip" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.66.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.66-selection-context-report.txt"
python3 - "$B" > "$OUT" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')

def func(name):
    start=s.find('function '+name+'(')
    if start<0:return 'NOT FOUND'
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
                if depth==0:return s[start:i+1]
        i+=1
    return 'UNTERMINATED'

for name in ['renderLayout','renderFieldSettings','renderRowSettings','renderSectionSettings','refreshActiveRowSelection']:
    print('\n===== FUNCTION '+name+' =====')
    print(func(name))

for token in ['activeFieldKey=','activeStructureSelection=','[data-field-edit]','[data-row-edit]','[data-section-edit]','classList.toggle(\'is-active\'','classList.toggle(\'is-selected\'']:
    print('\n===== TOKEN '+token+' =====')
    for m in list(re.finditer(re.escape(token),s))[:20]:
        line_start=s.rfind('\n',0,m.start())+1
        line_end=s.find('\n',m.end())
        if line_end<0:line_end=len(s)
        print(s[line_start:line_end])

print('\n===== CURRENT SELECTION CSS =====')
styles='\n'.join(re.findall(r'<style>(.*?)</style>',s,re.S|re.I))
for m in re.finditer(r'([^{}]+)\{([^{}]*)\}',styles,re.S):
    sel=' '.join(m.group(1).split()); body=' '.join(m.group(2).split())
    if any(x in sel for x in ['df-layout-card.is-active','df-layout-row-group.is-selected','df-layout-section-group']) and ('selected' in sel or 'is-active' in sel):
        print(sel+' {'+body+'}')
PY
