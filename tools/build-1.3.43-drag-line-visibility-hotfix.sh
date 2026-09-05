#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
OLD="1.3.42"
NEW="1.3.43"
BASE="$ROOT/releases/$OLD/pkg_decaroforms_$OLD.zip"
TARGET_DIR="$ROOT/releases/$NEW"
TARGET="$TARGET_DIR/pkg_decaroforms_$NEW.zip"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP" /tmp/forms-1343-builder.js' EXIT
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
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding='utf-8')

old_restore="""function smartRestorePreviewDom(){
 layoutCanvas?.querySelectorAll('.df-smart-placeholder,.df-smart-newrow-preview').forEach(el=>el.remove());
 layoutCanvas?.querySelectorAll('.df-smart-target-left,.df-smart-target-right,.df-smart-row-target-before,.df-smart-row-target-after').forEach(el=>el.classList.remove('df-smart-target-left','df-smart-target-right','df-smart-row-target-before','df-smart-row-target-after'));
 layoutCanvas?.querySelectorAll('.df-layout-row[data-smart-original-grid]').forEach(row=>{row.style.gridTemplateColumns=row.getAttribute('data-smart-original-grid')||'';row.removeAttribute('data-smart-original-grid');});
 layoutCanvas?.querySelectorAll('.df-smart-source-row-empty').forEach(el=>el.classList.remove('df-smart-source-row-empty'));
 if(smartDrag.active)smartReflowSourceRow();
}"""
new_restore="""function smartRestorePreviewDom(){
 layoutCanvas?.querySelectorAll('.df-smart-placeholder,.df-smart-newrow-preview').forEach(el=>el.remove());
 layoutCanvas?.querySelectorAll('.df-smart-target-left,.df-smart-target-right,.df-smart-row-target-before,.df-smart-row-target-after').forEach(el=>el.classList.remove('df-smart-target-left','df-smart-target-right','df-smart-row-target-before','df-smart-row-target-after'));
 layoutCanvas?.querySelectorAll('.df-layout-row[data-smart-original-grid]').forEach(row=>{row.style.gridTemplateColumns=row.getAttribute('data-smart-original-grid')||'';row.removeAttribute('data-smart-original-grid');});
 layoutCanvas?.querySelectorAll('.df-smart-source-row-empty').forEach(el=>el.classList.remove('df-smart-source-row-empty'));
 layoutCanvas?.querySelectorAll('.df-smart-source-line-empty').forEach(el=>el.classList.remove('df-smart-source-line-empty'));
 if(smartDrag.active)smartReflowSourceRow();
}"""
if old_restore not in s:
    raise SystemExit('1.3.43: smartRestorePreviewDom anchor missing')
s=s.replace(old_restore,new_restore,1)

old_reflow="function smartReflowSourceRow(){const row=smartDrag.sourceRow;if(!row?.isConnected)return;const visible=[...row.querySelectorAll('.df-layout-card:not(.df-smart-source-hidden)')];const group=row.closest('.df-layout-row-group');if(!visible.length){group?.classList.add('df-smart-source-row-empty');return;}group?.classList.remove('df-smart-source-row-empty');smartSetGrid(row,smartAutoWidths(visible.length));}"
new_reflow="function smartReflowSourceRow(){const row=smartDrag.sourceRow;if(!row?.isConnected)return;const visible=[...row.querySelectorAll('.df-layout-card:not(.df-smart-source-hidden)')],group=row.closest('.df-layout-row-group');group?.classList.remove('df-smart-source-row-empty');if(!visible.length){smartRememberGrid(row);row.classList.add('df-smart-source-line-empty');row.style.gridTemplateColumns='1fr';return;}row.classList.remove('df-smart-source-line-empty');smartSetGrid(row,smartAutoWidths(visible.length));}"
if old_reflow not in s:
    raise SystemExit('1.3.43: smartReflowSourceRow anchor missing')
s=s.replace(old_reflow,new_reflow,1)

old_css=".df-smart-source-hidden{display:none!important}.df-smart-source-row-empty{display:none!important}"
new_css=".df-smart-source-hidden{display:none!important}.df-smart-source-row-empty{display:block!important}.df-smart-source-line-empty{display:grid!important;grid-template-columns:1fr!important;min-height:52px!important;border:2px dashed color-mix(in srgb,var(--df) 48%,var(--df-border));border-radius:8px;background:color-mix(in srgb,var(--df) 5%,var(--bs-body-bg,#fff));align-items:center;position:relative}.df-smart-source-line-empty::after{content:'POSIZIONE ORIGINALE';display:flex;align-items:center;justify-content:center;min-height:46px;padding:8px;color:var(--df);font-size:10px;font-weight:900;letter-spacing:.04em;pointer-events:none}"
if old_css not in s:
    raise SystemExit('1.3.43: smart drag CSS anchor missing')
