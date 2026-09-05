#!/usr/bin/env bash
set -euo pipefail
TMP_SCRIPT="$(mktemp)"
trap 'rm -f "$TMP_SCRIPT"' EXIT
cp tools/build-1.3.40-row-actions-dropzones.sh "$TMP_SCRIPT"
python3 - "$TMP_SCRIPT" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')

# Make the structureRenderTarget replacement use stable function boundaries.
old_render='''old=re.search(r"function structureRenderTarget\\(spec\\)\\{.*?\\}\\n\\n",s,re.S)\nif not old: raise SystemExit('1.3.40: structureRenderTarget block missing')'''
new_render='''a_render=s.index('function structureRenderTarget(')\nb_render=s.index('function structureGhost(',a_render)'''
if old_render not in s:
    raise SystemExit('1.3.40 fixed wrapper: structure render finder anchor missing')
s=s.replace(old_render,new_render,1)
old_render_splice="s=s[:old.start()]+new_render+s[old.end():]"
new_render_splice="s=s[:a_render]+new_render+s[b_render:]"
idx=s.find(old_render_splice,s.find("new_render=r'''function structureRenderTarget"))
if idx < 0:
    raise SystemExit('1.3.40 fixed wrapper: structure render splice anchor missing')
s=s[:idx]+new_render_splice+s[idx+len(old_render_splice):]

# Make the structureFindTarget replacement use stable function boundaries as well.
old='''pat=r"function structureFindTarget\\(x,y\\)\\{.*?\\n\\}\\nfunction structureBegin"\nm=re.search(pat,s,re.S)\nif not m: raise SystemExit('1.3.40: structureFindTarget block missing')'''
new='''a_target=s.index('function structureFindTarget(')\nb_target=s.index('function structureBegin',a_target)'''
if old not in s:
    raise SystemExit('1.3.40 fixed wrapper: target finder anchor missing')
s=s.replace(old,new,1)
old2="s=s[:m.start()]+new_target+s[m.end():]"
new2="s=s[:a_target]+new_target+s[b_target+len('function structureBegin'):]"
idx=s.find(old2,s.find("new_target=r'''function structureFindTarget"))
if idx < 0:
    raise SystemExit('1.3.40 fixed wrapper: target splice anchor missing')
s=s[:idx]+new2+s[idx+len(old2):]

# The original syntax-check expected the AI block after smartDrag. In 1.3.39 the
# AI declarations live elsewhere, so use stable smart-drag boundaries instead.
old_js="a=s.index('const smartDrag=');b=s.index('const aiAllowedTypes=',a)"
new_js="a=s.index('function smartClassifyCard(');b=s.index('function smartShiftRowMeta(',a)"
if old_js not in s:
    raise SystemExit('1.3.40 fixed wrapper: smart syntax-check anchor missing')
s=s.replace(old_js,new_js,1)

p.write_text(s,encoding='utf-8')
PY
bash "$TMP_SCRIPT"
