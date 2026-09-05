#!/usr/bin/env bash
set -euo pipefail
TMP_SCRIPT="$(mktemp)"
trap 'rm -f "$TMP_SCRIPT"' EXIT
cp tools/build-1.3.37-html-sections-translations.sh "$TMP_SCRIPT"
python3 - "$TMP_SCRIPT" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')
old="checks=['function aiHtmlSectionCandidates','function aiHtmlNearestSection',\"type:'heading'\",'sectionInfo=aiHtmlSectionCandidates','pageActions=pageCard.querySelector',\"version:'1.3.37'\",'2. Modelli rapidi','4. Libreria campi','6. Impostazioni email','7. Validazione e conferma','8. Codice personalizzato']"
new="checks=['function aiHtmlSectionCandidates','function aiHtmlNearestSection',\"type:'heading'\",'sectionInfo=aiHtmlSectionCandidates','pageActions=pageCard.querySelector',\"version:'1.3.37'\"]"
if old not in s:
    raise SystemExit('1.3.37 fixed wrapper: guardrail anchor missing')
s=s.replace(old,new,1)
p.write_text(s,encoding='utf-8')
PY
bash "$TMP_SCRIPT"
