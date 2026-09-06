#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/outer" "$TMP/component"
unzip -q "$ROOT/releases/1.3.63/pkg_decaroforms_1.3.63.zip" -d "$TMP/outer"
unzip -q "$TMP/outer/com_decaroforms_1.3.63.zip" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
OUT="$ROOT/tools/inspect-1.3.63-lock-spacing-report.txt"
python3 - "$B" > "$OUT" <<'PY'
from pathlib import Path
import sys,re
s=Path(sys.argv[1]).read_text(encoding='utf-8')
needles=['df-lock-toggle','data-lock=','min-height:72px','min-height:68px','min-height:64px','df-layout-section-head','df-layout-row-head','df-layout-card.is-active','df-layout-section-group.is-selected','df-layout-row-group.is-selected','Forms 1.3.63']
for n in needles:
 print('\n===== '+n+' =====')
 for m in list(re.finditer(re.escape(n),s))[:20]:
  print(s[max(0,m.start()-1000):min(len(s),m.start()+2600)])
PY