s=s.replace(old_css,new_css,1)

# Runtime marker.
if "version:'1.3.42'" not in s:
    raise SystemExit('1.3.43: runtime 1.3.42 marker missing')
s=s.replace("version:'1.3.42'","version:'1.3.43'")

# Regression guarantees for the exact browser/video failure:
# dragging a single visual line must never hide its entire logical row group.
assert "group?.classList.add('df-smart-source-row-empty')" not in s
assert ".df-smart-source-row-empty{display:none!important}" not in s
assert "row.classList.add('df-smart-source-line-empty')" in s
assert "layoutCanvas?.querySelectorAll('.df-smart-source-line-empty')" in s
assert ".df-smart-source-line-empty{display:grid!important" in s
assert "version:'1.3.43'" in s

# Keep the logical-row model and previous Add hotfix intact.
required=[
 'function visualLinesForItems(',
 'function visualLinesInRow(',
 'function visualLineForField(',
 'function normalizeVisualLines(',
 'function sortSelectedByLayout(',
 'function smartMoveBeside(',
 'function smartMoveToExistingRow(',
 'function smartMoveNewRow(',
 'function smartBeginDrag(',
 'function smartFinishDrag(',
 'function renderLayoutCanvas()'
]
missing=[x for x in required if x not in s]
if missing:
    raise SystemExit('1.3.43 missing required Builder helpers: '+', '.join(missing))

p.write_text(s,encoding='utf-8')
PY

# Keep component metadata coherent.
while IFS= read -r f; do sed -i "s/$OLD/$NEW/g" "$f"; done < <(grep -RIl --exclude='*.png' --exclude='*.jpg' --exclude='*.jpeg' --exclude='*.webp' --exclude='*.gif' -- "$OLD" "$TMP/component" || true)
php -l "$B" >/dev/null

# Syntax-check the Builder JS helper region.
python3 - "$B" <<'PY'
from pathlib import Path
import re,sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
a=s.find('function fieldsInRow(')
if a<0: raise SystemExit('1.3.43: helper block start missing')
ends=[x for x in (s.find('const aiAllowedTypes=',a),s.find('const aiWidths=',a),s.find('function aiOpen(',a)) if x>=0]
b=min(ends) if ends else min(len(s),a+200000)
js=re.sub(r'<\?php.*?\?>','null',s[a:b],flags=re.S)
Path('/tmp/forms-1343-builder.js').write_text(js,encoding='utf-8')
PY
node --check /tmp/forms-1343-builder.js >/dev/null

# Exact hotfix checks.
python3 - "$B" <<'PY'
from pathlib import Path
import sys
s=Path(sys.argv[1]).read_text(encoding='utf-8')
start=s.find('function smartReflowSourceRow()')
assert start>=0
chunk=s[start:start+1200]
assert "df-smart-source-line-empty" in chunk
assert "df-smart-source-row-empty');return" not in chunk
assert "group?.classList.remove('df-smart-source-row-empty')" in chunk
assert "version:'1.3.43'" in s
print('1.3.43 drag-line visibility regression checks OK')
PY

# Rebuild component ZIP.
rm -f "$COMP_OLD"
(cd "$TMP/component" && zip -qr "$TMP/outer/com_decaroforms_$NEW.zip" .)

# Rebuild the other nested extension ZIPs with version-only changes.
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
<changelogs><changelog><element>pkg_decaroforms</element><type>package</type><version>$NEW</version><security><item>No security changes.</item></security><fix><item>Fix smart field drag inside logical rows: an empty source visual line no longer hides the entire logical row and its sibling lines.</item><item>Keep the original source position visible as a lightweight placeholder while dragging, then restore the line cleanly on drop or cancel.</item><item>Preserve the 1.3.42 Add-field hotfix and the logical-row / visual-line data model without database changes.</item></fix></changelog></changelogs>
EOF

rm -rf "$ROOT/releases/_upload"
echo "Built $TARGET"
echo "SHA256 $SHA"
