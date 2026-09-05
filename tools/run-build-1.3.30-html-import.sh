#!/usr/bin/env bash
set -euo pipefail
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
python3 - tools/build-1.3.30-html-import.sh "$TMP" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text(encoding='utf-8')
old="\n }return{conditions:[],condition_logic:'all',condition_action:'show'};}\nfunction aiHtmlControlType"
new="\n return{conditions:[],condition_logic:'all',condition_action:'show'};}\nfunction aiHtmlControlType"
if old not in src:
    raise SystemExit('1.3.30 parser brace fix anchor missing')
Path(sys.argv[2]).write_text(src.replace(old,new,1),encoding='utf-8')
PY
bash "$TMP"
