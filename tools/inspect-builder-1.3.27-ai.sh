#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
BASE="$ROOT/releases/1.3.27/pkg_decaroforms_1.3.27.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
OUT="$ROOT/tools/inspect-builder-1.3.27-ai"
rm -rf "$OUT"
mkdir -p "$TMP/o" "$TMP/c" "$OUT"
unzip -q "$BASE" -d "$TMP/o"
unzip -q "$TMP/o/com_decaroforms_1.3.27.zip" -d "$TMP/c"
B="$TMP/c/administrator/components/com_decaroforms/tmpl/builder/default.php"
cp "$B" "$OUT/default.php"
{
  grep -n -F 'id="df-open-ai-import"' "$B" || true
  grep -n -F 'Forms 1.3.27: AI field import' "$B" || true
  grep -n -F "window.dfBuilderRuntime={version:'1.3.27'" "$B" || true
  grep -n -F 'function sanitizeEmailPreviewHtml' "$B" || true
  grep -n -F 'sandbox="allow-scripts"' "$B" || true
  grep -n -F "const aiAliases=" "$B" || true
  grep -n -F 'pushHistory();aiClose();' "$B" || true
} > "$OUT/checks.txt"
php -l "$B" > "$OUT/php-lint.txt"
python3 - "$B" "$OUT/ai-block.js" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
a=s.index('/* Forms 1.3.27: AI field import.')
b=s.index('/* Forms 1.3.6: bind quick templates',a)
Path(sys.argv[2]).write_text(s[a:b],encoding='utf-8')
PY
node --check "$OUT/ai-block.js" > "$OUT/node-check.txt" 2>&1
rm -rf "$ROOT/releases/_upload"
