#!/usr/bin/env bash
set -euo pipefail
TMP_SCRIPT="$(mktemp)"
trap 'rm -f "$TMP_SCRIPT" /tmp/forms-ai-import-check.js' EXIT
cp tools/build-1.3.27-ai-import.sh "$TMP_SCRIPT"
python3 - "$TMP_SCRIPT" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')
# Sostituisce l'intera tabella alias con una versione sintatticamente valida e controllata.
correct_aliases="const aiAliases={phone:'tel',telephone:'tel',telefono:'tel',mail:'email','e-mail':'email',integer:'number',numeric:'number',decimal:'number',birthdate:'date','date_of_birth':'date',multiline:'textarea','text-area':'textarea',dropdown:'select',combo:'select',combobox:'select',checkbox_group:'checkboxes',checkboxgroup:'checkboxes',checkgroup:'checkboxes',privacy:'consent',gdpr:'consent',section:'heading',title:'heading'};"
s,n=re.subn(r"const aiAliases=\{[^\n]*?\};",correct_aliases,s,count=1)
if n!=1: raise SystemExit('build wrapper: aiAliases anchor missing')
s=s.replace("row.querySelector('[data-ai-label]').oninput=e=>{f.label=e.target.value.slice(0,150);f.key=aiSlug(f.label);aiRefreshDuplicates();aiRenderPreview(skipped);};", "row.querySelector('[data-ai-label]').onchange=e=>{f.label=e.target.value.slice(0,150);f.key=aiSlug(f.label);aiRefreshDuplicates();aiRenderPreview(skipped);};")
needle="# Aggiorna la versione del componente e ricrea il suo ZIP."
check=r'''# Controllo sintattico del solo blocco JavaScript AI (non contiene PHP dinamico).
python3 - "$BUILDER" <<'PYCHECK'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
a=s.index('/* Forms 1.3.27: AI field import.')
b=s.index('/* Forms 1.3.6: bind quick templates', a)
Path('/tmp/forms-ai-import-check.js').write_text(s[a:b],encoding='utf-8')
PYCHECK
if command -v node >/dev/null 2>&1; then node --check /tmp/forms-ai-import-check.js >/dev/null; fi

'''
if needle not in s: raise SystemExit('build wrapper: insertion anchor missing')
s=s.replace(needle,check+needle,1)
p.write_text(s,encoding='utf-8')
PY
bash "$TMP_SCRIPT"
