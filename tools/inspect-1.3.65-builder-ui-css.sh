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
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
blocks=re.findall(r'<style>(.*?)</style>',s,re.S|re.I)
styles='\n'.join(blocks)
print('FILE_BYTES',len(s))
print('STYLE_BLOCKS',len(blocks))
print('STYLE_BYTES',len(styles))
for token in ['.df-lock-toggle','.df-editor-toolbar','.df-layout-section-head','.df-layout-row-head','.df-layout-card.is-active','.df-layout-section-group.is-section-selected','.df-layout-row-group.is-selected']:
    print('COUNT',token,styles.count(token))

print('\n===== MARKER DEPTH / CONTEXT =====')
for marker in ['Forms 1.3.63','Forms 1.3.64','Forms 1.3.65']:
    for bi,b in enumerate(blocks):
        i=b.find(marker)
        if i<0: continue
        # naive CSS brace depth is enough to detect accidental nesting around our comment markers.
        depth=0;quote=None;esc=False
        for c in b[:i]:
            if quote:
                if esc:esc=False
                elif c=='\\':esc=True
                elif c==quote:quote=None
            else:
                if c in "'\"":quote=c
                elif c=='{':depth+=1
                elif c=='}':depth-=1
        print(marker,'STYLE_BLOCK',bi,'BRACE_DEPTH',depth)
        print(b[max(0,i-1800):min(len(b),i+3400)])

print('\n===== RULES TOUCHING LOCK/TOOLBAR =====')
for m in re.finditer(r'([^{}]+)\{([^{}]*)\}',styles,re.S):
    sel=' '.join(m.group(1).split())
    body=' '.join(m.group(2).split())
    if 'df-lock-toggle' in sel or 'df-editor-toolbar' in sel or 'df-edit-mode' in sel:
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

print('\n===== FINAL STYLE TAIL =====')
for bi,b in enumerate(blocks):
    print('\n--- STYLE BLOCK',bi,'TAIL ---')
    print(b[-9000:])
PY
