#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.41"
NEW="1.3.42"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1342-builder.js' EXIT
mkdir -p "$TMP/outer" "$TMP/component" "$TARGET_DIR"
test -f "$BASE"
unzip -q "$BASE" -d "$TMP/outer"
COMP_OLD="$TMP/outer/com_decaroforms_$OLD.zip"
test -f "$COMP_OLD"
unzip -q "$COMP_OLD" -d "$TMP/component"
B="$TMP/component/administrator/components/com_decaroforms/tmpl/builder/default.php"
test -f "$B"

python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); s=p.read_text(encoding='utf-8')

# Hotfix: 1.3.41 refactor left calls to sortSelectedByLayout() but the declaration
# was removed from the final package. This caused Library -> Add to insert a field
# and then abort with ReferenceError before the Builder could finish rendering/syncing.
fn="function sortSelectedByLayout(){selected.sort((a,b)=>Number(a.config?.layout?.row||1)-Number(b.config?.layout?.row||1)||Number(a.config?.layout?.col||1)-Number(b.config?.layout?.col||1));}"
if 'function sortSelectedByLayout(' not in s:
    anchor='function widthChoices('
    pos=s.find(anchor)
    if pos < 0:
        anchor='function selectField('
        pos=s.find(anchor)
    if pos < 0:
        raise SystemExit('1.3.42: no safe anchor for sortSelectedByLayout')
    s=s[:pos]+fn+'\n'+s[pos:]

# Verify the complete helper chain required by the 1.3.41 logical-row model.
required=[
 'function fieldsInRow(',
 'function smartAutoWidths(',
 'function visualLinesForItems(',
 'function visualLinesInRow(',
 'function visualLineForField(',
 'function setLogicalRowOrder(',
 'function normalizeVisualLines(',
 'function distributeRow(',
 'function smartFitRow(',
 'function normalizeLayoutRows(',
 'function sortSelectedByLayout(',
 'function rowMeta(',
 'function add(item)',
 'function smartMoveBeside(',
 'function smartMoveToExistingRow(',
 'function smartMoveNewRow(',
 'function renderLayoutCanvas()'
]
missing=[x for x in required if x not in s]
if missing:
    raise SystemExit('1.3.42 missing required Builder helpers: '+', '.join(missing))

# There must be at least one actual use, otherwise this hotfix would be dead code.
if s.count('sortSelectedByLayout()') < 2:  # declaration body excluded; calls expected in add/move paths
    raise SystemExit('1.3.42: expected sortSelectedByLayout calls not found')

# Version marker.
s=s.replace("version:'1.3.41'","version:'1.3.42'")
p.write_text(s,encoding='utf-8')
PY

# Keep component metadata coherent.
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$TMP/component" || true)
php -l "$B" >/dev/null

# Static JS syntax check for the Builder helper region. PHP snippets are neutralized.
python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
a=s.find('function fieldsInRow(')
b=s.find('const aiAllowedTypes=',a)
if a<0 or b<0: raise SystemExit('1.3.42: Builder JS region missing')
js=re.sub(r'<\?php.*?\?>','null',s[a:b],flags=re.S)
Path('/tmp/forms-1342-builder.js').write_text(js,encoding='utf-8')
PY
node --check /tmp/forms-1342-builder.js >/dev/null

# Regression sanity check for the exact failure reported from the browser.
python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
assert 'function sortSelectedByLayout(' in s
assert 'function add(item)' in s
add=s[s.index('function add(item)'):s.index('/* Forms 1.3.40: AI mode selector',s.index('function add(item)'))]
assert 'sortSelectedByLayout()' in add
assert "version:'1.3.42'" in s
print('1.3.42 add-field regression checks OK')
PY

# Rebuild component ZIP.
rm -f "$COMP_OLD"
(cd "$TMP/component" && zip -qr "$TMP/outer/com_decaroforms_$NEW.zip" .)

# Rebuild every other nested extension ZIP with version-only changes, preserving contents.
for z in "$TMP/outer"/*_"$OLD".zip; do
  [ -e "$z" ] || continue
  work="$TMP/sub-$(basename "$z" .zip)"
  mkdir -p "$work"
  unzip -q "$z" -d "$work"
  while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$work" || true)
  newz="${z/$OLD/$NEW}"
  rm -f "$newz"
  (cd "$work" && zip -qr "$newz" .)
  rm -f "$z"
done
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -Il -- "$OLD" "$TMP/outer"/* 2>/dev/null || true)

rm -f "$TARGET"
(cd "$TMP/outer" && zip -qr "$TARGET" .)
unzip -tq "$TARGET" >/dev/null
SHA="$(sha256sum "$TARGET" | awk '{print $1}')"

cat > "$ROOT/updates/pkg_decaroforms.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<updates><update><name>Forms</name><description>Reusable Joomla form builder, submissions manager, data importer and export tools.</description><element>pkg_decaroforms</element><type>package</type><client>site</client><version>$NEW</version><downloads><downloadurl type="full" format="zip">https://raw.githubusercontent.com/xdecaro/forms/main/releases/$NEW/pkg_decaroforms_$NEW.zip</downloadurl></downloads><changelogurl>https://raw.githubusercontent.com/xdecaro/forms/main/updates/changelog.xml</changelogurl><tags><tag>stable</tag></tags><maintainer>Luca De Caro</maintainer><maintainerurl>https://github.com/xdecaro/forms</maintainerurl><targetplatform name="joomla" version="6\.[0-9]+" /><php_minimum>8.3.0</php_minimum><sha256>$SHA</sha256></update></updates>
EOF
cat > "$ROOT/updates/changelog.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<changelogs><changelog><element>pkg_decaroforms</element><type>package</type><version>$NEW</version><security><item>No security changes.</item></security><fix><item>Fix Builder Library Add action after the logical-row refactor by restoring the missing sortSelectedByLayout helper.</item><item>Validate the full logical-row helper chain during release build to prevent similar missing-helper regressions.</item></fix></changelog></changelogs>
EOF

rm -rf "$ROOT/releases/_upload"
echo "Built $TARGET"
echo "SHA256 $SHA"
