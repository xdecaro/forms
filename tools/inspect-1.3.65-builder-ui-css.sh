#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$ROOT/releases/1.3.65/pkg_decaroforms_1.3.65.zip" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.65.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.65-builder-ui-css-report.txt"
python3 - "$B" > "$OUT" <<'PY'
from pathlib import Path
import re,sys,collections
s=Path(sys.argv[1]).read_text(encoding='utf-8')
styles='\n'.join(re.findall(r'<style>(.*?)</style>',s,re.S|re.I))
print('FILE_BYTES',len(s))
print('STYLE_BYTES',len(styles))
for token in ['.df-lock-toggle','.df-editor-toolbar','.df-layout-section-head','.df-layout-row-head','.df-layout-card.is-active','.df-layout-section-group.is-section-selected','.df-layout-row-group.is-selected']:
    print('COUNT',token,styles.count(token))

print('\n===== RULES TOUCHING LOCK/TOOLBAR =====')
for m in re.finditer(r'([^{}]+)\{([^{}]*)\}',styles,re.S):
    sel=' '.join(m.group(1).split())
    body=' '.join(m.group(2).split())
    if 'df-lock-toggle' in sel or 'df-editor-toolbar' in sel or 'df-edit-mode' in sel:
        print(sel+' {'+body+'}')

print('\n===== RULES TOUCHING BUILDER HEIGHTS / ACTIVE SELECTION =====')
for m in re.finditer(r'([^{}]+)\{([^{}]*)\}',styles,re.S):
    sel=' '.join(m.group(1).split())
    body=' '.join(m.group(2).split())
    if any(x in sel for x in ['df-layout-section-head','df-layout-row-head','df-layout-card.is-active','df-layout-section-group.is-section-selected','df-layout-row-group.is-selected']):
        print(sel+' {'+body+'}')

print('\n===== LOCK JS =====')
for name in ['applyLockState','setEditorLocked']:
    start=s.find('function '+name+'(')
    if start<0:
        print(name,'NOT FOUND');continue
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

print('\n===== LAST 18000 STYLE CHARS =====')
print(styles[-18000:])
PY
