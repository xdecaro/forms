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
for n in ['df-lock-toggle','function applyLockState','function setEditorLocked','is-locked','Forms 1.3.64']:
 print('\n===== '+n+' =====')
 for m in list(re.finditer(re.escape(n),s))[:20]:
  print(s[max(0,m.start()-900):min(len(s),m.start()+2600)])
PY
