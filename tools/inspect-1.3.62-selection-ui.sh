#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$ROOT/releases/1.3.62/pkg_decaroforms_1.3.62.zip" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.62.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.62-selection-ui-report.txt"
python3 - "$B" > "$OUT" <<'PY'
from pathlib import Path
import sys,re
s=Path(sys.argv[1]).read_text(encoding='utf-8')
needles=[
 'function renderLayoutFieldCard',
 'function renderLayoutCanvas',
 'function renderStructureSettings',
 'activeStructureSelection',
 'df-layout-section-group',
 'df-layout-row-group',
 'df-layout-section-head',
 'df-layout-row-head',
 'df-lock-toggle',
 'is-active',
 'function applyLockState',
 'function setEditorLocked'
]
for n in needles:
 print('\n===== '+n+' =====')
 for m in list(re.finditer(re.escape(n),s))[:8]:
  print(s[max(0,m.start()-1200):min(len(s),m.start()+4200)])
PY
