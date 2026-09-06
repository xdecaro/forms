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
patterns=['activeStructureSelection','is-selected','is-active','data-field-edit','data-row-edit','data-section-edit','renderLayout','renderFieldSettings','renderRowSettings','renderSectionSettings','structureQueue']
for p in patterns:
    print('\n===== '+p+' =====')
    for m in list(re.finditer(re.escape(p),s))[:30]:
        print(s[max(0,m.start()-1200):min(len(s),m.start()+3200)])
PY
