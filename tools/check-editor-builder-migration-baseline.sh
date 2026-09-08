#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${1:-1.5.1}"
PACKAGE="$ROOT/releases/$VERSION/pkg_decaroforms_$VERSION.zip"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

[[ -f "$PACKAGE" ]] || {
  echo "Package not found: $PACKAGE" >&2
  exit 1
}

mkdir -p "$WORK/outer" "$WORK/component"
unzip -q "$PACKAGE" -d "$WORK/outer"
COMPONENT_ZIP="$WORK/outer/com_decaroforms_${VERSION}.zip"
[[ -f "$COMPONENT_ZIP" ]] || {
  echo "Component ZIP not found inside package: $COMPONENT_ZIP" >&2
  exit 1
}

unzip -q "$COMPONENT_ZIP" -d "$WORK/component"
BUILDER="$WORK/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
[[ -f "$BUILDER" ]] || {
  echo "Builder template missing: $BUILDER" >&2
  exit 1
}

require() {
  local pattern="$1"
  local label="$2"
  if ! grep -Fq "$pattern" "$BUILDER"; then
    echo "Builder migration baseline missing: $label" >&2
    echo "Expected marker: $pattern" >&2
    exit 1
  fi
  printf 'OK  %s\n' "$label"
}

# Smart drag/pointer baseline. These markers intentionally describe observable
# capabilities of the current Forms implementation rather than pinning every
# check to one historical implementation line.
require 'const smartDrag=' 'smart drag state'
require 'function smartAutoWidths(' 'automatic row width distribution'
require 'function smartMoveBeside(' 'left/right same-row placement'
require 'function smartMoveNewRow(' 'above/below logical-row placement'
require 'function smartRenderPreview(' 'drag preview rendering'
require 'function smartAnimateFrom(' 'movement animation'
require 'smartDrag.pointerId' 'pointer-based drag lifecycle'
require 'canSide=count<=4' 'four-field row limit'
require 'sync();renderSelected();' 'Forms canonical sync after drag'
require 'pushHistory();' 'Forms domain history after drag'

# Selection hierarchy and active Field state must remain intact.
require '.df-layout-card.is-active{' 'active Field visual state'
require 'activeFieldKey' 'active Field domain state'
require 'activeStructureSelection' 'Section/Row selection state'

# Custom widths and logical layout must remain host-owned Forms data.
require 'f.config.layout.width' 'stored field width'
require 'f.config.layout.row' 'stored logical row'
require 'f.config.layout.col' 'stored logical column'

# JavaScript syntax check using the same extraction strategy as the release
# build scripts. PHP fragments are neutralised before <script> bodies are joined.
python3 - "$BUILDER" > "$WORK/builder.js" <<'PY'
from pathlib import Path
import re
import sys

source = Path(sys.argv[1]).read_text(encoding='utf-8')
source = re.sub(r'<\?(?:php|=).*?\?>', 'null', source, flags=re.S)
print('\n'.join(re.findall(r'<script(?:\s[^>]*)?>(.*?)</script>', source, flags=re.S | re.I)))
PY
node --check "$WORK/builder.js" >/dev/null
printf 'OK  Builder JavaScript syntax\n'

cat <<EOF

Forms $VERSION Builder migration baseline: PASS

This does not prove Editor Builder parity. It proves the current Forms behaviors
that must remain present until the Editor adapter passes equivalent runtime,
touch/pointer, persistence, responsive and light/dark regression tests.
EOF
