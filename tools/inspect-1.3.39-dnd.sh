#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
VER="1.3.39"
BASE="$ROOT/releases/$VER/pkg_decaroforms_$VER.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$BASE" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_$VER.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.39-dnd.txt"
python3 - "$B" "$OUT" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
out=[]
def grab(name,start_pat,end_pat=None,limit=18000):
    try:a=s.index(start_pat)
    except ValueError:
        out.append(f"\n=== {name} MISSING ===\n");return
    if end_pat:
        try:b=s.index(end_pat,a)
        except ValueError:b=min(len(s),a+limit)
    else:b=min(len(s),a+limit)
    out.append(f"\n=== {name} ===\n"+s[a:b])
grab('smart drag engine','function smartFindSpec(', 'function smartShiftRowMeta(')
grab('smart commit','function smartShiftRowMeta(', 'function smartEndVisual(')
grab('structure target/render','function structureClearTargets(', 'function structureGhost(')
grab('structure find/finish','function structureFindTarget(', 'function layoutGroups(')
grab('row and section render','function renderLayoutCanvas()', 'function renderColumns(')
grab('row settings','function renderRowSettings(', 'function renderSectionSettings(')
grab('section settings','function renderSectionSettings(', 'function renderSelected(')
# CSS around structure drag classes
for token in ['.is-structure-before','.df-layout-row-head','.df-layout-section-head','.df-structure-drag-ghost']:
    i=s.find(token)
    if i>=0:out.append(f"\n=== CSS {token} ===\n"+s[max(0,i-2500):min(len(s),i+5000)])
Path(sys.argv[2]).write_text('\n'.join(out),encoding='utf-8')
PY
rm -rf "$ROOT/releases/_upload"
echo "Wrote $OUT"
